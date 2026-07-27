# 온디바이스 AI

모델이 이 앱에서 맡는 역할과, 그 역할을 그렇게 좁게 정한 이유입니다.

## 모델의 일

문장을 쓰는 것 하나입니다. 계산도, 판단도, 검색도 하지 않습니다.

`GemmaInterpreter`가 모델에 보내는 것은 두 블록뿐입니다.

```
[명식 사실]
사주: 癸未 甲寅 丙寅 甲午 (년월일시 순)
일간: 병丙 화양
오행 분포: 목4 화2 토1 금0 수1
신강약: 신강 (세력비 63%)
발달 십신: 편인3 겁재2
지지 관계: 인오 삼합(화)
현재 대운: 경술(庚戌) 23세~

[섹션] 성격과 기질
[근거]
- (편인) 편인(偏印)이 발달한 사람은 ...
- (겁재) 겁재(劫財)의 기운은 ...

위 근거를 통합해 이 섹션의 해설을 써 주세요.
```

시스템 지시가 못을 박습니다. 제공된 내용만 사용할 것, 새로운 간지나 십신을 만들지 말 것, 근거를 나열하지 말고 흐르는 글로 엮을 것. 모델에게 남은 자유도는 문체뿐입니다.

이 설계의 결과가 셋입니다. 2B급 모델로 충분하고, 명식을 틀리게 말할 수 없고, 모델이 없어도 앱이 완전합니다.

## 모델 선택

| 모델 | 다운로드 | 권장 환경 |
|---|---|---|
| Gemma 4 E2B 4-bit | 약 3.6 GB | 기본. 통합 메모리 8 GB에서도 동작 |
| Gemma 4 E2B QAT 4-bit | 약 4.4 GB | 같은 크기대에서 품질 우위 |
| Gemma 4 E4B 4-bit | 약 5.2 GB | 16 GB 이상 |
| Gemma 4 E4B QAT 4-bit | 약 6.8 GB | 여유 메모리가 있을 때 |

E2B를 기본으로 둔 것은 의도적입니다. 이 작업은 어려운 추론이 아니라 구조화된 사실의 문장화이고, 문장 품질 차이의 대부분은 프롬프트와 규칙 원문이 좌우합니다. 8 GB Mac 사용자를 배제하지 않는 쪽이 낫습니다.

E4B로 올리고 싶은 유혹이 생기지만, 그 전에 규칙 원문을 다듬는 편이 효과가 큽니다.

## 런타임

[mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) 3.31.x를 씁니다. Gemma 4는 이 패키지의 모델 레지스트리에 `gemma4`, `gemma4_unified`, `gemma4_text`로 등록되어 있고, `LLMRegistry.gemma4_e2b_it_4bit` 같은 프리셋도 내장되어 있습니다.

```swift
let configuration = ModelConfiguration(
    id: "mlx-community/gemma-4-e2b-it-4bit",
    extraEOSTokens: ["<turn|>"]
)
let container = try await #huggingFaceLoadModelContainer(
    configuration: configuration
) { progress in
    // Foundation.Progress — fractionCompleted
}

let session = ChatSession(container, instructions: systemPrompt, generateParameters: params)
for try await chunk in session.streamResponse(to: prompt) {
    // 스트리밍 델타
}
```

Ollama를 별도 프로세스로 띄우는 방식은 검토 후 배제했습니다. 사용자에게 별도 설치를 요구하는 순간 네이티브 앱이 아닙니다.

Xcode 빌드 시 `-skipMacroValidation`이 필요합니다. `MLXHuggingFaceMacros`가 매크로 신뢰 승인을 요구하기 때문이며, GUI Xcode에서는 최초 1회 승인 대화상자가 뜹니다.

## 채팅 템플릿

Gemma 4는 시스템 역할을 네이티브로 지원합니다. 구버전 Gemma처럼 시스템 내용을 사용자 턴에 합칠 필요가 없습니다. `ChatSession(instructions:)`이 그대로 시스템 블록으로 렌더링됩니다.

## 라이선스

Gemma 4는 Apache 2.0입니다. Gemma 1~3 및 3n의 Gemma Terms of Use와 다릅니다. Hugging Face에서 게이팅되어 있지 않아 사용자가 로그인이나 약관 동의 없이 내려받을 수 있습니다.

이 저장소는 가중치를 재배포하지 않습니다. 앱이 사용자를 대신해 실행 시점에 Hub에서 받아 사용자의 Mac에만 저장합니다. 재배포가 아니므로 라이선스 부담이 가장 가벼운 경로입니다.

상세 근거와 확인 시점은 [research/on-device-llm.md](./research/on-device-llm.md)에 있습니다.

## 프롬프트 예산

E2B의 컨텍스트는 128K이지만 긴 컨텍스트는 프리필이 느려집니다. 실제 프롬프트는 섹션당 1K 토큰 안쪽이며, 명식 사실 블록은 첫 섹션에만 붙입니다. `ChatSession`이 대화 이력을 유지하므로 이후 섹션은 근거 블록만 보냅니다.

생성 파라미터는 temperature 0.6, maxTokens 700입니다. 낮은 온도는 근거에서 벗어나지 않게 하고, 700 토큰은 2~3문단에 충분합니다.

## 앞으로

LoRA 파인튜닝은 v1.5 이후로 미룹니다. 지식을 넣기 위해서가 아니라 문체를 통일하고 용어를 정확히 쓰게 하기 위해서입니다. "비견"을 "비교하는 성격" 같은 식으로 풀어 쓰는 일을 막는 것이 목적입니다. 사용자 피드백 데이터가 쌓인 뒤에 하는 편이 낫습니다.

Apple Foundation Models 프레임워크를 두 번째 백엔드로 두는 것도 검토 대상입니다. macOS 27에서 `LanguageModelSession`에 MLX를 포함한 여러 모델을 갈아끼울 수 있게 되었으므로, Apple Intelligence를 켠 사용자는 추가 다운로드 없이 쓸 수 있게 됩니다. 지금 구조에서는 `Interpreter` 프로토콜에 구현 하나를 더하는 일입니다.
