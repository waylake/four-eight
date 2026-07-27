import Foundation
import MLXLMCommon
import SajuKit

/// 해석 스트림 이벤트.
enum InterpretationChunk: Sendable {
    case sectionStart(id: String, title: String, evidence: [Rule])
    case text(sectionID: String, delta: String)
    case sectionEnd(id: String)
    case done
}

/// 해석기 — 룰 텍스트를 읽기 좋은 해설로.
protocol Interpreter: Sendable {
    func stream(reading: Reading) -> AsyncThrowingStream<InterpretationChunk, Error>
}

// MARK: - 템플릿 해석기 (모델 없이 항상 동작)

/// 결정론적 폴백 — 근거 룰 텍스트를 섹션별로 그대로 조립한다.
struct TemplateInterpreter: Interpreter {
    func stream(reading: Reading) -> AsyncThrowingStream<InterpretationChunk, Error> {
        AsyncThrowingStream { continuation in
            for section in reading.sections {
                continuation.yield(.sectionStart(
                    id: section.id, title: section.title, evidence: section.rules
                ))
                let text = section.rules.map(\.text).joined(separator: "\n\n")
                continuation.yield(.text(sectionID: section.id, delta: text))
                continuation.yield(.sectionEnd(id: section.id))
            }
            continuation.yield(.done)
            continuation.finish()
        }
    }
}

// MARK: - Gemma 해석기 (MLX 온디바이스)

/// Gemma 4 스트리밍 해석 — 명식 사실과 룰 근거만으로 서술을 재구성한다.
/// 계산·판단은 이미 엔진이 끝냈으므로 모델의 역할은 문장화뿐이다.
struct GemmaInterpreter: Interpreter {
    let container: ModelContainer

    static let instructions = """
    당신은 한국 명리학 상담가입니다. 규칙:
    - 제공된 [명식 사실]과 [근거]의 내용만 사용합니다. 새로운 명리적 주장, 간지, 십신을 만들어내지 않습니다.
    - 근거 문장들을 매끄럽게 통합해 하나의 흐르는 해설로 다시 씁니다. 근거를 나열식으로 반복하지 않습니다.
    - 존댓말을 사용하고, 단정 대신 "~한 편입니다", "~경향이 있습니다"로 표현합니다.
    - 운명 단정, 공포 조장, 의료·투자·법률 조언을 하지 않습니다.
    - 2~3문단, 각 문단 2~4문장. 제목이나 목록 없이 본문만 씁니다.
    """

    func stream(reading: Reading) -> AsyncThrowingStream<InterpretationChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var params = GenerateParameters()
                    params.temperature = 0.6
                    params.maxTokens = 700
                    let session = ChatSession(
                        container,
                        instructions: Self.instructions,
                        generateParameters: params
                    )
                    let factsBlock = reading.facts.summaryLines.joined(separator: "\n")

                    for (index, section) in reading.sections.enumerated() {
                        try Task.checkCancellation()
                        continuation.yield(.sectionStart(
                            id: section.id, title: section.title, evidence: section.rules
                        ))
                        let evidence = section.rules
                            .map { "- (\($0.title)) \($0.text)" }
                            .joined(separator: "\n")
                        var prompt = ""
                        if index == 0 {
                            prompt += "[명식 사실]\n\(factsBlock)\n\n"
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
