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
#
#    기준선이 Interpreter를 구현하면 다시 스트림·중단·재생성이 붙고,
#    비용이 다른 두 연산이 한 정책으로 묶인다.
#
#    이 검사는 원래 "Gemma가 아닌 Interpreter는 전부 금지"였다. 그것은
#    규칙이 아니라 그때의 구현 목록이었고, 원격 제공자를 붙이자 정당한
#    구현(RemoteInterpreter)을 막았다. 검사가 **뜻**이 아니라 **당시의
#    모양**을 적고 있으면, 다음 사람은 뜻을 지키면서도 검사에 걸린다.
#    그때 사람들이 하는 일은 검사를 지우는 것이다.
#
#    그래서 명단으로 바꿨다. 새 구현을 더하는 것은 허용되지만 이 목록에
#    손을 대야 하고, 그러면 왜 이 규칙이 있는지 읽게 된다. 비용을 치르는
#    경로만 여기 올 수 있다 — 결정론적 문장은 baselineText다.
allowed_writers="GemmaInterpreter RemoteInterpreter GemmaCounselor RemoteCounselor"
writers=$(grep -rhn --include='*.swift' -oE '(struct|final class) +[A-Za-z]+ *: *(Interpreter|Counselor) *\{' App |
	sed -E 's/.*(struct|final class) +([A-Za-z]+).*/\2/' | sort -u || true)
for writer in $writers; do
	case " $allowed_writers " in
	*" $writer "*) ;;
	*)
		echo "생성 정책 위반: 명단에 없는 해석기·상담가 구현입니다 — $writer"
		note "비용을 치르는 경로만 Interpreter·Counselor가 됩니다."
		note "결정론적 문장은 InterpretationSection.baselineText로 두십시오."
		note "정말로 새 전송 경로라면 이 스크립트의 allowed_writers에 더하십시오."
		status=1
		;;
	esac
done

# 5. 프롬프트는 전송 수단이 아니라 제품이다.
#
#    톤 규약, 근거 밖으로 나가지 말라는 지시, 등급을 매기지 말라는 지시는
#    이 앱의 해석 품질 자체이고, 온디바이스로 보내는지 원격으로 보내는지에
#    따라 달라질 이유가 없다. 전송 층마다 자기 프롬프트를 갖게 두면 둘은
#    반드시 어긋나고, **어긋났다는 사실을 아무도 모른다** — 두 경로의 출력이
#    둘 다 그럴듯하기 때문이다.
prompt_marker='당신은 한국 명리학'
stray=$(grep -rln --include='*.swift' "$prompt_marker" App |
	grep -v 'Services/CounselBrief.swift' || true)
if [ -n "$stray" ]; then
	echo "생성 정책 위반: 지시문이 CounselBrief 밖에 있습니다."
	note "지시문과 프롬프트 조립은 CounselBrief·InterpretationBrief에만 둡니다."
	note "전송 층(GemmaInterpreter, RemoteWriter 등)은 나르기만 합니다."
	echo "$stray"
	status=1
fi

# 6. 이 Mac을 벗어나는 첫 전송 앞에는 사람이 서는 관문이 있다.
#
#    생성을 시작하는 화면은 무엇이 나가는지 보여주는 관문도 함께 가지고
#    있어야 한다. 관문 없는 생성 진입점이 하나 생기면 그 경로로는 사용자가
#    모르는 채로 글이 나간다. 그리고 그 실패는 조용하다 — 답이 정상적으로
#    나오므로 아무도 알아채지 못한다.
while IFS= read -r file; do
	[ -n "$file" ] || continue
	if ! grep -q 'needsAcknowledgement' "$file"; then
		echo "생성 정책 위반: 전송 확인 관문 없이 생성을 시작합니다 — $file"
		note "writers.needsAcknowledgement를 확인하고 OutboundDisclosure를 띄우십시오."
		status=1
	fi
done <<EOF
$(grep -rln --include='*.swift' -E 'store\.(generate|resume)\(key:|store\.answer\(id:' App || true)
EOF

# 7. API 키는 요청 헤더에만 실린다.
#
#    본문이나 주소에 실리면 그 값이 확인 화면과 보관 파일과 스크린샷에
#    남는다. Endpoint가 질의 문자열을 버리는 것도 같은 이유다.
key_leak=$(grep -rln --include='*.swift' 'Authorization' App RemoteLLM/Sources |
	grep -v 'RemoteLLM/Sources/RemoteLLM/ChatClient.swift' || true)
if [ -n "$key_leak" ]; then
	echo "생성 정책 위반: Authorization 헤더를 ChatClient 밖에서 다룹니다."
	note "키가 지나는 자리를 한 곳으로 유지하십시오."
	echo "$key_leak"
	status=1
fi

if [ "$status" -eq 0 ]; then
	echo "생성 정책 검사 통과 — 생성 진입점은 사용자 조작뿐이고, 나가는 것은 먼저 보여줍니다."
fi
exit "$status"
