# 조사: 이질적 모델의 출력 토큰 예산

조사일 2026-07-28. **사실만** 기록합니다. 결정은
[ADR 0011 §8](../adr/0011-remote-provider-as-a-destination.md)에 있습니다.

등급: `[벤더]` 공식 문서 / `[실측]` 직접 실행·소스 열람 / `[3자주장]` 출처
없음 / `[미확인]`.

이 노트의 축자 인용은 전부 `curl`로 받은 원문(HTML·YAML·markdown·소스)에서
왔습니다. 요약기를 거친 인용은 없습니다.

---

## 0. 이 조사를 시작하게 한 증상 [실측]

이 앱은 `max_tokens: 700`을 보내고 있었습니다. 온디바이스 Gemma 경로에서
그대로 물려받은 값입니다. 사용자가 지정한 게이트웨이의
`deepseek-v4-flash`로 실제 해석 프롬프트를 보낸 결과입니다.

| 요청 | `finish_reason` | 본문 | 추론 토큰 |
|---|---|---|---|
| `max_tokens=700` | **length** | **0자** | 700 / 700 |
| `max_tokens=1500` | stop | 316자 | 1204 / 1409 |
| `max_tokens=2500` | stop | 230자 | 1356 / 1516 |
| **항목을 안 보냄** | **stop** | **277자** | 1153 / 1333 |

**700에서는 본문이 한 글자도 나오지 않습니다.** 추론 모델에서 이 한도는
생각과 답변을 합쳐 세기 때문입니다. 사용자에게는 "답이 잘렸습니다"만
보였고, 요금은 나갔습니다.

마지막 행이 이 조사의 결론입니다 — 항목을 보내지 않으면 제공자의 기본값
(이 모델은 384,000)이 쓰이고 정상 동작합니다.

## 1. OpenAI가 이 증상을 문서화하고 있습니다 [벤더]

`https://developers.openai.com/api/docs/guides/reasoning`,
"Allocating space for reasoning" 절 축자:

> If the generated tokens reach the context window limit or the
> max_output_tokens value you've set, you'll receive a response with a status
> of `incomplete` and `incomplete_details` with `reason` set to
> `max_output_tokens`. **This might occur before any visible output tokens
> are produced, meaning you could incur costs for input and reasoning tokens
> without receiving a visible response.**
>
> To prevent this, ensure there's sufficient space in the context window or
> adjust the `max_output_tokens` value to a higher number. **OpenAI
> recommends reserving at least 25,000 tokens for reasoning and outputs**
> when you start experimenting with these models.

같은 페이지 축자:

> While reasoning tokens are not visible via the API, they still occupy space
> in the model's context window and are billed as output tokens.

> Depending on the problem's complexity, the models may generate anywhere from
> a few hundred to tens of thousands of reasoning tokens.

**권고값 25,000은 이 앱이 쓰던 700의 약 35배입니다.**

`max_completion_tokens`의 정의도 같은 것을 말합니다 [벤더,
`openai-openapi` v2.3.0 축자]:

> An upper bound for the number of tokens that can be generated for a
> completion, **including visible output tokens and reasoning tokens**.

**중요한 한계**: 위 가이드는 전부 Responses API의 `max_output_tokens` 기준이고
`max_completion_tokens`는 그 페이지에 0회 등장합니다. Chat Completions의
`finish_reason` enum은 `[stop, length, tool_calls, content_filter,
function_call]`뿐이므로 [벤더, 축자] **"추론이 다 먹었다"를 Chat
Completions에서 구별하는 표준 필드가 없습니다.** OpenAI가 그것을 문서화한
곳은 **[미확인]**입니다.

## 2. 성숙한 도구 12개의 정책 [실측, 소스 직접 열람]

| 도구 | 기본 `max_tokens` 전송? | 유도 근거 |
|---|---|---|
| Vercel AI SDK 7.0.40 | **안 보냄** | 없음 |
| LiteLLM 1.95.0 | **안 보냄** | 없음 |
| aider | **안 보냄** (Anthropic YAML만 예외) | — |
| LangChain 1.4.1 | **안 보냄** (`None` 기본) | 없음 |
| LlamaIndex 0.7.10 | **안 보냄** (`None` 기본) | 없음 |
| opencode 네이티브 경로 | **안 보냄** (Anthropic만 예외) | — |
| Zed OpenRouter 제공자 | **안 보냄** (`max_output_tokens() -> None`) | — |
| opencode AI SDK 경로 | 보냄 | `min(limit.output, 32_000)` |
| Zed (그 외) | 보냄 | 하드코딩 테이블 / 사용자 설정 |
| Cline | 보냄 | 기본 32,000 |
| Roo Code | 갈림 | 8192 / 16384, `min(maxTokens, ctx×0.2)` |
| Continue.dev | 보냄 | `min(model max, ctx/4)` else 4096 |

**12개 중 7개가 아무 값도 보내지 않습니다.** 서버 기본값에 맡기는 것이
소수 취향이 아닙니다.

### 2-1. opencode는 추론 모델에서 예산을 **지웁니다** [실측]

`anomalyco/opencode` `017a5977`, `packages/opencode/src/plugin/cloudflare.ts:64-73`
축자:

```ts
// The unified gateway routes through @ai-sdk/openai-compatible, which
// always emits max_tokens. OpenAI reasoning models (gpt-5.x, o-series)
// reject that field and require max_completion_tokens instead, and the
// compatible SDK has no way to rename it. Drop the cap so OpenAI falls
// back to the model's default output budget.
if (!input.model.api.id.toLowerCase().startsWith("openai/")) return
if (!input.model.capabilities.reasoning) return
output.maxOutputTokens = undefined
```

**추론 모델에 대한 대응이 "예산을 늘린다"가 아니라 "예산을 지운다"입니다.**
테스트가 붙어 있습니다 (`test/plugin/cloudflare.test.ts:42-67`).

### 2-2. Cline은 반대 방향 — 추론 예산을 총 예산의 하한으로 밀어 올립니다 [실측]

`sdk/packages/llms/src/providers/gateway.ts` 축자:

```ts
// Providers like Anthropic require max_tokens to exceed the thinking
// budget, so an explicit reasoning budget lifts the synthesized default
const reasoningFloor = isPositiveFiniteNumber(input.reasoningBudgetTokens)
    ? Math.floor(input.reasoningBudgetTokens) + (input.outputReserveTokens ?? GATEWAY_OUTPUT_RESERVE_TOKENS)
    : 0;
```

**12개 중 유일합니다.** 방향이 §2-1과 정반대이며, 조정하지 않고 둘 다 적습니다.

## 3. 출력 상한은 모델의 속성이 아니라 **라우트의 속성**입니다 [실측]

OpenRouter의 `deepseek-v4-flash` 엔드포인트 목록, 20개 업스트림 라이브 응답:

```
Venice        out=32768        StreamLake   out=384000
DeepInfra     out=65536        DeepSeek     out=384000
Baidu         out=131072       SiliconFlow  out=393216
AkashML       out=131072       Alibaba      out=393216
Ionstream     out=131072       Morph        out=1048576
Cloudflare    out=384000       CoreWeave    out=1048576
GMICloud      out=None         Fireworks    out=None

서로 다른 값: [32768, 65536, 131072, 384000, 393216, 1048576] — 32배 범위
null: 3개
집계 뷰(top_provider)가 보고한 값: 393216
```

**같은 모델 id로 요청해도 상한이 32배로 갈립니다.** 정적 테이블로 표현할 수
없고, 앱이 고를 수 있는 옳은 숫자가 존재하지 않습니다.

두 카탈로그 모두 약 18%의 항목에서 **출력 상한이 컨텍스트보다 크거나
같습니다** [실측] — OpenRouter 299개 non-null 중 42개, models.dev 5802개 중
1017개(17.5%). 텍스트 전용 모델로 좁혀도 17.7%로 거의 변하지 않습니다.

수렴하는 값이 하나 있습니다: **두 카탈로그의 출력/컨텍스트 비율 중앙값이
모두 정확히 0.250**입니다 [실측]. 두 독립 출처가 일치하는 유일한 정량값입니다.

## 4. `max_completion_tokens`는 세 갈래로 갈립니다 [벤더 + 실측]

- **OpenAI** [벤더 축자]: "including visible output tokens and reasoning tokens"
- **xAI** [벤더, `docs.x.ai/llms.txt` 축자]: "**only applies to visible output
  tokens** (i.e. does not apply to tokens used for reasoning or function
  calls). Defaults to 128,000 when unset"
- **Ollama 0.31.1** [실측]: 구조체에 필드가 **없습니다.**
  `openai/openai.go:103` 축자는 `MaxTokens *int \`json:"max_tokens"\`` 하나뿐.
  라이브 측정 — **32을 요청하고 912 토큰을 생성했습니다.**

**같은 이름, 같은 OpenAI 호환 요청 모양, 정반대 의미이고 한 곳에서는 조용히
무시됩니다.** 마지막이 가장 위험합니다 — 상한을 걸었다고 믿는데 걸리지 않습니다.

llama.cpp와 vLLM은 둘 다 받습니다 [실측, 소스].
`tools/server/server-schema.cpp:44-48` 축자: `->add_alias("max_completion_tokens")`.
vLLM은 `max_tokens`를 `deprecated`로 표시하고 `max_completion_tokens`를
우선합니다.

## 5. 보편적으로 통하는 `reasoning_effort` 값은 **하나도 없습니다** [실측]

OpenRouter `/api/v1/models` 라이브 341개 모델 집계:

```
reasoning 객체를 가진 모델:        215 / 341
  supported_efforts를 노출:         83
  supports_max_tokens(수치 예산):    8      ← 215개 중 8개
  reasoning MANDATORY (끌 수 없음):  63

83개 모델 supported_efforts의 교집합:  []   ← 공집합
합집합: [high, low, max, medium, minimal, none, xhigh]

값별 수용 모델 수 (83개 중)
  high 81(98%)  medium 66(80%)  low 65(78%)  xhigh 38(46%)
  max 24(29%)   none 23(28%)    minimal 17(20%)
```

`high`조차 100%가 아닙니다 — `nvidia/nemotron-3-super-120b-a12b`는
`["medium","low"]`뿐입니다 [실측].

`supported_parameters` 빈도 [실측]: `max_tokens` 334 / 341,
**`max_completion_tokens` 53 / 341**. 그리고 목록에 `max_tokens`가 아예 없는
모델이 9개 있습니다.

LiteLLM은 이 비균일성을 **값별 불리언 7개**로 처리합니다 [실측]:
`supports_xhigh_reasoning_effort`(123), `supports_none_reasoning_effort`(82),
`supports_adaptive_thinking`(77), `supports_max_reasoning_effort`(72),
`supports_minimal_reasoning_effort`(70), `supports_low_reasoning_effort`(3),
`bedrock_output_config_effort_ceiling`(30). **하나의 enum을 7개 필드가
표현합니다.**

**"추론 예산 하한/예약값"을 뜻하는 필드는 어느 카탈로그에도 없습니다** [실측]
— `budget`/`reserve`/`min_`를 포함하는 필드는 `prompt_cache_min_tokens`
하나뿐입니다.

### 5-1. 사용자가 지정한 모델의 경우 [벤더]

`https://api-docs.deepseek.com/api/create-chat-completion` 축자:

> **reasoning_effort** `string` Possible values: `[high, max]` — The default
> effort is high for regular requests; for some complex agent requests (such
> as Claude Code, OpenCode), effort is automatically set to max. **For
> compatibility, low and medium are mapped to high**, and xhigh is mapped to max.

> **thinking** `object` `nullable` — **type** Possible values:
> `[enabled, disabled]` — Default value: `enabled`

**추론을 낮추는 노브가 없습니다.** `low`/`medium`을 보내면 오류 없이 `high`로
승격되고, "OpenCode 같은 에이전트 요청"은 자동으로 `max`가 됩니다. 그리고
사용자가 쓰는 엔드포인트가 opencode Zen 게이트웨이입니다.

**게이트웨이가 무엇을 근거로 "OpenCode 요청"이라 판정하는지는 [미확인]**입니다.

## 6. `finish_reason: "length"`는 네 원인을 뭉갠 값입니다 [벤더]

`https://openrouter.ai/docs/api_reference/errors-and-debugging.md` 축자:

> Certain token/length errors are transformed into successful completions
> instead of failures:
>
> | `error_type` | Transformed To | Finish Reason |
> | `context_length_exceeded` | Success | `length` |
> | `max_tokens_exceeded` | Success | `length` |
> | `token_limit_exceeded` | Success | `length` |
> | `string_too_long` | Success | `length` |

원인 정의 축자:

> | `context_length_exceeded` | The combined input and output tokens exceed the model's context window. |
> | `max_tokens_exceeded` | Generation stopped because `max_tokens` (or `max_completion_tokens`) was reached. |
> | `token_limit_exceeded` | A token budget enforced by OpenRouter (e.g. credit-based cap) was exceeded. |

**같은 값이 "예산을 올리면 해결된다", "올리면 악화된다", "올려도 절대 안
된다"를 동시에 뜻합니다.** 응답에 구별할 필드가 없습니다. 자동 재시도를
하지 않는 이유입니다.

## 7. 런타임 능력 탐지 — 와이어에서 얻을 수 있는 것이 거의 없습니다

### 7-1. 맨 `/v1/models`에는 능력 정보가 없습니다 — 확정 [벤더 + 실측]

`openai-openapi` v2.3.0의 `Model` 스키마 전체 축자:

```yaml
Model:
  properties:
    id: {type: string}
    created: {type: integer, format: unixtime}
    object: {type: string, enum: [model]}
    owned_by: {type: string}
  required: [id, object, created, owned_by]
```

필드 4개, 전부 필수. 스펙 전체에서 `capabilit`는 산문에만 등장하고 필드로는
**0회**입니다 [실측, grep].

라이브 확인 [실측]:
- **Ollama 0.31.1**: 4필드 그대로.
- **LM Studio**: `created`조차 없습니다(스펙상 필수). 그런데 **네이티브
  경로 `/api/v0/models`에는 있습니다** — `type`, `arch`, `quantization`,
  `state`, `max_context_length`. **로컬 런타임은 메타데이터를 갖고 있고
  OpenAI 호환 경로에서만 버립니다.**
- **사용자의 게이트웨이 `/v1/models`**: 60개 모델, 전부 4필드. 컨텍스트도,
  출력 상한도, 추론 여부도 없습니다.
- **llama.cpp**는 예외적으로 모달리티·별칭·태그·상태를 실지만 출력 상한과
  추론 정보는 없습니다. 소스 축자 주석: `// TODO: add other fields, may
  require reading GGUF metadata`.

### 7-2. `reasoning_tokens`를 런타임 신호로 쓸 수 없습니다 [실측]

스펙에는 있습니다 [벤더 축자]: `reasoning_tokens` "Tokens generated by the
model for reasoning."

그런데 로컬 런타임이 내보내지 않습니다.
- **Ollama**: `usage` 키가 3개뿐 — `{prompt_tokens, completion_tokens,
  total_tokens}`. 소스 전체에 `reasoning_tokens` 0건.
- **llama.cpp**: 서버 소스 6개 파일 grep에서 0건.
- **vLLM**: `chat_completion/protocol.py`에 0건.

이름도 갈립니다 [벤더]: OpenAI `completion_tokens_details.reasoning_tokens` /
Anthropic `output_tokens_details.thinking_tokens` / Google
`thoughtsTokenCount`.

**추론 텍스트 필드 이름은 최소 넷입니다** [실측, models.dev `interleaved`
필드 집계]: `reasoning_content` 627건, `reasoning_details` 14건, `true` 32건,
그리고 Ollama·OpenRouter의 `reasoning`.

### 7-3. 400 프로브는 런타임마다 다릅니다 [실측]

**Ollama는 잘못된 값에 유효값을 열거해 줍니다** — 라이브:
```
요청: {"reasoning_effort":"banana"}
응답: HTTP 400  invalid reasoning value: 'banana'
                (must be "high", "medium", "low", "max", or "none")
```

**llama.cpp는 반응하지 않습니다** [실측, `server-common.cpp:1089-1094` 축자]:
```cpp
if (reasoning_effort == "none") { inputs.enable_thinking = false; }
// other reasoning_effort values are model-specific and not yet handled
```

그리고 **미지 파라미터는 조용히 삼켜집니다** [실측, 라이브] —
`{"thinking":{...},"totally_bogus_xyz":123}`에 HTTP 200. Go의 JSON
언마샬이 미지 필드를 버립니다.

**"파라미터를 보내 보고 오류로 지원 여부를 판정한다"는 일반 전략은 성립하지
않습니다.**

### 7-4. 카탈로그를 싣는 것의 비용 [실측]

크기: models.dev `api.json` 3,269,802 / LiteLLM 1,669,319 / OpenRouter
533,094 / models.dev `models.json` 220,212 바이트. **작은 쪽(220KB)에는
`reasoning_options`가 0건**이므로 필요한 필드가 정확히 빠져 있습니다.

## 8. 정리하지 않은 불일치

**(가) 사용자가 지정한 그 모델에서 세 출처가 갈립니다** [실측]:

| 출처 | effort 값 | 끌 수 있는가 |
|---|---|---|
| DeepSeek 공식 | `[high, max]` | `thinking:{type:"disabled"}` |
| models.dev | `[{toggle},{effort:[high,max]}]` | toggle 있음 |
| OpenRouter | `["xhigh","high"]`, 기본 `high` | `mandatory:false`이나 `none` 없음 |

부분 설명은 LiteLLM 소스에 있습니다 — OpenRouter 어댑터가 `max` → `xhigh`로
개명합니다 (`litellm/llms/openrouter/chat/transformation.py:58-60`). 그러면
OpenRouter에서 `max`를 보낼 방법과 `xhigh`의 실제 의미가 불분명해집니다.
셋을 그대로 둡니다.

**(나) `claude-sonnet-4-5`의 컨텍스트가 5배 다릅니다** — models.dev
`1000000` vs LiteLLM `200000` [실측].

**(다) LiteLLM 자기 스키마의 자기 모순** [실측, `sample_spec` 축자]:
`max_tokens` "LEGACY parameter. set to max_output_tokens if provider
specifies it. **IF not set to max_input_tokens**". **한 필드가 문맥에 따라
출력 상한 또는 입력 상한을 뜻한다고 스스로 인정합니다.**

**(라) LiteLLM 코드와 주석이 어긋납니다** [실측]. `litellm.max_tokens = 4096`이
`__init__.py:229`에 `# OpenAI Defaults` 주석과 함께 있지만
OpenAI/openai-compatible chat 경로에서 읽히지 않습니다.

**(마) Anthropic은 `budget_tokens`를 폐기하는 중입니다** [벤더 축자]:
"Extended thinking (`thinking.type: "enabled"` with `budget_tokens`) is
deprecated on the Claude 4.6 models... Claude 4.7 and later models do not
support it and **reject requests that use it, returning a 400 error**."
새 노브 `output_config.effort`는 축자로 "Effort is a behavioral signal, **not
a strict token budget**"입니다.

**(바) Gemini 2.5 Pro는 추론을 끌 수 없습니다** [벤더 축자]: 범위 "128 to
32768", 끄기 "**N/A: Cannot disable thinking**". Flash-Lite는 하한이 512인데
끄는 값이 0이므로 **0은 범위 밖의 센티널**입니다. `maxOutputTokens`가
thinking 토큰을 포함하는지는 Google 6개 페이지에 양방향 진술이 없어
**[미확인]**입니다.

## 9. 실패 후 적응 — 선행 사례 [실측]

| | 더 큰 예산으로 자동 재시도 | "추론이 다 먹었음" 특정 | 이어가기 |
|---|---|---|---|
| Cline | 없음 | 없음 — 빈 출력 가드가 진단을 **가림** | 없음 |
| Roo Code | 없음 | 없음 | `"length"`가 프로덕션에 **0회** |
| Continue.dev | 없음 | 없음 | `"length"`를 계산만 하고 읽지 않음 |
| aider | 없음 | 없음 | **있음 — 유일** |
| LangChain / LlamaIndex | 없음 | 없음 | 없음 |
| Vercel AI SDK / LiteLLM / opencode / Zed | 없음 | 없음 | 없음 |

**"아무것도 하지 않고 오류를 올린다"가 압도적 다수입니다.**

### 9-1. Cline은 순서 버그로 진단이 도달 불가입니다 [실측]

탐지는 합니다 (`ai-sdk.ts:525-539`에서 `length` → `max-tokens`). 그런데
`agent-runtime.ts`에서 **빈 출력 검사(646-651행)가 max-tokens
검사(673-674행)보다 먼저** 실행됩니다. 축자:

```ts
if (message.content.length === 0) {
    throw new Error(... "Model returned empty response");
}
...
if (finishReason === "max-tokens" && toolCalls.length === 0) {
	throw new Error(MAX_TOKENS_INCOMPLETE_TURN_MESSAGE);
}
```

**측정한 정확한 상황(추론이 전부 먹고 content 0자, length)에서 Cline은
"Model returned empty response"를 던집니다.** 절단 진단은 도달할 수 없습니다.

### 9-2. aider의 이어가기는 OpenAI 계열에서 작동하지 않고, 반복 가드가 없습니다 [실측]

`base_coder.py:1457-1506`은 부분 assistant 턴을 프리필로 붙여 재발행합니다
(**예산을 올리지 않습니다**). 한계 셋:

1. litellm의 `supports_assistant_prefill`(Anthropic 계열)로 게이팅됩니다.
2. `while True`에 카운터도 상한도 없습니다. **빈 content + length가 반복되면
   무한 재전송입니다** — 측정한 상황이 정확히 그 경우입니다.
3. 빈 content + length와 부분 content + length를 구별하지 않습니다.

### 9-3. 프리필 이어가기가 맨 Ollama에서 작동하지 않습니다 [실측, 직접 측정]

절단된 부분 텍스트를 `{"role":"assistant","content": partial}`로 붙여
재요청한 결과, **이어가지 않고 처음부터 다시 시작했습니다.** Ollama의 채팅
템플릿이 assistant 턴을 닫아 버리기 때문입니다. 별도 프리필 플래그 없이는
중복 생성이 됩니다. DeepSeek는 이를 위해 별도 베타 엔드포인트를 요구합니다
[벤더 축자]: `prefix` "You must set base_url="https://api.deepseek.com/beta""

## 10. 생태계는 수렴하지 않습니다

- **OpenAI 스펙에 능력 탐지 추가가 없습니다** [실측] — v2.3.0(2026-07-27
  커밋)에서 `capabilit`가 필드로 0회.
- **표준 필드 대신 제공자별 플래그가 늡니다** — LiteLLM의 effort 플래그 7개.
- **OpenRouter 변경 이력에도 없습니다** [벤더] — 변경은 `Quantization`,
  `ReasoningFormat`, `ProviderName` enum **확장**입니다.
- **이름 충돌이 늡니다** — `xhigh`가 OpenAI·Anthropic에서 추론 깊이, xAI
  `grok-4.20-multi-agent`에서 **에이전트 수(4 또는 16)**, DeepSeek에서 `max`로
  조용히 재매핑 [벤더].

## 11. 미확인

- opencode Zen이 effort→`max_tokens` 비율 환산을 하는지, 잘못된 값에 무엇을
  반환하는지. 무인증은 401. **키가 있으면 요청 두 번으로 확정 가능합니다.**
- 측정값 `2500 → 추론 1356`이 어느 규칙에서 나오는지. `1500 → 1204`는 80.3%로
  OpenRouter의 `high ≈ 80%`와 근사하지만 2500에서는 54%로 어긋납니다.
  **단일 규칙으로 설명되지 않습니다.**
- Gemini `maxOutputTokens`의 thinking 포함 여부.
- Chat Completions에서 "추론이 다 먹었다"를 OpenAI가 문서화한 곳.
- llama.cpp·vLLM·LiteLLM 라이브 미측정 (소스 열람만). LM Studio는 채팅 모델이
  없어 `/v1/models`만 측정.
- §4의 OpenAI vs xAI 의미 반전은 각 1회 요청으로 확정 가능한 항목이나
  실측하지 않았습니다.
