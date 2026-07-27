# 온디바이스 LLM: Gemma 4 + MLX Swift

macOS 앱에서 Gemma 4를 Apple MLX로 로컬 실행하기 위한 사실 검증 노트. 패키지 버전, 모델 ID, 크기, 라이선스, chat template을 원본 소스에서 직접 확인했다.

조사일: 2026-07-27

## 조사 목적

해석문 생성을 온디바이스로 처리하려면 세 가지를 확정해야 한다. 어떤 Swift 런타임을 쓸 것인가,
어떤 모델 ID를 앱에 하드코딩할 것인가, 사용자가 런타임에 가중치를 내려받는 배포 형태가 라이선스상 문제가 없는가.

모든 항목은 2026-07-27 기준으로 GitHub raw와 Hugging Face API에서 직접 확인한 값이다. 추정치는 없다.

결론부터 적으면 다음과 같다.

- 런타임은 `ml-explore/mlx-swift-lm` 3.31.4. Gemma 4가 LLM/VLM 팩토리 registry에 정식 등록되어 있다.
- 기본 모델은 `mlx-community/gemma-4-e2b-it-4bit`(3.55 GB), 상위 옵션은 `mlx-community/gemma-4-e4b-it-4bit`(5.15 GB).
  두 ID 모두 mlx-swift-lm 소스에 하드코딩된 공식 프리셋이다.
- Gemma 4는 Apache 2.0이며 gated가 아니다. 앱에 HF 로그인 플로우가 필요 없다.
- Gemma 4는 system role을 네이티브 지원한다. 구세대처럼 system을 user turn에 병합할 필요가 없다.

## Gemma 4 모델군 스펙

model card 기준.

| 항목 | 값 |
|---|---|
| 공개 | 2026-03 (HF `google/gemma-4-31B-it` createdAt 2026-03-11) |
| Technical report | arXiv 2607.02770 |
| 사이즈 | E2B, E4B, 12B, 26B A4B (MoE), 31B — Dense + MoE 혼합 라인업 |
| 입력 | 전 모델 text + image. audio는 E2B/E4B/12B에서 native. video 입력 지원 |
| 출력 | text |
| Context window | 소형(E2B/E4B) 128K, 중형 256K |
| 언어 | 140개 이상 |
| Reasoning | configurable thinking mode 내장 |
| pipeline_tag | `any-to-any` |

원본 가중치 크기(bf16): `google/gemma-4-E2B-it`의 model.safetensors는 10,246,621,918바이트(10.25 GB),
`google/gemma-4-E4B-it`는 15,992,595,884바이트(15.99 GB). 앱은 이 원본이 아니라 아래의 MLX 4bit 변환본을 쓴다.

## MLX Swift 런타임

라이브러리 본체는 `mlx-swift-examples`에서 분리된 `ml-explore/mlx-swift-lm`이다.

| 항목 | 값 | 근거 |
|---|---|---|
| SPM URL | `https://github.com/ml-explore/mlx-swift-lm` | GitHub API `full_name` |
| 최신 release | `3.31.4` (2026-06-30 publish) | GitHub releases API |
| README 권장 pin | `.upToNextMajor(from: "3.31.3")` | README.md |
| swift-tools-version | `6.1` | Package.swift 1행 |
| Platforms | `.macOS(.v14)`, `.iOS(.v17)`, `.tvOS(.v17)`, `.visionOS(.v1)` | Package.swift `platforms:` |
| 주요 products | `MLXLLM`, `MLXVLM`, `MLXLMCommon`, `MLXEmbedders`, `MLXHuggingFace`, `MLXFoundationModels`, `MLXGuidedGeneration` (외 `BenchmarkHelpers`, `IntegrationTestHelpers`) | Package.swift `products:` |
| 의존성 | `ml-explore/mlx-swift` `.upToNextMinor(from: "0.31.4")`, `swiftlang/swift-syntax` `602.0.0 ..< 604.0.0` | Package.swift `dependencies:` |

release 이력: `3.31.4`(2026-06-30) ← `3.31.3`(2026-04-15, 첫 3.x) ← `2.31.3`(2026-04-01, 마지막 2.x) ← `2.30.6`(2026-02-18).

### 주의 사항

- **3.x는 breaking major다.** README: "The `main` branch is a _new_ major version number: 3.x.
  In order to decouple from tokenizer and downloader packages some breaking changes were introduced."
  tokenizer/downloader가 패키지 본체에서 분리되어, HF 연동 시 별도 패키지 2개를 추가해야 한다.
- `mlx-swift-examples`는 여전히 활성 저장소이나(archived: false, 마지막 push 2026-07-20) 이제 예제 앱 모음이며,
  라이브러리 본체는 mlx-swift-lm이다. mlx-swift-lm README가 examples를 "example applications and tools"로 역참조한다.
- `MLXFoundationModels` product(Apple FoundationModels 브릿지)는 macOS/iOS/visionOS 27.0 SDK가 필요하다.
  `FoundationModelsIntegration` trait로 게이트되며 기본 활성이다. 구 OS 타깃은 이 trait를 끄고 MLXLLM/MLXLMCommon만 쓰면 된다.
- MLX 자체가 Apple silicon 전용이다(ml-explore/mlx: "An array framework for Apple silicon").
  manifest의 macOS 14는 SPM 최소 버전일 뿐이고, 실행에는 Apple silicon Mac이 필요하다.

앱 타깃 의존성(README "Package.swift" 섹션 원문):

```swift
dependencies: [
    .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.3")),
    .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
    .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
],
// target products: MLXLLM, MLXLMCommon, MLXHuggingFace (mlx-swift-lm)
//                  HuggingFace (swift-huggingface), Tokenizers (swift-transformers)
```

### Gemma 4 registry 등록 근거

`Libraries/MLXLLM/LLMModelFactory.swift`의 `LLMTypeRegistry.shared` 등록 라인(main과 tag 3.31.4 동일, 라인 33-40):

```swift
"gemma": create(GemmaConfiguration.self, GemmaModel.init),
"gemma2": create(Gemma2Configuration.self, Gemma2Model.init),
"gemma3": create(Gemma3TextConfiguration.self, Gemma3TextModel.init),
"gemma3_text": create(Gemma3TextConfiguration.self, Gemma3TextModel.init),
"gemma3n": create(Gemma3nTextConfiguration.self, Gemma3nTextModel.init),
"gemma4": create(Gemma4Configuration.self, Gemma4Model.init),
"gemma4_unified": create(Gemma4Configuration.self, Gemma4Model.init),
"gemma4_text": create(Gemma4TextConfiguration.self, Gemma4TextModel.init),
```

`LLMRegistry` 프리셋(라인 203-213):

```swift
static public let gemma4_e4b_it_4bit = ModelConfiguration(
    id: "mlx-community/gemma-4-e4b-it-4bit",
    defaultPrompt: "What is the difference between a fruit and a vegetable?",
    extraEOSTokens: ["<turn|>"]
)

static public let gemma4_e2b_it_4bit = ModelConfiguration(
    id: "mlx-community/gemma-4-e2b-it-4bit",
    defaultPrompt: "What is the difference between a fruit and a vegetable?",
    extraEOSTokens: ["<turn|>"]
)
```

gemma3n 프리셋의 `extraEOSTokens`는 `["<end_of_turn>"]`인데 gemma4는 `["<turn|>"]`이다.
4세대에서 turn 토큰이 바뀐 것이 소스에도 반영되어 있다.

VLM 팩토리(`Libraries/MLXVLM/VLMModelFactory.swift`)에도 동일 계열이 등록되어 있다.

```swift
"gemma3": create(Gemma3Configuration.self, Gemma3.init),
"gemma4": create(Gemma4Configuration.self, Gemma4.init),
"gemma4_unified": create(Gemma4UnifiedConfiguration.self, Gemma4Unified.init),
// processors:
"Gemma4Processor": create(Gemma4ProcessorConfiguration.self, Gemma4Processor.init),
"Gemma4UnifiedProcessor": create(Gemma4UnifiedProcessorConfiguration.self, Gemma4UnifiedProcessor.init),
```

`VLMRegistry` 프리셋은 `gemma4_E2B_it_4bit`, `gemma4_E4B_it_4bit`, `gemma4_31B_it_4bit`, `gemma4_26BA4B_it_4bit`이며
각각 `mlx-community/gemma-4-e2b-it-4bit`, `gemma-4-e4b-it-4bit`, `gemma-4-31b-it-4bit`, `gemma-4-26b-a4b-it-4bit`에 대응한다.

구현 파일은 다음과 같다.

- `Libraries/MLXLLM/Models/Gemma4.swift`, `Gemma4Text.swift` (text 경로)
- `Libraries/MLXVLM/Models/Gemma4.swift`, `Gemma4Assistant.swift` (멀티모달 + MTP drafter)
- `Libraries/MLXLMCommon/Models/Gemma4.swift`
- `Libraries/MLXVLM/Gemma4AssistantRegistration.swift` — speculative decoding용 `gemma4_assistant` / `gemma4_unified_assistant` drafter 등록(`await Gemma4AssistantRegistration.register()`. 선택 기능)

`mlx-community/gemma-4-e2b-it-4bit`의 `config.json`은 `model_type: "gemma4"`,
`architectures: ["Gemma4ForConditionalGeneration"]`, `quantization: {group_size: 64, bits: 4, mode: "affine"}`로
registry key와 정확히 일치한다.

텍스트 채팅만 필요하면 `import MLXLLM`으로 충분하다(LLMModelFactory가 `gemma4`를 텍스트 모델로 로드).
이미지·오디오 입력까지 쓰려면 `import MLXVLM` 경로를 쓴다.

## HF 모델 카탈로그

크기는 HF `/api/models/{id}/tree/main`의 `.safetensors` 파일 합계다. 실제 다운로드는 tokenizer.json 약 32 MB 등이 더해지므로
"총계" 열을 봐야 한다. 다운로드 수는 2026-07-27 조회값이다.

| Repo ID | Quant | safetensors bytes | GB | 총계 GB | Downloads | HF license 표기 |
|---|---|---|---|---|---|---|
| `mlx-community/gemma-4-e2b-it-4bit` | 4bit (g64 affine) | 3,550,670,554 | 3.55 | 3.58 | 68,629 | gemma (주1) |
| `mlx-community/gemma-4-e2b-it-8bit` | 8bit | 5,866,581,158 | 5.87 | 5.90 | 808 | gemma (주1) |
| `mlx-community/gemma-4-e4b-it-4bit` | 4bit (g64 affine) | 5,146,800,534 | 5.15 | 5.18 | 61,721 | gemma (주1) |
| `mlx-community/gemma-4-e4b-it-8bit` | 8bit | 8,880,976,964 | 8.88 | 8.91 | 4,006 | gemma (주1) |
| `mlx-community/gemma-4-E2B-it-qat-4bit` | QAT 4bit | 4,329,240,325 | 4.33 | 4.36 | 2,084 | (미표기) |
| `mlx-community/gemma-4-E4B-it-qat-4bit` | QAT 4bit | 6,798,307,742 | 6.80 | 6.83 | 1,802 | (미표기) |
| `lmstudio-community/gemma-4-E2B-it-MLX-4bit` | 4bit (mixed 4/8bit 레이어) | 4,339,886,573 | 4.34 | 4.37 | 197,491 | apache-2.0 |
| `lmstudio-community/gemma-4-E4B-it-MLX-4bit` | 4bit | 6,829,300,498 | 6.83 | 6.86 | 1,326,860 | apache-2.0 |

주1: mlx-community 변환 repo의 카드 메타데이터는 `license: gemma`로 표기되어 있으나,
base model인 `google/gemma-4-E2B-it` / `google/gemma-4-E4B-it`는 `license: apache-2.0`이다.
변환 repo 메타데이터가 구세대 템플릿을 답습한 것으로 보인다. 어느 repo도 gated는 아니다(전부 `gated: False` 확인).

mlx-community에는 그 외 `5bit`, `6bit`, `bf16`, `mxfp4`, `mxfp8`, `nvfp4`, `OptiQ-4bit`, `qat-*` 변형과
speculative decoding drafter용 `*-assistant-*` repo가 있다.

앱 기본값은 **E2B 4bit**(저사양 기본), 16 GB 이상 머신 옵션으로 **E4B 4bit**를 권장한다.
선택 근거는 성능 비교가 아니라 이 두 ID가 mlx-swift-lm 소스에 등록된 canonical ID라는 점이다.

## API 사용 패턴

3.x 기준으로 실제 소스에서 확인한 시그니처만 옮긴다.

### 다운로드와 로드

가장 간단한 경로는 `MLXHuggingFace`의 macro다. `Libraries/MLXHuggingFace/Macros.swift` 선언 원문:

```swift
@freestanding(expression)
public macro huggingFaceLoadModelContainer(
    configuration: ModelConfiguration
) -> ModelContainer

@freestanding(expression)
public macro huggingFaceLoadModelContainer(
    configuration: ModelConfiguration,
    progressHandler: @Sendable @escaping (Progress) -> Void
) -> ModelContainer
```

명시적 팩토리 경로는 `Libraries/MLXLMCommon/ModelFactory.swift`에 있다.

```swift
public func loadContainer(
    from downloader: any Downloader,
    using tokenizerLoader: any TokenizerLoader,
    configuration: ModelConfiguration,
    useLatest: Bool = false,
    progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
) async throws -> ContainerType
```

downloader와 tokenizer는 macro `#hubDownloader()` / `#huggingFaceTokenizerLoader()`로 생성한다
(swift-huggingface `HubClient` 래핑). progress 콜백은 Foundation `Progress`이므로 `fractionCompleted`를 UI에 바인딩하면 된다.
로컬 디렉터리 로드는 `loadContainer(from: URL, using:)`이다.

### 스트리밍 채팅

`ChatSession`은 `MLXLMCommon` 소속이다(`Libraries/MLXLMCommon/ChatSession.swift`). 핵심 시그니처 원문:

```swift
public init(
    _ model: ModelContainer,
    instructions: String? = nil,                       // system instructions
    speculativeDecoding: SpeculativeDecodingConfig? = nil,
    generateParameters: GenerateParameters = .init(),
    processing: UserInput.Processing = .init(resize: CGSize(width: 512, height: 512)),
    additionalContext: [String: any Sendable]? = nil,
    tools: [ToolSpec]? = nil,
    toolDispatch: (@Sendable (ToolCall) async throws -> String)? = nil
)

public func respond(to prompt: String, ...) async throws -> String   // 단발
public func streamResponse(
    to prompt: String,
    role: Chat.Message.Role = .user,
    images: consuming [UserInput.Image] = [],
    videos: consuming [UserInput.Video] = [],
    audios: consuming [UserInput.Audio] = []
) -> AsyncThrowingStream<String, Error>                              // 스트리밍
public func streamResponse(to messages: consuming [Chat.Message]) -> AsyncThrowingStream<String, Error>
public func streamDetails(...)   // Generation 단위 (토큰 통계 등)
public func clear() async        // 히스토리·KV cache 리셋
```

`GenerateParameters`에는 `temperature`, `topP`, `topK`, `minP`, `maxTokens`, `repetitionPenalty`, `seed`,
KV cache quantization(`kvBits`, `kvGroupSize`, `kvScheme`) 등이 있다(`Libraries/MLXLMCommon/Evaluate.swift`).

import 목록은 `MLXLLM`, `MLXLMCommon`, `MLXHuggingFace`(mlx-swift-lm)에
`HuggingFace`(swift-huggingface), `Tokenizers`(swift-transformers)를 더한 것이다.

## 라이선스

- `google/gemma-4-E2B-it` 카드 frontmatter 원문은 `license: apache-2.0`,
  `license_link: https://ai.google.dev/gemma/docs/gemma_4_license`다.
  카드 본문에도 "License: Apache 2.0 | Authors: Google DeepMind"로 명기되어 있다. **Gemma 4는 Apache License 2.0이다.**
- HF API 기준 `gated: False`이고 `extra_gated_prompt`가 없다. Gemma 3까지와 달리 약관 동의 게이트가 없어
  HF 토큰이나 로그인 없이 익명 다운로드가 가능하다.
- Google 라이선스 페이지(gemma_4_license)는 Apache 2.0 본문과 함께 "Prohibited use policy"와 "Intended use statement"를 병기 링크한다.
  법적 구속력의 기준은 Apache 2.0이지만(다운로드 시 별도 동의 절차가 없다), Google이 권고하는 사용 정책 문서가 존재한다는 점은
  앱 문서에 링크로 안내하는 편이 안전하다.
- 구세대와의 구분: Gemma 1~3과 3n은 여전히 `license: gemma`(Gemma Terms of Use + Prohibited Use Policy)다.
  예를 들어 `mlx-community/gemma-3n-E2B-it-4bit`의 태그는 `license:gemma`다. Gemma 4에서 Apache 2.0으로 전환된 것이다.

### 런타임 다운로드 배포 형태에서의 의미

앱은 가중치를 재배포하지 않고 사용자가 HF에서 런타임에 내려받는다. 이 전제에서 정리하면 다음과 같다.

1. 다운로드에 인증이나 약관 동의 절차가 필요 없다(gated 아님). 앱에 HF 로그인 플로우를 만들 필요가 없다.
2. Apache 2.0은 상업적 사용·수정·재배포를 허용하고 NOTICE와 라이선스 고지 유지 의무를 둔다.
   앱이 가중치를 번들하지 않으므로 앱 바이너리에 대한 의무는 사실상 없고, 라이선스 파일은 다운로드 스냅샷에 함께 내려온다.
   앱 정보 화면에 모델 라이선스(Apache 2.0)와 Google 라이선스 페이지 링크를 표기하는 것을 권장한다.
3. mlx-community 변환 repo의 `license: gemma` 메타데이터는 upstream(apache-2.0)과 불일치한다.
   앱 내 표기는 upstream 기준(Apache 2.0)으로 하되 이 불일치를 인지하고 있어야 한다.
   표기 일관성이 더 중요하다면 `lmstudio-community` 변환본이 대안이다(apache-2.0 표기, E4B 4bit 다운로드 1위).

## Chat template

`google/gemma-4-E2B-it`의 `tokenizer_config.json`에는 `chat_template` 키가 없다.
템플릿은 별도 파일 `chat_template.jinja`(18,569바이트)에 있고, 헤더 주석은
"Google Gemma 4 Canonical Chat Template", "Published: 2026-07-09"이다. 핵심 부분 원문:

```jinja
{{- bos_token -}}
{#- Handle System/Tool Definitions Block -#}
{%- if enable_thinking or tools or (messages and messages[0]['role'] in ['system', 'developer']) -%}
    {{- '<|turn>system\n' -}}
    {%- if enable_thinking -%}
        {{- '<|think|>\n' -}}
    {%- endif -%}
    {%- if messages and messages[0]['role'] in ['system', 'developer'] -%}
        {{- messages[0]['content'] | trim -}}
        ...
    {%- endif -%}
    ...
    {{- '<turn|>\n' -}}
{%- endif %}
...
{%- set role = 'model' if message['role'] == 'assistant' else message['role'] -%}
{{- '<|turn>' + role + '\n' }}
```

정리하면 다음과 같다.

- **Gemma 4는 system role을 네이티브 지원한다.** 첫 메시지의 role이 `system` 또는 `developer`면
  전용 `<|turn>system ... <turn|>` 블록으로 렌더링된다. Gemma 1~3처럼 system 내용을 user turn에 병합할 필요가 없다.
- turn marker가 `<|turn>{role}`(시작)과 `<turn|>`(종료)로 바뀌었고, 이는 mlx-swift-lm 프리셋의
  `extraEOSTokens: ["<turn|>"]`과 일치한다. assistant role은 `model`로 매핑된다.
- tool 정의는 system 블록 안에 `<|tool>...<tool|>`로 들어가고, thinking mode는 `enable_thinking` 변수로 `<|think|>` 토큰을 주입한다.
  `tools`나 `enable_thinking`만 있어도 system 블록이 생성된다.
- mlx-community 변환 repo에도 `chat_template.jinja`가 포함되어 함께 내려온다.
  다만 `gemma-4-e2b-it-4bit`의 것은 17,336바이트로 canonical 2026-07-09판 이전 revision이다.
  swift-transformers가 스냅샷의 템플릿을 적용하므로 동작에는 문제가 없으나,
  template 버그픽스가 필요해지면 upstream 최신판과 diff를 확인해야 한다.
- mlx-swift-lm의 `ChatSession(instructions:)`이 이 system turn으로 매핑되므로, 앱은 `instructions:`에 시스템 프롬프트를 넣으면 된다.

## 검증 방법과 재확인이 필요한 시점

검증은 전부 1차 소스를 직접 조회하는 방식으로 했다. GitHub raw로 `Package.swift`, `README.md`,
팩토리·`ChatSession`·`ModelFactory`·`Macros` 소스를 읽었고, Gemma 4 registry 등록은 `main` 브랜치뿐 아니라
tag `3.31.4`에서도 동일함을 확인했다(main 전용 기능이 아님을 배제하기 위해서다).
모델 크기와 gated 여부, 라이선스 메타데이터는 HF API(`/api/models/{id}`, `/tree/main`)에서 받은 값이다.

다음 상황에서는 이 문서를 다시 확인해야 한다.

| 트리거 | 확인 대상 |
|---|---|
| mlx-swift-lm이 새 major(4.x)를 내면 | 3.x → 4.x 사이의 breaking change. 3.x 자체가 tokenizer/downloader 분리로 인한 breaking major였다 |
| 의존 패키지 pin을 올릴 때 | swift-huggingface 0.9.0, swift-transformers 1.3.0, mlx-swift 0.31.4의 하한이 유효한지 |
| 모델 로딩·EOS 처리가 이상할 때 | `extraEOSTokens: ["<turn\|>"]`, 그리고 mlx-community 스냅샷의 chat_template.jinja(17,336바이트)와 upstream canonical(18,569바이트)의 diff |
| 앱 라이선스 표기를 검토할 때 | mlx-community 변환 repo의 `license: gemma` 표기가 upstream apache-2.0으로 정정되었는지 |
| 디스크 요구량 문구를 수정할 때 | HF `/tree/main` 실측 바이트. 재양자화로 값이 바뀔 수 있다 |
| macOS 27 SDK로 올릴 때 | `MLXFoundationModels`와 `FoundationModelsIntegration` trait 사용 여부 |

다운로드 수와 카탈로그 구성은 시간에 따라 변하는 값이므로 조사 시점(2026-07-27) 스냅샷으로만 취급한다.

## Sources

### mlx-swift-lm (GitHub)

- 저장소: <https://github.com/ml-explore/mlx-swift-lm>
- 저장소 메타·release API: <https://api.github.com/repos/ml-explore/mlx-swift-lm>, <https://api.github.com/repos/ml-explore/mlx-swift-lm/releases>
- 최신 release 3.31.4: <https://github.com/ml-explore/mlx-swift-lm/releases/tag/3.31.4>
- Package.swift (main): <https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/main/Package.swift>
- README (main): <https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/main/README.md>
- LLM 팩토리 (main): <https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/main/Libraries/MLXLLM/LLMModelFactory.swift>
- LLM 팩토리 (tag 3.31.4): <https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/3.31.4/Libraries/MLXLLM/LLMModelFactory.swift>
- VLM 팩토리: <https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/main/Libraries/MLXVLM/VLMModelFactory.swift> (tag판은 경로의 main을 3.31.4로 치환)
- ChatSession: <https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/main/Libraries/MLXLMCommon/ChatSession.swift>
- ModelFactory (loadContainer): <https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/main/Libraries/MLXLMCommon/ModelFactory.swift>
- MLXHuggingFace macros: <https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/main/Libraries/MLXHuggingFace/Macros.swift>
- 통합 가이드 (using.md): <https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/main/Libraries/MLXLMCommon/Documentation.docc/using.md>
- GenerateParameters: <https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/main/Libraries/MLXLMCommon/Evaluate.swift>
- Gemma4 drafter 등록: <https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/main/Libraries/MLXVLM/Gemma4AssistantRegistration.swift>
- 예제 저장소: <https://github.com/ml-explore/mlx-swift-examples>
- mlx-swift: <https://github.com/ml-explore/mlx-swift>, MLX: <https://github.com/ml-explore/mlx>

### Hugging Face

- google/gemma-4-E2B-it (카드·파일): <https://huggingface.co/google/gemma-4-E2B-it>, <https://huggingface.co/api/models/google/gemma-4-E2B-it>, <https://huggingface.co/api/models/google/gemma-4-E2B-it/tree/main>
- chat template: <https://huggingface.co/google/gemma-4-E2B-it/raw/main/chat_template.jinja>, tokenizer_config: <https://huggingface.co/google/gemma-4-E2B-it/raw/main/tokenizer_config.json>
- google/gemma-4-E4B-it: <https://huggingface.co/api/models/google/gemma-4-E4B-it/tree/main>
- mlx-community 변환: <https://huggingface.co/mlx-community/gemma-4-e2b-it-4bit>, <https://huggingface.co/mlx-community/gemma-4-e2b-it-8bit>, <https://huggingface.co/mlx-community/gemma-4-e4b-it-4bit>, <https://huggingface.co/mlx-community/gemma-4-e4b-it-8bit>, <https://huggingface.co/mlx-community/gemma-4-E2B-it-qat-4bit>, <https://huggingface.co/mlx-community/gemma-4-E4B-it-qat-4bit>
- lmstudio-community 변환: <https://huggingface.co/lmstudio-community/gemma-4-E2B-it-MLX-4bit>, <https://huggingface.co/lmstudio-community/gemma-4-E4B-it-MLX-4bit>
- 파일 크기 조회: 각 repo의 `https://huggingface.co/api/models/{id}/tree/main`
- 검색 API: <https://huggingface.co/api/models?search=gemma-4&library=mlx> 외 변형 쿼리

### Google

- Gemma 4 라이선스 페이지: <https://ai.google.dev/gemma/docs/gemma_4_license>
- 출시 블로그 (모델 카드 내 링크): <https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/>
- Technical report: <https://arxiv.org/abs/2607.02770>
