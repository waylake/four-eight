# Hacking

개발 환경과 명령입니다. 기여 절차는 [CONTRIBUTING.md](./CONTRIBUTING.md)에 있습니다.

## 준비물

| | 버전 |
|---|---|
| macOS | 15.0 이상 |
| Xcode | 26.2 이상 (Swift 6.2) |
| XcodeGen | `brew install xcodegen` |
| Python | 3.9 이상 — 천문 데이터 재생성에만 필요 |

## 저장소 구조

```
four-eight/
├── SajuKit/              계산 엔진 (독립 Swift 패키지, 의존성 없음)
│   ├── Sources/SajuKit/
│   │   ├── Astro/        VSOP87, 장동, 삭, ΔT, 절기
│   │   ├── Core/         천간·지지·육십갑자·십신·십이운성
│   │   ├── KoreanCalendar/  음양력
│   │   ├── Saju/         PillarsEngine, DaeUn, Analyzer
│   │   ├── Interpretation/  FactExtractor, RuleSet
│   │   └── Resources/    rules.json (해석 규칙 60개)
│   └── Tests/
├── App/FourEight/        SwiftUI 앱
│   ├── Models/           Person, ModelCatalog
│   ├── Services/         SajuService, ModelManager, Interpreter
│   ├── Views/            화면
│   └── Resources/
├── scripts/              코드 생성기
├── docs/
└── project.yml           XcodeGen 정의
```

`FourEight.xcodeproj`는 생성물이며 커밋하지 않습니다.

## 엔진만 다루기

앱을 빌드하지 않고도 엔진 작업이 가능합니다. Xcode 없이 됩니다.

```bash
cd SajuKit
swift build
swift test
swift test --filter PublishedCaseTests
```

## 앱 빌드

```bash
xcodegen generate
xcodebuild -project FourEight.xcodeproj -scheme FourEight \
           -configuration Debug \
           -skipMacroValidation -skipPackagePluginValidation build
```

두 플래그가 필요합니다. `-skipMacroValidation`은 `mlx-swift-lm`의 `MLXHuggingFaceMacros`가, `-skipPackagePluginValidation`은 `mlx-swift`의 `CudaBuild` 빌드 플러그인이 신뢰 승인을 요구하기 때문입니다. Xcode GUI에서는 최초 1회 승인 대화상자를 통과하면 됩니다.

`ENABLE_HARDENED_RUNTIME`이 꺼져 있는 것은 실수가 아닙니다. Hardened Runtime에 포함된 Library Validation이 ad-hoc 서명과 겹치면 시스템이 `Sparkle.framework` 로드를 막습니다. Developer ID 인증서가 생기기 전까지는 켜지 마세요.

릴리스 빌드는 버전을 인자로 받습니다.

```bash
xcodebuild ... -configuration Release \
           MARKETING_VERSION=0.2.0 CURRENT_PROJECT_VERSION=42 build
```

실행:

```bash
open "$(xcodebuild -project FourEight.xcodeproj -scheme FourEight \
       -configuration Debug -showBuildSettings 2>/dev/null \
       | awk -F' = ' '/BUILT_PRODUCTS_DIR/{print $2; exit}')/FourEight.app"
```

## 코드 생성

두 생성기가 있습니다. 결과물은 커밋하며, 소스 데이터가 바뀔 때만 다시 돌립니다.

```bash
# VSOP87D 지구 계열 → Swift
python3 scripts/gen_vsop87.py scripts/data/VSOP87D.ear

# 앱 아이콘
swift scripts/gen_appicon.swift App/FourEight/Assets.xcassets/AppIcon.appiconset/icon_1024.png
```

`gen_vsop87.py`는 절단으로 버린 진폭의 합을 보고합니다. 임계값을 바꾸면 그 수치를 확인해 오차 예산이 유지되는지 판단하세요. L 계열에서 버린 진폭 합이 1×10⁻⁶ rad를 넘으면 절기 시각에 1초 이상 영향이 갈 수 있습니다.

## 테스트를 대하는 방식

계산 규칙을 바꿀 때는 테스트를 먼저 고치고 구현을 맞추세요. `PublishedCaseTests`와 `SolarTermReferenceTests`의 기댓값은 외부 공표 자료에서 온 것이므로 **구현에 맞춰 기댓값을 바꾸면 안 됩니다.** 기댓값이 틀렸다고 판단되면 새 출처를 [docs/research/](./docs/research/)에 추가하고 그 근거로 바꿉니다.

새 경계 사례를 발견하면 테스트로 고정해 주세요. 이 프로젝트에서 가장 값진 기여입니다.

## 해석 규칙 편집

`SajuKit/Sources/SajuKit/Resources/rules.json`입니다.

```json
{
  "id": "ILGAN_BYEONG",
  "category": "ilgan",
  "title": "병화 일간",
  "hanja": "丙火",
  "tags": ["ilgan:병"],
  "text": "..."
}
```

톤 규약은 [docs/research/interpretation-content.md](./docs/research/interpretation-content.md)에 있습니다. 요약하면 존댓말, 단정 금지, 의료·투자·법률 조언 금지, 이모지 금지, 항목마다 구체적 내용입니다.

태그 접두사는 `ilgan` `sibsin` `oheng_excess` `oheng_lack` `strength` `wolji` `sinsal` `daeun_sibsin`입니다. `FactExtractor`가 내는 태그와 정확히 일치해야 매칭됩니다.

## 코드 스타일

주변 코드를 따르세요. 몇 가지 관례가 있습니다.

- 주석은 한국어로, 무엇이 아니라 왜를 씁니다.
- 도메인 용어는 한글 그대로 씁니다. `일간`을 `dayMaster`로 쓰되 주석과 UI 문자열은 한국어입니다.
- `SajuKit`에 Foundation 외 의존성을 추가하지 않습니다. 이것이 이 패키지의 존재 이유입니다.
- 새 계산 옵션은 `SajuOptions`에 추가하고 기본값을 문서화합니다.
