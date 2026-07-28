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
/// 섹션 부분집합을 받는 것이 중요하다. 재개는 "미완료 섹션만 다시"이므로
/// 해석기가 전체 문서를 전제하면 안 된다.
protocol Interpreter: Sendable {
    func stream(sections: [InterpretationSection]) -> AsyncThrowingStream<InterpretationChunk, Error>
}

// MARK: - Gemma 해석기

/// Gemma 4 스트리밍. 계산과 판단은 이미 끝났으므로 문장화만 맡는다.
struct GemmaInterpreter: Interpreter {
    let container: ModelContainer
    /// 첫 섹션 앞에 붙는 명식 사실. 이미 확정된 값이다.
    let facts: [String]
    var instructions: String = GemmaInterpreter.natalInstructions

    static let natalInstructions = """
    당신은 한국 명리학 상담가입니다. 규칙:
    - 제공된 [명식 사실]과 [근거]의 내용만 사용합니다. 새로운 명리적 주장, 간지, 십신을 만들어내지 않습니다.
    - 근거 문장들을 매끄럽게 통합해 하나의 흐르는 해설로 다시 씁니다. 근거를 나열식으로 반복하지 않습니다.
    - 존댓말을 사용하고, 단정 대신 "~한 편입니다", "~경향이 있습니다"로 표현합니다.
    - 운명 단정, 공포 조장, 의료·투자·법률 조언을 하지 않습니다.
    - 2~3문단, 각 문단 2~4문장. 제목이나 목록 없이 본문만 씁니다.
    """

    static let timeInstructions = """
    당신은 한국 명리학 상담가입니다. 오늘과 이 시기의 기운을 설명합니다. 규칙:
    - 제공된 [사실]과 [근거]의 내용만 사용합니다. 새로운 간지나 관계를 만들어내지 않습니다.
    - 날과 시기에 등급을 매기지 않습니다. "좋은 날", "나쁜 날", "조심해야 할 날" 같은 표현을 쓰지 않고,
      어떤 성격의 기운이 실리는 국면인지만 서술합니다.
    - 존댓말을 쓰고 단정 대신 "~한 흐름입니다", "~에 힘이 실리는 편입니다"로 표현합니다.
    - 공포 조장, 운명 단정, 의료·투자·법률 조언을 하지 않습니다.
    - 1~2문단, 각 문단 2~3문장. 제목이나 목록 없이 본문만 씁니다.
    """

    func stream(sections: [InterpretationSection]) -> AsyncThrowingStream<InterpretationChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var params = GenerateParameters()
                    params.temperature = 0.6
                    params.maxTokens = 700
                    let session = ChatSession(
                        container,
                        instructions: instructions,
                        generateParameters: params
                    )
                    let factsBlock = facts.joined(separator: "\n")

                    for (index, section) in sections.enumerated() {
                        try Task.checkCancellation()
                        continuation.yield(.sectionStart(id: section.id))
                        let evidence = section.rules
                            .map { "- (\($0.title)) \($0.text)" }
                            .joined(separator: "\n")
                        var prompt = ""
                        if index == 0 {
                            prompt += "[사실]\n\(factsBlock)\n\n"
                        }
                        prompt += "[섹션] \(section.title)\n[근거]\n\(evidence)\n\n위 근거를 통합해 이 섹션의 해설을 써 주세요."

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
