# AGENTS.md

AI 코딩 에이전트가 이 저장소에서 작업할 때 알아야 할 것들입니다.

## 넘지 말아야 할 선

**언어 모델에게 계산을 시키지 마세요.** 이 프로젝트의 핵심 설계입니다. 네 기둥, 십신, 대운 등 모든 명리 산출은 `SajuKit`이 결정론적으로 수행하고, 모델은 확정된 결과를 문장으로 옮기는 일만 합니다. 근거는 [ADR 0002](./docs/adr/0002-separate-deterministic-engine-from-llm.md)에 있습니다.

**`SajuKit`에 의존성을 추가하지 마세요.** Foundation만 씁니다. 이 제약이 이 패키지의 가치입니다.

**모델이 사용자를 대신해 시작하는 일을 만들지 마세요.** LLM 생성은 사용자가 버튼을 눌러야만 시작합니다. `onAppear`·`onChange`·`task`에서 생성을 부르면 안 되고, "캐시가 없으면 채우는" 함수를 다시 만들면 안 됩니다. 화면에는 규칙 엔진이 조립한 기준선 문장이 항상 먼저 있습니다. `scripts/check_generation_policy.sh`가 검사하고 CI가 실행합니다. 근거는 [ADR 0009](./docs/adr/0009-baseline-first-generation-on-demand.md)에 있습니다.

**모델에게 안전 판단을 맡기지 마세요.** 위기 표현 감지와 대응 문구는 결정론적 코드가 처리하고 모델을 호출하지 않습니다. 계산을 맡기지 않는 것과 같은 이유입니다 — 그럴듯하게 틀리면 사람이 다칩니다. [ADR 0010](./docs/adr/0010-consultation-over-open-chat.md)을 보세요.

**테스트 기댓값을 구현에 맞추지 마세요.** `PublishedCaseTests`와 `SolarTermReferenceTests`의 값은 외부 공표 자료에서 온 것입니다. 테스트가 깨지면 구현이 틀린 것입니다. 기댓값이 틀렸다고 판단되면 `docs/research/`에 새 출처를 추가하고 그 근거로 바꾸세요.

**유파가 갈리는 지점에 정답을 정하지 마세요.** `SajuOptions`에 옵션으로 추가합니다. [ADR 0005](./docs/adr/0005-expose-school-differences-as-settings.md)를 보세요.

**아래 값을 바꾸거나 지우지 마세요.** 이미 배포된 앱에 박혀 나가므로 바꾸면 그 사용자들은 업데이트를 영원히 받지 못합니다. `project.yml`을 정리하다가 무심코 건드리기 쉬운 자리입니다.

| 값 | 현재 | 왜 못 바꾸는가 |
|---|---|---|
| `SUFeedURL` | `https://waylake.github.io/four-eight/appcast.xml` | 구버전 앱이 이 주소만 확인합니다 |
| `SUPublicEDKey` | `8MN3DdiGkKYCAbDUs3stVtsWDMgl5nPB1DwriETkTIg=` | Sparkle이 키 제거를 거부합니다. 교체만 가능합니다 |
| `ENABLE_HARDENED_RUNTIME` | `false` | ad-hoc 서명과 겹치면 Sparkle 로드가 실패합니다. Developer ID가 생기기 전까지 켜지 마세요 |
| `ARCHS` | `arm64` | MLX는 Metal 기반이라 Apple Silicon 전용입니다. x86_64 슬라이스는 동작하지 않으면서 빌드 시간만 두 배로 만듭니다 |

**`appcast.xml`을 소급 수정하지 마세요.** append-only로 다룹니다. 잘못 나간 항목은 지우지 말고 더 높은 빌드 번호로 새 릴리스를 올려 덮습니다.

## 빌드와 테스트

```bash
cd SajuKit && swift test              # 엔진만. Xcode 불필요
xcodegen generate                     # project.yml → .xcodeproj
xcodebuild -project FourEight.xcodeproj -scheme FourEight \
           -configuration Debug \
           -skipMacroValidation -skipPackagePluginValidation build
```

두 skip 플래그는 선택이 아닙니다. `mlx-swift-lm`의 매크로와 `mlx-swift`의 `CudaBuild` 플러그인이 신뢰 승인을 요구합니다.

`FourEight.xcodeproj`는 생성물입니다. 커밋하지 마세요.

## 생성 파일

수정하지 말고 생성기를 다시 돌리세요.

| 파일 | 생성기 |
|---|---|
| `SajuKit/Sources/SajuKit/Astro/Generated/VSOP87Earth.swift` | `scripts/gen_vsop87.py` |
| `App/FourEight/Assets.xcassets/AppIcon.appiconset/icon_1024.png` | `scripts/gen_appicon.swift` |

CI가 VSOP87 생성물의 드리프트를 검사합니다.

## 릴리스

전체 절차는 [docs/release.md](./docs/release.md)에 있습니다. 에이전트가 알아야 할 요약입니다.

**릴리스를 시작하지 마세요.** 태그를 찍거나 미는 것은 사람의 판단입니다. 요청받으면 `CHANGELOG.md` 섹션 작성까지만 하고 태그 명령은 사용자에게 넘기세요.

**흐름**: 태그 push → 빌드·검증·서명 → **초안** 릴리스 → 사람이 확인 → 발행 → appcast 라이브.

발행이 관문입니다. 태그를 밀어도 사용자에게는 아무 일도 일어나지 않습니다. 릴리스를 발행하는 행위가 appcast를 살립니다.

**버전 규칙**

- 태그 `v0.2.0` → `MARKETING_VERSION=0.2.0`
- `CURRENT_PROJECT_VERSION = git rev-list --count HEAD` — **단조 증가해야 합니다.** 낮아지면 Sparkle이 다운그레이드로 보고 조용히 무시합니다. `scripts/appcast.py`가 검사해 실패시킵니다.
- 히스토리를 재작성하면 커밋 수가 줄어 이 규칙이 깨질 수 있습니다. 재작성 후에는 반드시 확인하세요.

**릴리스 노트의 정본은 `CHANGELOG.md`입니다.** 릴리스 본문과 앱 안의 업데이트 설명이 모두 여기서 파생됩니다. 릴리스 본문에 직접 쓰지 마세요.

**계산이 바뀌는 릴리스는 표시합니다.** 만세력 규칙이 바뀌면 사용자가 이미 본 명식이 달라집니다. `CHANGELOG`에 명시하고 `appcast.py --calculation-changed`를 붙입니다.

**배포 경로가 둘입니다.** Homebrew(`waylake/homebrew-tap`)는 cask `postflight`가 격리 속성을 제거해 마찰이 없습니다. 직접 내려받는 경로는 Gatekeeper를 한 번 통과해야 합니다. cask를 고칠 때 `sha256`을 `:no_check`로 바꾸지 마세요 — 격리를 자동으로 벗기면서 무결성까지 포기하면 자산이 바뀌어도 아무도 모릅니다.

## 관례

- 주석과 UI 문자열은 한국어입니다. 무엇이 아니라 왜를 씁니다.
- 커밋은 Conventional Commits. `feat:` `fix:`만 릴리스를 만듭니다.
- 커밋 메시지와 PR 본문에 AI 어트리뷰션(`Co-Authored-By`, "Generated with...")을 넣지 않습니다.
- 이모지를 쓰지 않습니다. 코드, 문서, UI 전부입니다.
- 해석 콘텐츠는 톤 규약이 있습니다. [CONTRIBUTING.md](./CONTRIBUTING.md)를 보세요.

## 문서 구조

| 위치 | 용도 |
|---|---|
| `docs/adr/` | 되돌리기 어려운 결정. MADR 형식, `NNNN-kebab.md` |
| `docs/research/` | 출처가 있는 조사 노트. 결론이 굳으면 ADR로 승격 |
| `docs/release.md` | 릴리스 절차, 버전 규칙, 서명과 배포 채널 |
| `HACKING.md` | 개발 환경과 명령 |
| `CONTRIBUTING.md` | 기여 절차 |

사실 주장에는 출처 URL을 답니다. 조사 중 발견한 자료 간 불일치는 지우지 말고 기록하세요. 그것이 가장 값진 내용입니다.
