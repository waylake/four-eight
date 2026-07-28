import Testing
import Foundation
@testable import RemoteLLM

/// 조각 해석. 여기서 잡으려는 것은 파싱 오류가 아니라 **조용한 실패**다.
@Suite("스트림 해석")
struct ChatStreamTests {
    private func pieces(_ json: String) -> [ChatStreamDecoder.Piece] {
        ChatStreamDecoder().decode(.init(data: json, name: nil))
    }

    @Test("본문 조각")
    func delta() {
        let wire = #"{"choices":[{"delta":{"content":"재성이 "},"finish_reason":null}]}"#
        #expect(pieces(wire) == [.text("재성이 ")])
    }

    @Test("종료 표지는 아무것도 만들지 않는다")
    func doneSentinel() {
        #expect(pieces("[DONE]").isEmpty)
    }

    @Test("빈 delta는 조각이 아니다")
    func emptyDelta() {
        // 첫 청크에 role만 오는 제공자가 있다. 빈 문자열을 이어붙이면
        // 해가 없지만, 조각이 없다는 것과 조각이 비었다는 것을 구분해 둔다.
        #expect(pieces(#"{"choices":[{"delta":{"role":"assistant"}}]}"#).isEmpty)
        #expect(pieces(#"{"choices":[{"delta":{"content":""}}]}"#).isEmpty)
    }

    /// 사고 과정을 본문에 섞으면 사용자는 사주 해설 자리에서 모델의
    /// 혼잣말을 읽는다. 무해한 버그가 아니다 — 이 앱은 모든 문장에 근거가
    /// 붙어 있다고 말하는데, 사고 과정에는 근거가 없다.
    @Test("사고 과정은 본문이 아니다", arguments: [
        #"{"choices":[{"delta":{"reasoning_content":"사용자가 이직을 묻는다"}}]}"#,
        #"{"choices":[{"delta":{"reasoning":"먼저 재성을 본다"}}]}"#,
        #"{"choices":[{"delta":{"thinking":"음"}}]}"#,
    ])
    func reasoningDropped(_ wire: String) {
        #expect(pieces(wire).isEmpty)
    }

    @Test("사고 과정과 본문이 같은 청크에 오면 본문만 남는다")
    func reasoningAlongsideContent() {
        let wire = #"{"choices":[{"delta":{"reasoning":"음","content":"관성이"}}]}"#
        #expect(pieces(wire) == [.text("관성이")])
    }

    /// 토큰 한도에서 잘린 답은 완성된 답처럼 읽힌다. 이 앱은 근거를
    /// 통합한 서술을 만들므로 마지막 문단이 없어도 그럴듯하다.
    /// `finished`로 다루면 아무도 모른다.
    @Test("길이 초과는 정상 종료가 아니다")
    func truncationIsNotSuccess() {
        let wire = #"{"choices":[{"delta":{},"finish_reason":"length"}]}"#
        #expect(pieces(wire) == [.truncated])
    }

    @Test("정상 종료 이유는 그대로 나른다")
    func finishReason() {
        let wire = #"{"choices":[{"delta":{},"finish_reason":"stop"}]}"#
        #expect(pieces(wire) == [.finished(reason: "stop")])
    }

    /// HTTP는 이미 200으로 나갔고 본문에 오류가 실려 온다. 모르는 JSON을
    /// 조용히 버리면 생성이 일찍 끝난 것이 완성된 답처럼 보인다.
    @Test("스트림 도중의 오류를 잡는다")
    func midStreamError() {
        let wire = #"{"error":{"message":"Rate limit exceeded","code":"rate_limit_exceeded"}}"#
        guard case .failure(let error) = pieces(wire).first else {
            Issue.record("오류로 읽지 못했습니다"); return
        }
        #expect(error.detail?.contains("Rate limit exceeded") == true)
        // 제공자가 쓴 코드도 함께 나른다. 사용자가 문서를 찾을 때 쓴다.
        #expect(error.detail?.contains("rate_limit_exceeded") == true)
    }

    @Test("읽을 수 없는 본문을 조용히 버리지 않는다")
    func malformedIsReported() {
        guard case .failure(.malformedStream) = pieces("not json at all").first else {
            Issue.record("읽을 수 없는 본문이 조용히 통과했습니다"); return
        }
    }

    @Test("사용량은 보고할 때만 나른다")
    func usage() {
        let wire = #"{"choices":[],"usage":{"prompt_tokens":812,"completion_tokens":344}}"#
        #expect(pieces(wire) == [.usage(prompt: 812, completion: 344)])
        // 보고하지 않는 제공자가 있다. 그때 0을 만들어내지 않는다 —
        // 모른다고 말하는 것이 지어내는 것보다 낫다.
        #expect(pieces(#"{"choices":[],"usage":null}"#).isEmpty)
        #expect(pieces(#"{"choices":[{"delta":{"content":"x"}}]}"#) == [.text("x")])
    }

    /// 스트리밍을 요청했는데 완성된 응답을 돌려주는 구현이 있다.
    /// 조각이 `delta`가 아니라 `message`에 온다.
    @Test("비스트리밍 응답도 읽는다")
    func nonStreamingShape() {
        let wire = #"{"choices":[{"message":{"role":"assistant","content":"전문"},"finish_reason":"stop"}]}"#
        #expect(pieces(wire) == [.text("전문"), .finished(reason: "stop")])
    }
}

@Suite("응답 관문")
struct ResponseGateTests {
    /// 401 본문은 SSE가 아니다. SSE 파서에 넣으면 이벤트가 하나도 나오지
    /// 않고, 그러면 "모델이 빈 답을 냈다"로 보인다. 본문을 읽기 전에
    /// 상태 코드로 갈라야 한다.
    @Test("2xx가 아니면 오류 본문을 읽는다", arguments: [400, 401, 402, 403, 404, 422, 429, 500, 503])
    func errorStatuses(_ status: Int) {
        #expect(ChatClient.ResponseGate.check(status: status, contentType: "application/json")
            == .readErrorBody)
    }

    @Test("event-stream이면 스트림으로 읽는다")
    func eventStream() {
        #expect(ChatClient.ResponseGate.check(
            status: 200, contentType: "text/event-stream; charset=utf-8") == .stream)
    }

    @Test("Content-Type이 없어도 통과시킨다")
    func missingContentType() {
        // 규격 위반이지만 스트림 자체는 정상인 구현이 있다. 여기서 막으면
        // 동작하는 조합을 앱이 거절하게 된다.
        #expect(ChatClient.ResponseGate.check(status: 200, contentType: nil) == .stream)
    }

    @Test("200 + JSON은 본문을 봐야 안다")
    func jsonBody() {
        #expect(ChatClient.ResponseGate.check(status: 200, contentType: "application/json")
            == .readWholeBody)
    }

    @Test("200 + HTML은 API 주소가 아니다")
    func htmlBody() {
        // 사용자가 문서 페이지 주소나 프록시 로그인 페이지를 넣은 경우다.
        // "빈 답"이 아니라 주소가 틀렸다고 말해야 한다.
        #expect(ChatClient.ResponseGate.check(status: 200, contentType: "text/html")
            == .notStream(contentType: "text/html"))
    }
}

@Suite("종료 이유")
struct FinishReasonTests {
    /// `stop`만 성공이다. 처음에는 `length`만 따로 빼고 나머지를 전부 정상
    /// 종료로 다뤘는데, 그러면 OpenRouter가 200 스트림 안에서 보내는
    /// `finish_reason: "error"`가 조용히 성공으로 통과한다. HTTP 상태는 이미
    /// 200으로 나갔으므로 이 값이 유일한 신호다.
    @Test("stop만 성공이다")
    func onlyStopSucceeds() {
        #expect(ChatStreamDecoder.piece(forFinishReason: "stop") == .finished(reason: "stop"))
        #expect(ChatStreamDecoder.piece(forFinishReason: "length") == .truncated)
        #expect(ChatStreamDecoder.piece(forFinishReason: "error")
            == .failure(.midStreamFinish(reason: "error")))
        #expect(ChatStreamDecoder.piece(forFinishReason: "content_filter")
            == .failure(.contentFiltered))
    }

    /// 모르는 값은 정상 종료로 둔다. 실패로 바꾸면 규격에 없는 값을 쓰는
    /// 제공자에서 동작하는 조합을 앱이 거절하게 된다.
    @Test("모르는 값은 거절하지 않는다", arguments: ["tool_calls", "function_call", "eos", ""])
    func unknownReasonsPass(_ reason: String) {
        #expect(ChatStreamDecoder.piece(forFinishReason: reason) == .finished(reason: reason))
    }

    @Test("스트림 안의 error 종료가 실패로 올라온다")
    func errorFinishInStream() {
        let wire = #"{"choices":[{"delta":{},"finish_reason":"error"}]}"#
        let pieces = ChatStreamDecoder().decode(.init(data: wire, name: nil))
        guard case .failure(.midStreamFinish) = pieces.first else {
            Issue.record("200 안의 error 종료가 조용히 통과했습니다"); return
        }
    }
}
