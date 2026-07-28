# 조사: OpenAI 호환 엔드포인트를 상호운용 대상으로 볼 때

조사일 2026-07-28. 이 문서는 **사실만** 기록합니다. 무엇을 하기로 했는지는
[ADR 0011](../adr/0011-remote-provider-as-a-destination.md)에 있습니다.

## 이 노트를 읽을 때의 주의 — 방법론

조사 도중에 실제로 문제가 생겼고, 그 사실을 남깁니다.

**요약 모델을 거치는 페이지 가져오기는 축자(verbatim) 인용을 보장하지
않습니다.** 이번 조사에서 그 경로가 한 제공자의 400 오류 목록을 없는
소제목으로 재구성하고, 축자가 아닌 문장을 인용처럼 보고한 사례가 있었습니다.
그래서 아래 표는 원시 `curl`로 다시 확보한 것을 기준으로 합니다.

따라서 이 노트에서 **축자로 인용해도 되는 것**은 원시 요청으로 받은 것들뿐입니다
— OpenAI의 OpenAPI 명세, Mistral의 `openapi.yaml`, xAI의 `llms.txt`, 아래
401 실측 본문, 그리고 `RemoteLLM/Tests/RemoteLLMTests/Fixtures/`의 녹화
파일입니다. 그 밖의 인용은 **뜻은 맞지만 축자는 아닙니다.**

조사를 위임할 때 얻은 교훈이기도 합니다. 하위 에이전트가 스스로 근거
강도를 구분해 보고했고, 그것이 이 노트에서 틀린 문장을 걸러 냈습니다.

미확인으로 남은 것은 마지막 절에 모아 두었습니다.

---

## 1. 제공자별 분기

`/v1/chat/completions`를 "OpenAI 호환"이라 부르는 구현들의 실제 차이입니다.

| 제공자 | 뿌리 주소 | `max_tokens` / `max_completion_tokens` | 모르는 항목 | `stream_options.include_usage` |
|---|---|---|---|---|
| OpenRouter | `openrouter.ai/api/v1` | 둘 다, 폐기 표시 없음 | 무시하고 하위 모델 API로 전달 | **폐기됨, "효과 없음"** — 사용량은 항상 마지막 SSE 메시지에 |
| Groq | `api.groq.com/openai/v1` | 호환 페이지에는 **둘 다 없음**; API 참조에는 `max_tokens`에 Deprecated 배지 | 문서에 없음 | `stream_options`는 있음; `include_usage`는 접힌 컨트롤 안이라 **미확인** |
| Together | `api.together.ai/v1` | `max_tokens`만; `max_completion_tokens` 없음 | 문서에 없음 | 두 페이지에 **0회** |
| Mistral | `api.mistral.ai/v1` | `max_tokens`만; 명세에 `max_completion_tokens` **0회** | **명세에 `additionalProperties: false`** | 명세에 **0회** |
| DeepSeek | `api.deepseek.com` (현행 문서에 `/v1` 없음) | `max_tokens`만 | 문서에 없음 | 완전히 문서화, OpenAI와 문구 동일 |
| xAI | `api.x.ai/v1` | 둘 다; `max_tokens`에 `[DEPRECATED]` | 문서에 없음 | 문서화, `include_usage`가 **required** 표시 |
| Anthropic 호환층 | `api.anthropic.com/v1/` | **둘 다 "Fully supported"** | "지원하지 않는 항목 대부분은 오류가 아니라 조용히 무시" | "Fully supported"; 스트리밍 방출 여부는 미기재 |
| Gemini 호환층 | `.../v1beta/openai/` | **둘 다 없음 (0회)** | "조용히 무시" — 다만 본문상 *이미지* 생성에 한정된 서술 | 코드 예시 **안에만** 등장 |
| Ollama | `localhost:11434/v1` | `max_tokens`는 반영; **`max_completion_tokens`는 조용히 무시 — 실측 5 → 420 토큰** | **통과, HTTP 200** (실측: 모르는 항목 + `n:4` + `logit_bias` + `user` + `tool_choice` 전부 무시) | 지원, 규격에 맞는 `choices:[]` 청크 |
| vLLM | `localhost:8000/v1` | `max_tokens` 폐기, `max_completion_tokens`가 이김 | 소스에 `extra="allow"` | 지원 |
| llama.cpp | `127.0.0.1:8080/v1` | `max_tokens`는 별칭, `n_predict`가 정식 | 등록된 항목만 | 등록된 항목 |

**Mistral이 가장 엄격하고, 그 엄격함이 기계로 확인 가능한 유일한 경우입니다.**
자기 명세가 추가 속성을 금지하면서 `stream_options`를 선언하지 않으므로,
`stream_options`를 보내는 클라이언트는 거절되어야 합니다.

`max_completion_tokens`를 **조용히 무시**하는 구현이 있다는 실측(Ollama,
5 → 420 토큰)이 특히 중요합니다. 400을 내주면 알 수 있지만 무시하면 알 수
없고, 사용자는 길이 제한이 걸리지 않은 답을 받습니다.

## 2. 401 실측 — 오류 본문은 통일되어 있지 않다

직접 요청해 받은 응답입니다. 축자입니다.

- **DeepSeek** — 평문 `Authentication Fails (governor)`. JSON이 아닙니다.
- **Together** — `Missing API key`, `Content-Type` 없음.
- **Mistral** — `{"detail":"Unauthorized"}`
- **xAI** — 평평한 `{"code":…,"error":"…"}`. `error`가 객체가 아니라 문자열입니다.
- **Gemini** — 401이 아니라 **404**를 돌려줍니다.
- **OpenRouter, opencode Zen** — `/models`가 인증 없이 열려 있습니다.

마지막 항목이 설계에 직접 영향을 줍니다. **`/v1/models`가 200을 준다는 것이
키가 유효하다는 뜻이 아닙니다.**

JSON이 아닌 본문과 `Content-Type`이 없는 본문이 실재하므로, 오류 처리는
JSON 파싱 실패를 정상 경로로 다뤄야 합니다.

## 3. 한도 헤더 — 두 계열의 형식이 다르다

이 절이 구현을 실제로 바꿨습니다. 조사 전에는 `Retry-After`에 Go duration이
올 수 있다고 보고 양쪽에 두 파서를 걸어 두었습니다. 갈리는 자리가 분명했습니다.

- **`Retry-After`의 형식을 문서화한 제공자는 이 집합에서 하나(Groq)뿐이고,
  초 단위 정수입니다** — `retry-after: 2`, 비고란 "In seconds".
- **Go duration 문자열은 다른 헤더 계열에 있습니다** —
  `x-ratelimit-reset-requests: 2m59.56s`, `x-ratelimit-reset-tokens: 7.66s`.
- **이 집합에서 HTTP 날짜 형식을 쓴다고 문서화한 곳은 없습니다.**
- **Together는 `Retry-After`를 아예 보내지 않습니다.** 세 페이지에 없고,
  신호는 `x-ratelimit-reset`(초 단위 정수)입니다. 또한 동적 한도 이하에서는
  **503**, 초과에서는 429를 씁니다.
- **OpenRouter** — `Retry-After`가 있지만 조건부("모든 제공자가 재시도 힌트를
  돌려준 경우"). 형식 미기재. 성공 응답에는 `X-RateLimit-*`가 없습니다.
- **Anthropic 호환층** — `retry-after` "Fully supported", 형식 미기재.
- **xAI, DeepSeek, Gemini, Mistral** — `Retry-After` 없음, 헤더 이름도 형식도
  없음. (xAI는 35,641줄 export를 grep해 확인, Mistral은 명세 grep.)

같은 표 안에서 단위가 섞이는 사례도 있습니다 — Groq의
`x-ratelimit-limit-requests`는 RPD이고 `x-ratelimit-limit-tokens`는 TPM입니다.

## 4. 정리하지 않은 불일치 — 지우지 말 것

- **Groq가 자기 문서와 어긋납니다.** 호환 페이지는 `logprobs`, `logit_bias`,
  `top_logprobs`, `messages[].name`이 *"will result in a 400 error"*라고
  적고, API 참조는 같은 항목들을 받아들이는 선택 인자로 나열하며
  (`logit_bias`는 *"This is not yet supported by any of our models"*)
  400을 언급하지 않습니다.
- **xAI가 기본값에서 자기와 어긋납니다.** Chat Completions 항목은
  `max_completion_tokens` 기본값을 **128,000**이라 하고, 같은 개념의
  Responses API 항목은 **None** / 모델 최대라고 합니다.
- **Together의 보관 기본값이 자료마다 셋입니다.** 문서는 기본 미보관이라
  하고, 더 최근(2026-05-19)의 약관은 ZDR을 활성화하는 것이며
  *"does not affect any data processed prior"*라고 합니다.
- **Groq의 ZDR 접근 방식**: 서비스 약관은 *"Eligible Customers may enable"*,
  문서 페이지는 언제든 셀프서비스로 가능하다고 합니다.
- **Gemini의 "조용히 무시"**가 어디까지인지 불명확합니다. 그 문장은 이미지
  생성 절에 있고, `store`가 이 엔드포인트에서 400을 낸다는 제3자 보고가
  있습니다. 채팅에 일반화되는지는 미확인입니다.
- **LM Studio의 더미 키**: 서버는 요구하지 않고, Aider는
  `dummy-api-key`를 요구하며, LiteLLM은 필요하다고 하고, Vercel AI SDK는
  보내지 않습니다. **요구는 서버가 아니라 클라이언트 라이브러리에서 옵니다.**
- **Mistral의 문서 색인이 링크하는 한도 페이지가 404입니다.** 벤더 색인의
  깨진 링크이며, Mistral의 429 동작은 미확인입니다.

## 5. 게이트웨이 구독 — opencode

사용자 요청의 출발점이었으므로 따로 적습니다.

- 저장소가 이전했습니다. `sst/opencode`와 `sst/models.dev`가
  **`anomalyco/opencode`** / `anomalyco/models.dev`로 리다이렉트됩니다
  (`gh api repos/sst/opencode` → `"full_name":"anomalyco/opencode"`, 기본
  브랜치 `dev`, MIT). 2026-03-07경 리브랜딩.
- **Zen은 명시적으로 다중 규격입니다.** 문서에 엔드포인트 표가 있습니다 —
  GPT 계열은 `/zen/v1/responses`, Claude와 Qwen3.x는 `/zen/v1/messages`,
  Gemini는 `/zen/v1/models/<id>`, 그리고 Grok·DeepSeek·MiniMax·GLM·Kimi·
  Big Pickle과 모든 `*-free`는 `/zen/v1/chat/completions`입니다.
  **즉 `https://opencode.ai/zen/v1`은 카탈로그의 일부에 대해서만 유효한
  OpenAI 호환 뿌리 주소입니다.**
- 외부 사용을 의도하고 있습니다. 문서의 목표 항목:
  *"Have **no lock-in** by allowing you to use it with any other coding agent."*
- **무료 모델은 인증이 아예 필요 없습니다** (실측): `big-pickle`과
  `deepseek-v4-flash-free`는 `Authorization` 헤더 없이 200을 돌려주고,
  `claude-sonnet-5`와 `gpt-5.5`는 401입니다.
- **구독 요금제는 Zen과 별개의 제품인 opencode Go입니다.** Zen은 종량제이고,
  Go는 첫 달 $5 이후 월 $10, 워크스페이스당 구독자 1명, 뿌리 주소
  **`https://opencode.ai/zen/go/v1`**, 설정 접두사 `opencode-go/<id>`,
  사용 한도 $12/5시간·$30/주·$60/월, 오픈웨이트 모델 16종.
- **Zen의 프라이버시에는 명시된 예외가 있습니다.** 무보관·미학습이 기본이지만,
  무료·스텔스 모델 6종은 수집 데이터를 모델 개선에 쓸 수 있고, 한 모델은
  체험 전용으로 로깅되며, OpenAI와 Anthropic API는 각각 30일 보관합니다.
- **카탈로그 개수가 자료마다 다릅니다.** 라이브 `GET /zen/v1/models`는
  **60**개(폐기된 항목 포함, 일부 최신 모델 누락), 문서 표는 약 62개(반대로
  포함·누락), `models.dev/api.json`의 `opencode`는 **85**개(무료 24종 포함,
  양쪽에 없는 낡은 항목 포함). 셋 다 기록합니다.

설정 표기의 관례도 자료마다 갈립니다. `baseURL`(opencode, Vercel AI SDK) ·
`apiBase`(Continue) · `api_base`(LiteLLM) · `api_url`(Zed) ·
`openAiBaseUrl`(Cline, Roo) · `api`(models.dev) · `OPENAI_API_BASE`(Aider).
**이 집합에서 `base_url`로 쓰는 도구는 없습니다** — 그 표기는 OpenAI Python
SDK의 것입니다.

이름 함정 하나: Roo Code에서 `apiProvider: "openai"`가 OpenAI **호환**
제공자이고, 공식 OpenAI는 `"openai-native"`입니다.

## 6. 녹화한 SSE 응답

`RemoteLLM/Tests/RemoteLLMTests/Fixtures/`에 다섯 개. 전부 실제로 받은
바이트이며 편집하지 않았습니다. 유료 자격증명 없이 닿을 수 있는
엔드포인트에서만 녹화했고, **닿지 못한 곳에는 파일을 만들지 않았습니다** —
지어낸 골든 데이터는 없는 것보다 나쁩니다(테스트를 통과시키면서 아무것도
증명하지 않습니다). llama.cpp·LM Studio·vLLM·429 응답은 그래서 없습니다.

파일에서 확인되는 사실:

- 다섯 개 모두 **LF만** 씁니다. CRLF 경로는 이 골든 데이터로 검증되지 않습니다.
- `opencode-zen-stream.sse`는 `: OPENROUTER PROCESSING` 주석을 5개 보내고,
  **첫 줄이 주석**입니다. 같은 게이트웨이의 다른 경로
  (`opencode-zen-deepseek-stream.sse`)는 주석을 보내지 않습니다 — **같은
  제공자 안에서도 경로에 따라 갈립니다.**
- Zen 두 파일 모두 **`data: [DONE]` 뒤에 프레임이 하나 더** 옵니다
  (`data: {"choices":[],"cost":"0"}`).
- **다섯 개 모두 본문이 0자이고 `finish_reason`이 `length`입니다.** 녹화 시
  토큰 예산이 작아 모델이 전부 추론 토큰으로 썼습니다(`reasoning_tokens`
  16, 23). 그러므로 이 골든 데이터는 프레이밍·잘림·사용량·추론 토큰 무시를
  검증하고 **본문 누적 경로는 검증하지 않습니다.**
- 부수 소득: **"200인데 본문이 비어 있다"가 가상의 경우가 아님**이 증명됩니다.

## 7. 코드에 반영된 두 가지 확인

- **OpenRouter가 커밋된 200 스트림 안에서 `finish_reason: "error"`를
  보냅니다** — 문서로 확인, 옆에 `native_finish_reason`이 함께 옵니다.
  Ollama와 Zen은 200을 커밋하기 **전에** 실패합니다(Zen은 잘못된 모델에
  401을 주는데, 이는 부적절한 상태 코드입니다).
- **질의 문자열을 버리는 결정이 배제하는 것은 Azure뿐입니다.** Gemini는
  실측으로 별개 배제 — 호환 엔드포인트가 `?key=`를 거부하고 헤더를 요구합니다.

## 8. 미확인

- Groq의 `include_usage` 수용 여부 (문서의 접힌 컨트롤 안).
- Mistral의 429 동작 (벤더 색인의 링크가 404).
- llama-server 소스 내부, vLLM의 `extra="forbid"` 이력, LM Studio 변경 이력.
- Anthropic 네이티브 429 헤더 이름.
- Gemini의 "조용히 무시"가 채팅 엔드포인트에 일반화되는지.

이 노트의 어느 결론도 위 항목에 의존하지 않습니다.
