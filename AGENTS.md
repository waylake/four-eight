# AGENTS.md

AI 코딩 에이전트가 이 저장소에서 작업할 때 알아야 할 것들입니다.

## 넘지 말아야 할 선

**언어 모델에게 계산을 시키지 마세요.** 이 프로젝트의 핵심 설계입니다. 네 기둥, 십신, 대운 등 모든 명리 산출은 `SajuKit`이 결정론적으로 수행하고, 모델은 확정된 결과를 문장으로 옮기는 일만 합니다. 근거는 [ADR 0002](./docs/adr/0002-separate-deterministic-engine-from-llm.md)에 있습니다.

**`SajuKit`에 의존성을 추가하지 마세요.** Foundation만 씁니다. 이 제약이 이 패키지의 가치입니다.

**테스트 기댓값을 구현에 맞추지 마세요.** `PublishedCaseTests`와 `SolarTermReferenceTests`의 값은 외부 공표 자료에서 온 것입니다. 테스트가 깨지면 구현이 틀린 것입니다. 기댓값이 틀렸다고 판단되면 `docs/research/`에 새 출처를 추가하고 그 근거로 바꾸세요.

**유파가 갈리는 지점에 정답을 정하지 마세요.** `SajuOptions`에 옵션으로 추가합니다. [ADR 0005](./docs/adr/0005-expose-school-differences-as-settings.md)를 보세요.

## 빌드와 테스트

```bash
cd SajuKit && swift test              # 엔진만. Xcode 불필요
xcodegen generate                     # project.yml → .xcodeproj
xcodebuild -project FourEight.xcodeproj -scheme FourEight \
           -configuration Debug -skipMacroValidation build
```

`-skipMacroValidation`은 선택이 아닙니다. `mlx-swift-lm`의 매크로 신뢰 승인 때문입니다.

`FourEight.xcodeproj`는 생성물입니다. 커밋하지 마세요.

## 생성 파일

수정하지 말고 생성기를 다시 돌리세요.

| 파일 | 생성기 |
|---|---|
| `SajuKit/Sources/SajuKit/Astro/Generated/VSOP87Earth.swift` | `scripts/gen_vsop87.py` |
| `App/FourEight/Assets.xcassets/AppIcon.appiconset/icon_1024.png` | `scripts/gen_appicon.swift` |

CI가 VSOP87 생성물의 드리프트를 검사합니다.

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
| `HACKING.md` | 개발 환경과 명령 |
| `CONTRIBUTING.md` | 기여 절차 |

사실 주장에는 출처 URL을 답니다. 조사 중 발견한 자료 간 불일치는 지우지 말고 기록하세요. 그것이 가장 값진 내용입니다.
