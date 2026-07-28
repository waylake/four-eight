import Foundation

/// 제공자가 거절했을 때.
///
/// 이 타입의 목적은 분류가 아니라 **전달**이다. 제공자마다 오류 본문
/// 모양이 다르고, 이 앱이 그 차이를 다 아는 척하면 모르는 오류를 "생성
/// 실패"로 뭉갠다. 그러면 사용자는 주소가 틀린 것인지 키가 틀린 것인지
/// 잔액이 없는 것인지 모른 채로 남는다.
///
/// 그래서 **제공자가 쓴 문장을 그대로 나른다.** 이 앱이 아는 것(상태 코드가
/// 뜻하는 것, 무엇을 하면 되는지)은 덧붙이고, 모르는 것은 원문으로 둔다.
/// "모른다"는 품질 기준이지 실패가 아니다.
public enum ProviderError: Error, Equatable, Sendable {
    /// 키가 없거나 틀렸다 (401, 403).
    case unauthorized(detail: String?)
    /// 이 주소에 그런 것이 없다 (404). 대개 경로가 틀린 것이다.
    case notFound(detail: String?)
    /// 요청을 제공자가 이해하지 못했다 (400, 422).
    case rejected(detail: String?)
    /// 한도 초과 (429). `retryAfter`는 제공자가 알려 준 초 단위 값.
    case rateLimited(retryAfter: TimeInterval?, detail: String?)
    /// 잔액·크레딧 부족 (402).
    case paymentRequired(detail: String?)
    /// 제공자 쪽 문제 (5xx).
    case serverError(status: Int, detail: String?)
    /// 그 밖의 상태 코드.
    case unexpectedStatus(status: Int, detail: String?)
    /// 응답이 SSE가 아니다. 대개 주소가 API가 아닌 곳을 가리킨다.
    case notEventStream(contentType: String?, body: String?)
    /// 스트림 안에 읽을 수 없는 것이 있었다.
    case malformedStream(payload: String)
    /// 200 스트림 안에서 `finish_reason`으로 실패를 알렸다.
    /// OpenRouter가 이 방식을 쓴다.
    case midStreamFinish(reason: String)
    /// 제공자가 내용을 걸렀다.
    case contentFiltered
    /// 네트워크가 닿지 않았다.
    case transport(String)

    // MARK: - 본문에서 읽어내기

    /// 오류 본문에서 사람이 읽을 문장을 뽑는다.
    ///
    /// 관용적인 모양을 순서대로 시도한다. 하나로 통일하려 하지 않는 이유는
    /// 실제로 통일되어 있지 않기 때문이다 — 자료 간 불일치를 지우지 않는
    /// 것과 같은 태도다.
    public static func detail(from root: [String: Any]) -> String? {
        // `{"error":{"message":"..."}}` — OpenAI 계열.
        if let error = root["error"] as? [String: Any] {
            if let message = error["message"] as? String, !message.isEmpty {
                // 코드가 따로 있으면 함께 보여준다. 사용자가 문서를 찾을 때 쓴다.
                if let code = error["code"] as? String, !code.isEmpty {
                    return "\(message) (\(code))"
                }
                if let type = error["type"] as? String, !type.isEmpty {
                    return "\(message) (\(type))"
                }
                return message
            }
            // `{"error":{...}}`인데 message가 없으면 통째로 보여준다.
            if let data = try? JSONSerialization.data(withJSONObject: error),
               let text = String(data: data, encoding: .utf8) {
                return text
            }
        }
        // `{"error":"..."}` — Ollama 등.
        if let error = root["error"] as? String, !error.isEmpty { return error }
        // 최상위 `message`.
        if let message = root["message"] as? String, !message.isEmpty { return message }
        // `{"detail":"..."}` — vLLM·FastAPI 계열.
        if let detail = root["detail"] as? String, !detail.isEmpty { return detail }
        return nil
    }

    /// 본문이 오류를 담고 있으면 해당 오류를, 아니면 nil.
    ///
    /// `status`가 nil이면 스트림 도중에 온 것이다 — HTTP는 이미 200으로
    /// 나갔으므로 상태 코드로는 알 수 없고 본문만이 근거다.
    public static func fromBody(_ root: [String: Any], status: Int?) -> ProviderError? {
        let hasErrorKey = root["error"] != nil
            || (root["object"] as? String) == "error"
            || (root["type"] as? String) == "error"
        guard hasErrorKey else { return nil }
        return from(status: status ?? 200, detail: detail(from: root), retryAfter: nil)
    }

    public static func from(status: Int, detail: String?, retryAfter: TimeInterval?) -> ProviderError {
        switch status {
        case 400, 422: .rejected(detail: detail)
        case 401, 403: .unauthorized(detail: detail)
        case 402: .paymentRequired(detail: detail)
        case 404: .notFound(detail: detail)
        case 429: .rateLimited(retryAfter: retryAfter, detail: detail)
        case 500...599: .serverError(status: status, detail: detail)
        // 200인데 이 함수까지 왔다면 본문에 오류가 실린 경우다.
        case 200...299: .rejected(detail: detail)
        default: .unexpectedStatus(status: status, detail: detail)
        }
    }

    /// 제공자가 알려 준 재시도 대기 시간.
    ///
    /// 헤더 두 계열의 형식이 **다르고**, 처음에는 그것을 몰라 양쪽에 두
    /// 파서를 다 걸어 두었다. 조사해 보니 갈리는 자리가 분명했다.
    ///
    /// - `Retry-After` — 형식을 문서화한 제공자는 하나뿐이고 **초 단위
    ///   정수**다. 이 집합에서 HTTP 날짜 형식을 쓴다고 문서화한 곳은 없다.
    /// - `x-ratelimit-reset-*` — Go duration 문자열이 여기 있다
    ///   (`2m59.56s`, `7.66s`). 초 단위 정수만 기대하면 대기 시간을 잃는다.
    /// - `x-ratelimit-reset` — 초 단위 정수를 쓰는 제공자가 있다.
    ///   `Retry-After`를 아예 보내지 않고 이것만 쓰는 곳도 있다.
    ///
    /// 그래도 각 이름에 두 파서를 다 시도한다. 형식을 문서화하지 않은
    /// 제공자가 대부분이므로 이름으로 형식을 단정하면 읽을 수 있는 값을
    /// 버리게 된다. 순서는 우선순위이지 형식 선언이 아니다.
    ///
    /// 근거: docs/research/remote-llm-providers.md.
    public static func retryAfter(from headers: [AnyHashable: Any]) -> TimeInterval? {
        let names = [
            // 표준 헤더가 먼저다. 있으면 그것이 제공자의 명시적 지시다.
            "Retry-After",
            "retry-after",
            // 한도 계열. Go duration이 실제로 관측되는 자리.
            "x-ratelimit-reset-requests",
            "x-ratelimit-reset-tokens",
            "x-ratelimit-reset",
        ]
        for name in names {
            guard let raw = headers[name] as? String else { continue }
            if let seconds = TimeInterval(raw.trimmingCharacters(in: .whitespaces)) {
                return seconds
            }
            if let seconds = parseGoDuration(raw) { return seconds }
        }
        return nil
    }

    /// `"6m0s"`, `"1.5s"`, `"200ms"` 형태. Go의 duration 표기이며 여러
    /// 제공자가 한도 헤더에 이 형식을 쓴다. 초 단위 정수만 기대하고
    /// `TimeInterval(_:)`에 넣으면 nil이 되어 대기 시간을 잃는다.
    static func parseGoDuration(_ raw: String) -> TimeInterval? {
        let text = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !text.isEmpty else { return nil }
        var total: TimeInterval = 0
        var number = ""
        var unit = ""
        var matched = false

        func flush() -> Bool {
            guard let value = Double(number) else { return false }
            let factor: TimeInterval? = switch unit {
            case "ms": 0.001
            case "s": 1
            case "m": 60
            case "h": 3600
            case "us", "µs": 0.000_001
            case "ns": 0.000_000_001
            default: nil
            }
            guard let factor else { return false }
            total += value * factor
            matched = true
            number = ""
            unit = ""
            return true
        }

        for character in text {
            if character.isNumber || character == "." {
                // 단위 뒤에 숫자가 다시 나오면 앞 항이 끝난 것이다.
                if !unit.isEmpty, !flush() { return nil }
                number.append(character)
            } else {
                guard !number.isEmpty else { return nil }
                unit.append(character)
            }
        }
        if !unit.isEmpty, !flush() { return nil }
        // 단위 없이 숫자만 남았다면 이 표기가 아니다.
        guard matched, number.isEmpty else { return nil }
        return total
    }
}

extension ProviderError {
    /// 제공자가 쓴 원문. 없을 수 있다.
    public var detail: String? {
        switch self {
        case .unauthorized(let d), .notFound(let d), .rejected(let d),
             .paymentRequired(let d):
            d
        case .rateLimited(_, let d), .serverError(_, let d), .unexpectedStatus(_, let d):
            d
        case .notEventStream(_, let body):
            body
        case .malformedStream(let payload):
            payload
        case .midStreamFinish(let reason):
            "finish_reason: \(reason)"
        case .contentFiltered:
            nil
        case .transport(let message):
            message
        }
    }

    /// 이 앱이 아는 것 — 무엇이 일어났고 무엇을 하면 되는가.
    ///
    /// 제공자 원문을 대체하지 않는다. 둘 다 보여준다.
    public var guidance: String {
        switch self {
        case .unauthorized:
            "키가 없거나 이 주소에서 받아들여지지 않았습니다. 설정에서 키를 다시 넣어 보세요."
        case .notFound:
            "이 주소에 그런 것이 없습니다. 주소 끝이 `/v1`인지, 모델 이름이 맞는지 확인해 주세요. 설정 화면에 실제로 호출되는 주소가 표시됩니다."
        case .rejected:
            "제공자가 요청을 받아들이지 않았습니다. 아래 원문에 어느 항목이 문제인지 적혀 있는 경우가 많습니다."
        case .rateLimited(let retryAfter, _):
            if let retryAfter {
                "요청 한도에 걸렸습니다. \(Int(retryAfter.rounded()))초 뒤에 다시 시도할 수 있습니다."
            } else {
                "요청 한도에 걸렸습니다. 잠시 뒤에 다시 시도해 주세요."
            }
        case .paymentRequired:
            "이 제공자의 잔액이나 크레딧이 부족합니다."
        case .serverError(let status, _):
            "제공자 쪽에서 오류가 났습니다 (\(status)). 이 앱이 할 수 있는 일은 없고, 잠시 뒤 다시 시도하는 것뿐입니다."
        case .unexpectedStatus(let status, _):
            "예상하지 못한 응답입니다 (\(status))."
        case .notEventStream(let contentType, _):
            "이 주소가 스트리밍 응답을 돌려주지 않았습니다\(contentType.map { " (\($0))" } ?? ""). API 주소가 아닌 곳을 가리키고 있을 수 있습니다."
        case .malformedStream:
            "응답 도중에 읽을 수 없는 내용이 왔습니다. 받은 글은 그대로 남아 있고, 이어서 만들 수 있습니다."
        case .midStreamFinish:
            "제공자가 응답 도중에 오류로 끝냈습니다. HTTP 상태는 성공이었으므로 원인은 제공자 쪽에 있습니다. 받은 글은 그대로 남아 있습니다."
        case .contentFiltered:
            "제공자가 이 요청의 내용을 걸렀습니다. 명리 근거가 아니라 적어 주신 글이 걸렸을 수 있습니다."
        case .transport:
            "연결하지 못했습니다. 주소와 네트워크를 확인해 주세요."
        }
    }
}

extension ProviderError: LocalizedError {
    public var errorDescription: String? {
        guard let detail, !detail.isEmpty else { return guidance }
        return "\(guidance)\n\n제공자 응답: \(detail)"
    }
}
