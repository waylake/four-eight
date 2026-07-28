# AGENTS.md

AI 코딩 에이전트가 이 저장소에서 작업할 때 알아야 할 것들입니다.

## 넘지 말아야 할 선

**언어 모델에게 계산을 시키지 마세요.** 이 프로젝트의 핵심 설계입니다. 네 기둥, 십신, 대운 등 모든 명리 산출은 `SajuKit`이 결정론적으로 수행하고, 모델은 확정된 결과를 문장으로 옮기는 일만 합니다. 근거는 [ADR 0002](./docs/adr/0002-separate-deterministic-engine-from-llm.md)에 있습니다.

**`SajuKit`에 의존성을 추가하지 마세요.** Foundation만 씁니다. 이 제약이 이 패키지의 가치입니다.

**HTTP나 SSE를 `SajuKit`이나 앱 타깃에 넣지 마세요.** `RemoteLLM` 패키지에 둡니다. `SajuKit`은 명리 엔진이고, 앱 타깃에 두면 Xcode 없이 테스트할 방법이 사라집니다. 이 층에서 틀리기 쉬운 것들(줄 경계, 멀티바이트 분할, 오류 매핑)은 `swift test`로 고정되어야 합니다.

**`URLSession.AsyncBytes`의 `.lines`로 SSE를 읽지 마세요.** 실측 결과 `.lines`는 **빈 줄을 전부 버립니다.** 빈 줄은 SSE에서 이벤트 경계이므로 프레이밍이 사라집니다. `U+2028`·`U+0085`처럼 SSE가 종결자로 규정하지 않는 코드포인트에서도 줄을 쪼갭니다. `SSEParser`가 바이트를 모아 직접 자르는 이유입니다.

**모델이 사용자를 대신해 시작하는 일을 만들지 마세요.** LLM 생성은 사용자가 버튼을 눌러야만 시작합니다. `onAppear`·`onChange`·`task`에서 생성을 부르면 안 되고, "캐시가 없으면 채우는" 함수를 다시 만들면 안 됩니다. 화면에는 규칙 엔진이 조립한 기준선 문장이 항상 먼저 있습니다. `scripts/check_generation_policy.sh`가 검사하고 CI가 실행합니다. 근거는 [ADR 0009](./docs/adr/0009-baseline-first-generation-on-demand.md)에 있습니다.

**사용자의 글이 이 Mac을 벗어나는 경로를 조용히 만들지 마세요.** 목적지는 셋입니다 — 이 앱 안(`inProcess`), 이 Mac 안(`onMachine`, 루프백), 이 Mac 밖(`offMachine`). 판정이 애매하면 `offMachine`이라고 말합니다. 루프백을 원격이라 부르면 사용자가 확인 화면을 한 번 더 보고, 원격을 루프백이라 부르면 사용자는 자기 글이 나간 것을 모릅니다. 이 Mac 밖으로 나가는 첫 전송 앞에는 무엇이 나가는지 원문으로 보여주는 관문이 있어야 하고, 그것은 설정 화면이 아니라 보내기 직전에 있습니다. [ADR 0011](./docs/adr/0011-remote-provider-as-a-destination.md)을 보세요.

**프라이버시 문장을 고정 문자열로 두지 마세요.** "네트워크로 전송되지 않습니다"는 이제 설정에 따라 참이거나 거짓이고, 거짓일 때가 하필 사용자가 알아야 하는 경우입니다. About 화면과 상담 화면의 문장은 `Writers.plannedDestination`에서 계산합니다. 이미 화면에 있는 문장의 출처는 설정이 아니라 `Provenance` 기록에서 읽습니다.

**지시문과 프롬프트 조립을 전송 층에 두지 마세요.** 톤 규약은 이 앱의 해석 품질 자체이고 목적지에 따라 달라질 이유가 없습니다. `CounselBrief`·`InterpretationBrief`에만 두고 전송 층은 나르기만 합니다. 두 경로가 각자 프롬프트를 가지면 반드시 어긋나며, 문제는 어긋난 것이 아니라 **어긋났다는 사실을 아무도 모르는 것**입니다 — 양쪽 출력이 다 그럴듯합니다. `scripts/check_generation_policy.sh`가 검사합니다.

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

**아래 두 개는 추가하면 앱이 죽거나 조용히 망가집니다.** 실측 근거는 [macos-network-and-keychain.md](./docs/research/macos-network-and-keychain.md)에 있습니다.

| 하지 말 것 | 무슨 일이 일어나는가 |
|---|---|
| `keychain-access-groups` entitlement 추가 | ad-hoc 서명에서는 provisioning profile이 이 권한을 인가할 수 없어 **앱이 실행 시점에 SIGKILL됩니다**(exit 137). 출력도 없이 죽습니다 |
| `kSecUseDataProtectionKeychain` 또는 `kSecAttrAccessible` 사용 | ad-hoc 서명에서 `-34018 errSecMissingEntitlement`입니다. `kSecAttrAccessible`은 data protection 키체인에서만 유효하므로 legacy에 주면 아무 일도 하지 않으면서 "접근 범위를 좁혀 두었다"는 착각만 만듭니다 |

키체인 관련해 알아야 할 사실이 하나 더 있습니다. legacy 키체인 ACL은 쓴 프로세스의 **코드 해시**에 묶이므로, **앱을 업데이트하면 저장된 API 키를 읽지 못합니다**(`-25293 errSecAuthFailed`). 이것은 버그가 아니라 Developer ID 인증서가 없는 상태의 정상 동작이며, `Secrets.Lookup.needsReentry`가 그 상태에 이름을 붙여 사용자에게 무엇을 하면 되는지 말합니다. 오류로 뭉개지 마세요.

**`appcast.xml`을 소급 수정하지 마세요.** append-only로 다룹니다. 잘못 나간 항목은 지우지 말고 더 높은 빌드 번호로 새 릴리스를 올려 덮습니다. 파일은 저장소 루트에 있고 릴리스 워크플로가 항목을 더해 커밋합니다. 손으로 고칠 일은 없습니다. `scripts/check_appcast.py`가 CI에서 검사합니다.

**GitHub Pages를 배포하는 워크플로를 새로 만들지 마세요.** `pages.yml` 하나뿐입니다. Pages 배포는 사이트 전체 교체이므로 배포 경로가 둘이 되면 나중에 배포된 쪽이 상대의 파일을 지웁니다. `appcast.xml`이 사라지면 모든 사용자의 업데이트 확인이 조용히 죽습니다 — 오류도 나지 않습니다. 사이트는 항상 `web/` + `appcast.xml`에서 조립됩니다.

## 빌드와 테스트

```bash
cd SajuKit && swift test              # 명리 엔진. Xcode 불필요
cd RemoteLLM && swift test            # 원격 전송 층. Xcode 불필요
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
