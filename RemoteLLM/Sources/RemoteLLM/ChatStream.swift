import Foundation

/// SSE 이벤트를 이 앱이 쓸 조각으로 옮기는 층.
///
/// 여기서 조심하는 것은 파싱이 아니라 **조용한 실패**다. HTTP는 200이고
/// 이벤트도 정상으로 보이는데 사용자가 받은 글은 틀린 경우가 셋 있다.
///
/// 1. 답이 토큰 한도에서 잘렸다 (`finish_reason == "length"`). 잘린 문장은
///    완성된 문장처럼 보인다. 이 앱은 근거를 통합한 서술을 만들므로 마지막
///    문단이 없어도 그럴듯하게 읽힌다. 표시하지 않으면 아무도 모른다.
/// 2. 스트림 도중에 오류 객체가 온다. 상태 코드는 이미 200으로 나갔으므로
///    HTTP만 보면 성공이다. 모르는 JSON을 조용히 버리면 생성이 그냥 일찍
///    끝나고, 그것도 완성된 답처럼 보인다.
/// 3. 모델의 사고 과정(`reasoning`, `reasoning_content`)이 본문에 섞인다.
///    이어붙이면 사용자는 사주 해설 자리에서 모델의 혼잣말을 읽는다.
///
/// 셋 다 "그럴듯하게 틀리는" 실패다. 이 저장소가 모델에게 계산을 맡기지
/// 않는 이유와 같은 종류의 위험이므로, 셋 다 명시적으로 다룬다.
public struct ChatStreamDecoder: Sendable {
    public init() {}

    public enum Piece: Equatable, Sendable {
        /// 사용자에게 보여줄 본문 조각.
        case text(String)
        /// 모델이 생각한 **분량만**. 내용은 담지 않는다.
        ///
        /// 사고 과정은 이 앱의 산출물이 아니므로 글자를 나르지 않는다.
        /// 그런데 분량은 알아야 한다 — "추론이 예산을 다 써서 본문이 0자"인
        /// 상황을 진단하는 유일한 신호이기 때문이다.
        ///
        /// `usage.completion_tokens_details.reasoning_tokens`를 쓰면 될 것
        /// 같지만 **로컬 런타임은 그 필드를 내보내지 않는다** — Ollama,
        /// llama.cpp, vLLM 모두 없다(실측). 반면 추론 델타 자체는 온다.
        /// 이미 파싱해서 버리고 있으므로 세는 것은 공짜다.
        case reasoning(chars: Int)
        /// 모델이 스스로 끝냈다. 정상 종료.
        case finished(reason: String?)
        /// 토큰 한도에서 잘렸다. 정상 종료가 아니다.
        case truncated
        /// 제공자가 알려 준 토큰 사용량. 보고하지 않는 제공자도 있다.
        case usage(prompt: Int?, completion: Int?)
        /// 스트림 도중에 도착한 오류.
        case failure(ProviderError)
    }

    /// 이벤트 하나를 해석한다. 아무 뜻도 없으면 빈 배열이다.
    public func decode(_ event: SSEParser.Event) -> [Piece] {
        let payload = event.data.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else { return [] }
        // 종료 표지. OpenAI 규약이고 대부분의 제공자가 따른다. 보내지 않고
        // 그냥 연결을 닫는 제공자도 있으므로 이것에만 의존하지 않는다.
        guard payload != "[DONE]" else { return [] }
        guard let data = payload.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            // 모르는 바이트열을 조용히 버리지 않는다. 버리면 스트림이 일찍
            // 끝난 것이 완성된 답처럼 보인다.
            return [.failure(.malformedStream(payload: String(payload.prefix(400))))]
        }

        // 200으로 시작한 뒤 본문에 실린 오류. 상태 코드만 보면 성공이다.
        if let error = ProviderError.fromBody(root, status: nil) {
            return [.failure(error)]
        }

        var pieces: [Piece] = []

        if let choices = root["choices"] as? [[String: Any]] {
            for choice in choices {
                if let delta = choice["delta"] as? [String: Any] {
                    // `content`만 본문이다. 사고 과정은 글자를 나르지 않고
                    // 분량만 센다.
                    if let text = delta["content"] as? String, !text.isEmpty {
                        pieces.append(.text(text))
                    }
                    if let thought = Self.reasoningLength(in: delta), thought > 0 {
                        pieces.append(.reasoning(chars: thought))
                    }
                }
                // 비스트리밍 응답을 스트리밍처럼 되돌려주는 제공자가 있다.
                // 그 경우 조각이 `delta`가 아니라 `message`에 온다.
                if let message = choice["message"] as? [String: Any],
                   let text = message["content"] as? String, !text.isEmpty {
                    pieces.append(.text(text))
                }
                if let reason = choice["finish_reason"] as? String {
                    pieces.append(Self.piece(forFinishReason: reason))
                }
            }
        }

        if let usage = root["usage"] as? [String: Any] {
            let prompt = usage["prompt_tokens"] as? Int
            let completion = usage["completion_tokens"] as? Int
            if prompt != nil || completion != nil {
                pieces.append(.usage(prompt: prompt, completion: completion))
            }
        }

        return pieces
    }

    /// 이 델타에 실린 사고 과정의 길이.
    ///
    /// 이름이 최소 넷이다 — `reasoning_content`(DeepSeek 계열, 조사한
    /// 카탈로그에서 627건), `reasoning`(Ollama·OpenRouter),
    /// `reasoning_details`(14건), `thinking`. 하나만 보면 다른 제공자에서
    /// 진단 신호를 잃는다.
    static func reasoningLength(in delta: [String: Any]) -> Int? {
        var total = 0
        for key in ["reasoning_content", "reasoning", "reasoning_details", "thinking"] {
            switch delta[key] {
            case let text as String:
                total += text.count
            case let parts as [Any]:
                // `reasoning_details`는 배열로 온다. 내용은 쓰지 않으므로
                // 모양을 다 알 필요 없이 길이만 센다.
                for part in parts {
                    if let text = part as? String { total += text.count }
                    else if let object = part as? [String: Any],
                            let text = object["text"] as? String { total += text.count }
                    else { total += 1 }
                }
            default:
                continue
            }
        }
        return total
    }

    /// `finish_reason`을 어떻게 읽을지.
    ///
    /// **`stop`만 성공이다.** 처음에는 `length`만 따로 빼고 나머지를 전부
    /// 정상 종료로 다뤘는데, 그러면 두 가지가 조용히 성공으로 통과한다.
    ///
    /// - `error` — OpenRouter가 200 스트림 안에서 오류를 알리는 방식이다.
    ///   상태 코드는 이미 성공으로 나갔으므로 이 값이 유일한 신호다.
    /// - `content_filter` — 제공자가 내용을 걸렀다. 사용자가 받은 글은
    ///   모델이 쓰려던 글이 아니다. 이 앱의 근거는 명리 문헌이므로 걸릴
    ///   이유가 없어 보이지만, 사용자가 적은 고민이 함께 나가고 그쪽이
    ///   걸릴 수 있다. 걸렸다는 사실을 알려야 한다.
    ///
    /// 모르는 값은 정상 종료로 둔다. 여기서 실패로 바꾸면 규격에 없는 값을
    /// 쓰는 제공자에서 동작하는 조합을 앱이 거절하게 된다.
    static func piece(forFinishReason reason: String) -> Piece {
        switch reason {
        case "length":
            .truncated
        case "error":
            .failure(.midStreamFinish(reason: reason))
        case "content_filter":
            .failure(.contentFiltered)
        default:
            .finished(reason: reason)
        }
    }
}
