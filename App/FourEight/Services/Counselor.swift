import Foundation
import MLXLMCommon
import SajuKit

/// 상담 답변을 쓰는 쪽.
///
/// 모델이 하는 일은 하나다. **앱이 고른 근거를, 사용자가 말한 사정에 맞춰
/// 문장으로 옮긴다.** 무엇에 대한 고민인지 정하는 일(라우팅), 어떤 근거를
/// 쓸지 정하는 일(선별), 위기인지 판단하는 일(안전)은 모델에 오기 전에
/// 결정론적으로 끝나 있다.
///
/// 프로토콜인 이유는 목적지가 여럿이기 때문이다 — 이 앱 안의 Gemma,
/// 이 Mac의 Ollama, 이 Mac 밖의 원격 제공자. 세 경우 모두 **같은
/// `CounselBrief`에서 나온 같은 글자**를 보낸다. 프롬프트는 전송 수단이
/// 아니라 제품이므로 구현마다 다시 쓰지 않는다. 재료와 문장은
/// `CounselBrief`에 있고, 이 프로토콜의 구현체는 나르기만 한다.
protocol Counselor: Sendable {
    func stream(for consultation: Consultation, followUp: String?)
        -> AsyncThrowingStream<String, Error>
}

// MARK: - 온디바이스

/// 이 앱의 프로세스 안에서 쓴다. 글이 네트워크에 나가지 않는다.
///
/// 매 턴 세션을 새로 만든다. 4B 모델은 턴이 쌓이면 시스템 지시를 잊고,
/// 잊는 순간 근거 밖으로 나간다. 그래서 대화 이력을 모델의 기억에 맡기지
/// 않고 매 턴 근거와 최근 발언을 다시 넣는다. 화면에도 그렇게 적는다 —
/// 기억하는 척하지 않는 것이 정직하다.
struct GemmaCounselor: Counselor {
    let container: ModelContainer
    let brief: CounselBrief

    func stream(for consultation: Consultation, followUp: String?)
        -> AsyncThrowingStream<String, Error>
    {
        let text = brief.promptText(for: consultation, followUp: followUp)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var params = GenerateParameters()
                    params.temperature = 0.6
                    params.maxTokens = 700
                    // 턴마다 새 세션. 이력을 모델에 남기지 않는다.
                    // ChatSession.clear()는 non-Sendable 값을 격리 경계
                    // 밖으로 보내야 해서 쓸 수 없고, 어차피 결과가 같다.
                    let session = ChatSession(
                        container,
                        instructions: CounselBrief.instructions,
                        generateParameters: params
                    )
                    for try await chunk in session.streamResponse(to: text) {
                        try Task.checkCancellation()
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
