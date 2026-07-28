import Testing
import Foundation
@testable import RemoteLLM

@Suite("요청 본문")
struct ChatRequestTests {
    private func json(_ request: ChatRequest) throws -> [String: Any] {
        let data = try request.body()
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private let sample = ChatRequest(
        model: "gpt-4o-mini", system: "지시", user: "근거"
    )

    @Test("기본 본문에는 필요한 것만 있다")
    func minimalBody() throws {
        let body = try json(sample)
        // 항목을 늘리는 것은 이 앱이 지원하는 제공자 목록을 조용히 줄이는
        // 일이다. 규격에 있다는 이유로 보내지 않는다.
        #expect(Set(body.keys) == ["model", "messages", "stream", "temperature", "max_tokens"])
        #expect(body["stream"] as? Bool == true)
    }

    @Test("쓸 데 없는 항목을 보내지 않는다", arguments: [
        "tools", "tool_choice", "response_format", "logprobs", "seed",
        "presence_penalty", "frequency_penalty", "top_p", "n", "stop",
        "stream_options", "user", "metadata",
    ])
    func doesNotSendUnusedFields(_ field: String) throws {
        #expect(try json(sample)[field] == nil)
    }

    @Test("system과 user가 따로 간다")
    func twoMessages() throws {
        let messages = try #require(try json(sample)["messages"] as? [[String: String]])
        #expect(messages.count == 2)
        #expect(messages[0]["role"] == "system")
        #expect(messages[1]["role"] == "user")
    }

    @Test("system 역할을 받지 않는 구현을 위해 합칠 수 있다")
    func foldsSystem() throws {
        var request = sample
        request.compatibility.foldsSystemIntoUser = true
        let messages = try #require(try json(request)["messages"] as? [[String: String]])
        #expect(messages.count == 1)
        #expect(messages[0]["role"] == "user")
        // 지시가 사라지면 모델이 근거 밖으로 나간다. 합칠 때도 남아야 한다.
        #expect(messages[0]["content"]?.contains("지시") == true)
        #expect(messages[0]["content"]?.contains("근거") == true)
    }

    @Test("max_completion_tokens로 바꿀 수 있다")
    func maxCompletionTokens() throws {
        var request = sample
        request.compatibility.usesMaxCompletionTokens = true
        let body = try json(request)
        #expect(body["max_tokens"] == nil)
        #expect(body["max_completion_tokens"] as? Int == 700)
    }

    @Test("온도를 빼면 항목 자체가 없다")
    func omitsTemperature() throws {
        var request = sample
        request.compatibility.omitsTemperature = true
        // null로 보내면 "지정했다"로 읽는 구현이 있다. 아예 없어야 한다.
        #expect(try json(request)["temperature"] == nil)
    }

    @Test("사용량 보고는 요청할 때만 붙는다")
    func usageOptIn() throws {
        var request = sample
        request.compatibility.requestsUsage = true
        let options = try #require(try json(request)["stream_options"] as? [String: Any])
        #expect(options["include_usage"] as? Bool == true)
    }

    @Test("400 원문에서 어느 스위치인지 짚는다", arguments: [
        ("Unsupported parameter: 'max_tokens' is not supported with this model. Use 'max_completion_tokens' instead.",
         ChatRequest.Hint.usesMaxCompletionTokens),
        ("Unsupported value: 'temperature' does not support 0.6 with this model.",
         .omitsTemperature),
        ("Developer instruction is not enabled: system role is not supported",
         .foldsSystemIntoUser),
        ("Unrecognized request argument supplied: stream_options",
         .dropUsageRequest),
    ])
    func hints(_ detail: String, _ expected: ChatRequest.Hint) {
        // 자동으로 다시 보내지 않는다. 사용자가 보낸 것과 다른 요청을 앱이
        // 마음대로 보내면 무엇이 나갔는지 사용자가 모르게 된다.
        #expect(ChatRequest.hint(forRejection: detail) == expected)
    }

    @Test("짚을 수 없으면 짚지 않는다")
    func noHintWhenUnknown() {
        #expect(ChatRequest.hint(forRejection: "Invalid model id") == nil)
        #expect(ChatRequest.hint(forRejection: nil) == nil)
    }
}

@Suite("키가 새어 나갈 자리")
struct RedactionTests {
    /// 주소에 붙은 질의 문자열을 버리는 것은 경로 이어붙이기 문제만이
    /// 아니다. `?api_key=`로 키를 받는 제공자가 있고, 그 주소를 그대로
    /// 저장하면 키가 UserDefaults와 오류 메시지와 화면에 남는다.
    /// 키는 Keychain에만 있어야 한다.
    @Test("주소에 실린 키는 정규화에서 버려진다")
    func stripsCredentialsFromURL() throws {
        let endpoint = try Endpoint.normalize("https://api.example.com/v1?api_key=sk-secret-value")
        #expect(!endpoint.base.absoluteString.contains("sk-secret-value"))
        #expect(!endpoint.chatCompletions.absoluteString.contains("sk-secret-value"))
    }

    @Test("요청 본문에 키가 들어가지 않는다")
    func keyIsNotInBody() throws {
        // 키는 Authorization 헤더에만 실린다. 본문에 넣는 구현으로
        // 바뀌면 그 본문이 확인 화면에 그대로 표시되므로 화면에 노출된다.
        let request = ChatRequest(model: "m", system: "s", user: "u")
        let body = String(decoding: try request.body(), as: UTF8.self)
        #expect(!body.lowercased().contains("authorization"))
        #expect(!body.lowercased().contains("api_key"))
    }
}

@Suite("제공자 오류")
struct ProviderErrorTests {
    private func detail(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return ProviderError.detail(from: root)
    }

    /// 오류 본문 모양은 실제로 통일되어 있지 않다. 하나로 정리하려 하지
    /// 않고 관용적인 것들을 순서대로 시도한다.
    @Test("여러 모양의 오류 본문에서 문장을 뽑는다", arguments: [
        (#"{"error":{"message":"Incorrect API key provided","type":"invalid_request_error"}}"#,
         "Incorrect API key provided"),
        (#"{"error":"model 'llama3' not found"}"#, "model 'llama3' not found"),
        (#"{"message":"Unauthorized"}"#, "Unauthorized"),
        (#"{"detail":"Not Found"}"#, "Not Found"),
    ])
    func extractsDetail(_ json: String, _ expected: String) {
        #expect(detail(json)?.contains(expected) == true)
    }

    @Test("상태 코드를 분류한다", arguments: [
        (401, "unauthorized"), (403, "unauthorized"), (402, "paymentRequired"),
        (404, "notFound"), (400, "rejected"), (422, "rejected"),
        (429, "rateLimited"), (500, "serverError"), (503, "serverError"),
    ])
    func classifies(_ status: Int, _ kind: String) {
        let error = ProviderError.from(status: status, detail: nil, retryAfter: nil)
        let matches = switch (error, kind) {
        case (.unauthorized, "unauthorized"), (.paymentRequired, "paymentRequired"),
             (.notFound, "notFound"), (.rejected, "rejected"),
             (.rateLimited, "rateLimited"), (.serverError, "serverError"):
            true
        default:
            false
        }
        #expect(matches, "\(status) → \(error)")
    }

    /// `Retry-After`가 초 단위 정수로만 온다고 가정하면, Go duration 표기를
    /// 쓰는 제공자에서 대기 시간을 잃는다. 잃으면 사용자에게 "잠시 뒤"라고만
    /// 말할 수 있고, 실제로 몇 초인지는 응답에 적혀 있었다.
    @Test("Go duration 표기를 읽는다", arguments: [
        ("1s", 1.0), ("6m0s", 360.0), ("200ms", 0.2), ("1.5s", 1.5),
        ("1h30m0s", 5400.0), ("2m30s", 150.0),
    ])
    func goDuration(_ raw: String, _ expected: TimeInterval) throws {
        let seconds = try #require(ProviderError.parseGoDuration(raw))
        #expect(abs(seconds - expected) < 0.001)
    }

    @Test("초 단위 정수도 읽는다")
    func plainSeconds() {
        #expect(ProviderError.retryAfter(from: ["Retry-After": "20"]) == 20)
        #expect(ProviderError.retryAfter(from: ["retry-after": "20"]) == 20)
    }

    @Test("읽을 수 없으면 짐작하지 않는다", arguments: [
        "Wed, 21 Oct 2026 07:28:00 GMT", "", "soon", "abc",
    ])
    func doesNotGuess(_ raw: String) {
        // 짐작한 값으로 재시도를 자동화하지 않는다. 모른다고 말하는 것이 낫다.
        #expect(ProviderError.retryAfter(from: ["Retry-After": raw]) == nil)
    }

    @Test("모든 오류에 안내 문장이 있다", arguments: [
        ProviderError.unauthorized(detail: nil),
        .notFound(detail: nil),
        .rejected(detail: nil),
        .rateLimited(retryAfter: 30, detail: nil),
        .rateLimited(retryAfter: nil, detail: nil),
        .paymentRequired(detail: nil),
        .serverError(status: 503, detail: nil),
        .unexpectedStatus(status: 418, detail: nil),
        .notEventStream(contentType: "text/html", body: nil),
        .malformedStream(payload: "x"),
        .transport("끊김"),
    ])
    func everyErrorSpeaks(_ error: ProviderError) {
        // "생성 실패"로 뭉개면 사용자는 주소가 틀린 것인지 키가 틀린 것인지
        // 잔액이 없는 것인지 모른 채로 남는다.
        #expect(!error.guidance.isEmpty)
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("제공자 원문을 안내와 함께 보여준다")
    func keepsProviderWording() throws {
        let error = ProviderError.unauthorized(detail: "Incorrect API key provided: sk-***")
        let described = try #require(error.errorDescription)
        #expect(described.contains("Incorrect API key provided"))
        #expect(described.contains(error.guidance))
    }
}

@Suite("한도 헤더")
struct RateLimitHeaderTests {
    /// 헤더 두 계열의 형식이 다르다. 조사 전에는 둘을 같은 것으로 보고
    /// 양쪽에 두 파서를 걸어 두었는데, 실제로는 갈리는 자리가 분명했다.
    ///
    /// `Retry-After`는 초 단위 정수이고, Go duration 문자열은
    /// `x-ratelimit-reset-*`에 있다. 실제로 관측된 값들이다.
    @Test("Retry-After는 초 단위 정수다")
    func retryAfterIsSeconds() {
        #expect(ProviderError.retryAfter(from: ["retry-after": "2"]) == 2)
    }

    @Test("Go duration은 한도 계열 헤더에 온다")
    func goDurationOnRateLimitHeaders() {
        #expect(ProviderError.retryAfter(from: ["x-ratelimit-reset-requests": "2m59.56s"])
            == 179.56)
        #expect(ProviderError.retryAfter(from: ["x-ratelimit-reset-tokens": "7.66s"]) == 7.66)
    }

    /// `Retry-After`를 아예 보내지 않고 이것만 쓰는 제공자가 있다.
    @Test("x-ratelimit-reset 단독도 읽는다")
    func bareResetHeader() {
        #expect(ProviderError.retryAfter(from: ["x-ratelimit-reset": "30"]) == 30)
    }

    /// 표준 헤더가 있으면 그것을 먼저 쓴다. 제공자의 명시적 지시이므로
    /// 한도 계열 헤더에서 계산한 값보다 우선한다.
    @Test("표준 헤더가 우선한다")
    func standardHeaderWins() {
        let headers: [AnyHashable: Any] = [
            "Retry-After": "5",
            "x-ratelimit-reset-requests": "2m59.56s",
        ]
        #expect(ProviderError.retryAfter(from: headers) == 5)
    }

    /// 형식을 문서화하지 않은 제공자가 대부분이므로 이름으로 형식을
    /// 단정하지 않는다. 단정하면 읽을 수 있는 값을 버린다.
    @Test("이름으로 형식을 단정하지 않는다")
    func doesNotAssumeFormatFromName() {
        // Go duration이 표준 헤더에 와도 읽는다.
        #expect(ProviderError.retryAfter(from: ["Retry-After": "1.5s"]) == 1.5)
        // 정수가 한도 계열에 와도 읽는다.
        #expect(ProviderError.retryAfter(from: ["x-ratelimit-reset-tokens": "8"]) == 8)
    }
}
