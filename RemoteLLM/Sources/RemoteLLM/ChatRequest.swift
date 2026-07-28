import Foundation

/// 보낼 것.
///
/// **일부러 작다.** OpenAI 호환을 자칭하는 구현은 많지만 규격을 전부
/// 구현하는 곳은 드물고, 모르는 항목을 만나면 무시하는 곳과 400을 내는
/// 곳이 갈린다. 이 앱이 필요한 것은 하나다 — 확정된 근거를 문장으로
/// 옮겨 달라는 요청. `tools`, `response_format`, `logprobs`, `seed`,
/// `presence_penalty` 같은 것은 쓸 데가 없으므로 보내지 않는다.
///
/// 보내지 않는 것은 호환 문제가 생길 수 없다. 항목을 늘리는 것은 이 앱이
/// 지원하는 제공자 목록을 조용히 줄이는 일이다.
public struct ChatRequest: Sendable, Equatable {
    public var model: String
    /// 시스템 지시. 근거 밖으로 나가지 말라는 규약이 여기 있다.
    public var system: String
    /// 확정된 사실과 근거, 그리고 사용자가 적은 사정.
    public var user: String
    public var temperature: Double?
    /// 출력 토큰 상한. **기본은 nil이고, 그것이 이 타입의 결정이다.**
    ///
    /// 처음에는 700을 기본값으로 두었다. 온디바이스 Gemma 경로에서 그대로
    /// 물려받은 값인데, 추론 모델에서는 이 한도가 **생각 + 답변**을 합쳐
    /// 세기 때문에 700이 전부 생각에 쓰이고 본문이 0자로 끝났다.
    /// 실측(`deepseek-v4-flash`):
    ///
    /// ```
    /// max_tokens=700   finish_reason=length  본문 0자    추론 700/700
    /// max_tokens=1500  finish_reason=stop    본문 316자  추론 1204/1409
    /// ```
    ///
    /// 그래서 더 큰 숫자를 고르는 대신 **보내지 않기로 했다.** 근거 셋이다.
    ///
    /// 1. OpenAI가 직접 적는다 — 추론 토큰이 한도에 닿으면 "This might
    ///    occur **before any visible output tokens are produced**, meaning
    ///    you could incur costs for input and reasoning tokens without
    ///    receiving a visible response." 권고는 **최소 25,000 토큰 예약**이다.
    ///    이 앱이 쓰던 700의 35배다.
    /// 2. 성숙한 도구 12개 중 7개가 아무 값도 보내지 않는다(Vercel AI SDK,
    ///    LiteLLM, aider, LangChain, LlamaIndex, opencode 네이티브 경로,
    ///    Zed의 OpenRouter 제공자). 서버 기본값에 맡기는 것이 다수다.
    /// 3. opencode는 추론 모델에 대해 예산을 **지운다** —
    ///    `output.maxOutputTokens = undefined`. 늘리는 것이 아니다.
    ///
    /// 그리고 상한은 애초에 모델의 속성이 아니다. 같은 모델이 업스트림
    /// 라우트에 따라 32,768부터 1,048,576까지 32배로 갈린다. 앱이 고를
    /// 수 있는 옳은 숫자가 없다.
    ///
    /// 사용자가 요금을 묶고 싶으면 설정에서 값을 준다. 그때만 실린다.
    /// 근거: docs/research/reasoning-model-budgets.md.
    public var maxTokens: Int?
    public var compatibility: Compatibility

    public init(
        model: String,
        system: String,
        user: String,
        temperature: Double? = 0.6,
        maxTokens: Int? = nil,
        compatibility: Compatibility = .init()
    ) {
        self.model = model
        self.system = system
        self.user = user
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.compatibility = compatibility
    }

    /// 제공자마다 갈리는 지점.
    ///
    /// 만세력에서 유파가 갈리는 곳을 설정으로 드러낸 것과 같은 이유로
    /// 여기에 둔다. 조용한 기본값 하나를 정답이라 부르면, 다른 쪽을 쓰는
    /// 사용자는 왜 안 되는지 알 방법이 없다.
    ///
    /// 다만 만세력과 다른 점이 하나 있다. 이쪽은 **어느 쪽이 맞는지 서버가
    /// 알려 준다.** 그래서 사용자가 미리 고르게 하지 않고, 400이 오면 그
    /// 원문을 보여주고 해당 스위치를 짚어 준다.
    public struct Compatibility: Sendable, Equatable, Codable, Hashable {
        /// `max_tokens` 대신 `max_completion_tokens`를 쓴다.
        ///
        /// OpenAI가 새 모델에서 `max_tokens`를 거절하며 갈린 지점이다.
        /// **기본으로 켜지 않는다.** 이 이름은 세 갈래로 갈린다.
        ///
        /// - OpenAI: 추론 토큰을 **포함**한 상한.
        /// - xAI: "only applies to visible output tokens (i.e. does not
        ///   apply to tokens used for reasoning)" — **정반대 의미다.**
        /// - Ollama: 구조체에 필드가 아예 없어 **조용히 무시된다.**
        ///   실측 — 32을 요청하고 912 토큰을 생성했다.
        ///
        /// 마지막이 특히 위험하다. 상한을 걸었다고 믿는데 걸리지 않는다.
        /// 그래서 상한을 보낼 때의 기본 이름은 `max_tokens`이고, 이 스위치는
        /// 제공자가 그것을 거절할 때만 켠다.
        public var usesMaxCompletionTokens = false
        /// `temperature`를 아예 보내지 않는다. 고정 온도만 받는 모델이 있다.
        public var omitsTemperature = false
        /// 시스템 지시를 별도 메시지로 두지 않고 사용자 메시지 앞에 붙인다.
        /// system 역할을 받지 않는 구현이 있다.
        public var foldsSystemIntoUser = false
        /// 마지막 청크에 사용량을 실어 달라고 요청한다. OpenAI 확장이며,
        /// 모르는 항목에 400을 내는 제공자가 있으므로 기본은 끈다.
        public var requestsUsage = false

        public init() {}
    }

    /// 요청 본문. 순수 함수이므로 네트워크 없이 검사할 수 있다.
    public func body() throws -> Data {
        var messages: [[String: String]] = []
        if compatibility.foldsSystemIntoUser {
            messages.append(["role": "user", "content": system + "\n\n" + user])
        } else {
            messages.append(["role": "system", "content": system])
            messages.append(["role": "user", "content": user])
        }

        var json: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": true,
        ]
        if let temperature, !compatibility.omitsTemperature {
            json["temperature"] = temperature
        }
        if let maxTokens {
            json[compatibility.usesMaxCompletionTokens ? "max_completion_tokens" : "max_tokens"]
                = maxTokens
        }
        if compatibility.requestsUsage {
            json["stream_options"] = ["include_usage": true]
        }
        return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
    }

    /// 400을 받았을 때, 원문에서 어느 스위치를 짚어 줄지 고른다.
    ///
    /// 자동으로 다시 보내지 않는다. 사용자가 보낸 것과 다른 요청을 앱이
    /// 마음대로 보내면, 무엇이 나갔는지 사용자가 모르게 된다.
    public static func hint(forRejection detail: String?) -> Hint? {
        guard let detail = detail?.lowercased() else { return nil }
        if detail.contains("max_completion_tokens")
            || (detail.contains("max_tokens") && detail.contains("not supported")) {
            return .usesMaxCompletionTokens
        }
        if detail.contains("temperature") {
            return .omitsTemperature
        }
        if detail.contains("system") && (detail.contains("role") || detail.contains("support")) {
            return .foldsSystemIntoUser
        }
        if detail.contains("stream_options") {
            return .dropUsageRequest
        }
        return nil
    }

    public enum Hint: Equatable, Sendable {
        case usesMaxCompletionTokens
        case omitsTemperature
        case foldsSystemIntoUser
        case dropUsageRequest

        public var message: String {
            switch self {
            case .usesMaxCompletionTokens:
                "이 제공자는 `max_tokens`를 받지 않습니다. 설정에서 `max_completion_tokens`로 바꿔 다시 시도해 보세요."
            case .omitsTemperature:
                "이 모델은 온도 지정을 받지 않습니다. 설정에서 온도를 보내지 않도록 바꿔 보세요."
            case .foldsSystemIntoUser:
                "이 제공자는 system 역할을 받지 않습니다. 설정에서 지시를 사용자 메시지에 합치도록 바꿔 보세요."
            case .dropUsageRequest:
                "이 제공자는 사용량 보고 요청을 받지 않습니다. 설정에서 그 항목을 꺼 주세요."
            }
        }
    }
}
