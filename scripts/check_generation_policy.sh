#!/usr/bin/env bash
#
# 생성 정책 검사.
#
# 이 저장소에는 되돌리면 사용자가 즉시 다치는 규칙이 하나 있다.
#
#   LLM 생성은 사용자의 조작으로만 시작한다.
#
# 예전에는 뷰가 나타날 때 "캐시가 없으면 채우는" 함수를 불렀다. 캐시 키에
# 엔진 종류가 들어 있었으므로, 모델을 켜는 것만으로 키가 바뀌어 이미 읽은
# 문장 전체가 다시 생성됐다. 사용자는 아무것도 주문하지 않았다.
#
# 주석으로 적으면 지워진다. 타입으로 막을 수 없는 부분은 검사로 남긴다.
# 실패하면 증상을 고치지 말고 왜 이 규칙이 있는지부터 읽으십시오 —
# docs/adr/0009-baseline-first-generation-on-demand.md
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
status=0

note() { printf '  %s\n' "$1"; }

# 1. 뷰 생명주기 훅에서 생성을 시작하지 않는다.
#    onAppear·onChange·task는 사용자의 의사가 아니라 SwiftUI의 사정으로
#    불린다. 읽기(restore)는 여기서 해도 되지만 쓰기는 안 된다.
# shellcheck disable=SC2016  # awk 프로그램이므로 셸 확장을 원하지 않는다.
hits=$(find App -name '*.swift' -print0 |
	xargs -0 awk '
    /\.onAppear|\.onChange|\.task[ ({]/ { window = 6 }
    window > 0 {
      if ($0 ~ /(generate|resume|regenerate)\(key:|answer\(id:/) {
        printf "%s:%d: %s\n", FILENAME, FNR, $0
      }
      window--
    }
  ' || true)
if [ -n "$hits" ]; then
	echo "생성 정책 위반: 뷰 생명주기 훅에서 생성을 시작합니다."
	note "생성은 Button 액션에서만 시작해야 합니다."
	echo "$hits"
	status=1
fi

# 2. "없으면 채운다" 의미의 API를 되살리지 않는다.
#    비용이 밀리초인 계산에는 옳지만 수십 초에 배터리를 쓰는 생성에는
#    틀린 정책이다. 이 이름이 다시 생기면 곧 같은 버그가 돌아온다.
if grep -rn --include='*.swift' -E 'func ensure|\.ensure\(' App >/dev/null 2>&1; then
	echo "생성 정책 위반: ensure(캐시가 없으면 생성) 형태의 API가 있습니다."
	note "generate(사용자 요청) / restore(디스크 읽기)로 나누십시오."
	grep -rn --include='*.swift' -E 'func ensure|\.ensure\(' App
	status=1
fi

# 3. 캐시 키에 엔진 종류를 넣지 않는다.
#    엔진이 키에 있으면 모델을 켜는 것이 캐시 전체 무효화와 같은 뜻이 된다.
#    어느 모델이 썼는지는 키가 아니라 Provenance에 기록한다.
if awk '
    /struct Key/ { inkey = 1 }
    inkey && /^    }/ { inkey = 0 }
    inkey && /engine/ { print FILENAME ":" FNR ": " $0; found = 1 }
    END { exit !found }
  ' App/FourEight/Services/InterpretationStore.swift; then
	echo "생성 정책 위반: InterpretationStore.Key에 엔진 정보가 있습니다."
	note "출처는 Document.provenance에 기록하십시오."
	status=1
fi

# 4. 규칙 엔진 기준선은 해석기가 아니다.
#    기준선이 Interpreter를 구현하면 다시 스트림·중단·재생성이 붙고,
#    비용이 다른 두 연산이 한 정책으로 묶인다.
if grep -rn --include='*.swift' -E ': *Interpreter *\{' App | grep -v Gemma >/dev/null 2>&1; then
	echo "생성 정책 위반: Gemma 외의 Interpreter 구현이 있습니다."
	note "결정론적 문장은 InterpretationSection.baselineText로 두십시오."
	grep -rn --include='*.swift' -E ': *Interpreter *\{' App | grep -v Gemma
	status=1
fi

if [ "$status" -eq 0 ]; then
	echo "생성 정책 검사 통과 — 생성 진입점은 사용자 조작뿐입니다."
fi
exit "$status"
