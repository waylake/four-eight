import Foundation
import MLXLMCommon
import SajuKit

/// 해석 스트림 이벤트.
enum InterpretationChunk: Sendable {
    case sectionStart(id: String)
    case text(sectionID: String, delta: String)
    case sectionEnd(id: String)
    case done
}

/// 해석기 — 확정된 사실과 근거를 문장으로 옮긴다.
///
/// 여기 있는 것은 **비용을 치르는 경로뿐이다.** 규칙 엔진 문장은 해석기가
/// 아니라 `InterpretationSection.baselineText`, 즉 계산 결과의 일부다.
/// 예전에는 규칙 엔진도 이 프로토콜을 구현했는데, 그래서 "해석문을 만든다"는
/// 한 동작에 밀리초짜리와 수십 초짜리가 섞였고 정책도 하나로 묶였다.
///
/// 구현체는 목적지마다 하나씩 있다 — 이 앱 안(`GemmaInterpreter`), 이 Mac
/// 또는 그 밖(`RemoteInterpreter`). 어느 쪽이든 프롬프트는
/// `InterpretationBrief`가 만든 같은 글자다. 전송 층이 프롬프트를 갖게 두면
/// 두 경로의 톤 규약이 어긋나고, 어긋났다는 사실을 아무도 모른다.
///
/// 섹션 부분집합을 받는 것이 중요하다. 재개는 "미완료 섹션만 다시"이므로
/// 해석기가 전체 문서를 전제하면 안 된다.
protocol Interpreter: Sendable {
    func stream(sections: [InterpretationSection]) -> AsyncThrowingStream<InterpretationChunk, Error>
}

// MARK: - 온디바이스

/// Gemma 4 스트리밍. 계산과 판단은 이미 끝났으므로 문장화만 맡는다.
/// 글이 이 앱의 프로세스를 벗어나지 않는다.
struct GemmaInterpreter: Interpreter {
    let container: ModelContainer
    let brief: InterpretationBrief

    func stream(sections: [InterpretationSection]) -> AsyncThrowingStream<InterpretationChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var params = GenerateParameters()
                    params.temperature = 0.6
                    params.maxTokens = 700
                    let session = ChatSession(
                        container,
                        instructions: brief.instructions,
                        generateParameters: params
                    )

                    for (index, section) in sections.enumerated() {
                        try Task.checkCancellation()
                        continuation.yield(.sectionStart(id: section.id))
                        let prompt = brief.promptText(for: section, includesFacts: index == 0)
                        for try await chunk in session.streamResponse(to: prompt) {
                            try Task.checkCancellation()
                            continuation.yield(.text(sectionID: section.id, delta: chunk))
                        }
                        continuation.yield(.sectionEnd(id: section.id))
                    }
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
