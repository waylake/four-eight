import Foundation
import Observation
import MLXLMCommon
import SajuKit

/// 명식을 두고 나누는 대화.
///
/// 2B 모델에게 자유 질의응답을 시키면 없는 간지를 지어낸다. 그래서
/// 대화도 해석과 같은 규약을 따른다. 확정된 사실과 매칭된 근거만 주고,
/// **근거에 없는 것은 모른다고 답하도록** 지시한다.
///
/// 모른다고 말하는 것이 이 기능의 품질 기준이다. 그럴듯하게 지어내는
/// 답변보다 "그 부분은 지금 명식 정보만으로는 말씀드리기 어렵습니다"가
/// 낫다.
@MainActor
@Observable
final class Conversation {
    struct Message: Identifiable, Hashable {
        enum Role { case user, assistant }
        let id = UUID()
        let role: Role
        var text: String
        var isComplete: Bool = true
    }

    private(set) var messages: [Message] = []
    private(set) var isResponding = false
    private(set) var errorMessage: String?
    private var task: Task<Void, Never>?
    private var session: ChatSession?
    /// 이 대화가 어떤 명식·엔진에 매인 것인지.
    private(set) var boundKey: String?

    static let instructions = """
    당신은 한국 명리학 상담가입니다. 사용자의 명식에 대해 대화합니다. 규칙:
    - [명식 사실]과 [참고 근거]에 있는 내용만 사용합니다. 새로운 간지, 십신, 신살을 만들어내지 않습니다.
    - 근거에 없는 것을 물으면 아는 척하지 말고, 지금 정보로는 말씀드리기 어렵다고 솔직하게 답합니다.
      이것이 지어내는 것보다 낫습니다.
    - 답은 2~4문장으로 짧게 합니다. 존댓말을 쓰고 단정 대신 "~한 편입니다"로 표현합니다.
    - 운명 단정, 공포 조장, 길흉 판정, 의료·투자·법률 조언을 하지 않습니다.
    - 구체적인 날짜의 길흉을 물으면, 날에 등급을 매기지 않는다고 설명하고 그날 기운의 성격만 말합니다.
    """

    /// 세션을 다시 만들 수 있도록 재료를 들고 있는다.
    /// `ChatSession.clear()`는 non-Sendable 값을 격리 경계 밖으로 보내야 해서
    /// 쓸 수 없다. 어차피 새 세션은 이력이 비어 있으므로 결과가 같다.
    private struct Recipe {
        let container: ModelContainer
        let instructions: String
    }
    private var recipe: Recipe?

    /// 명식이나 엔진이 바뀌면 대화를 새로 연다.
    func bind(reading: Reading, container: ModelContainer?, engineID: String) {
        let key = "\(reading.person.id)|\(reading.chart.signature)|\(engineID)"
        guard boundKey != key else { return }
        reset()
        boundKey = key

        guard let container else { return }
        let facts = reading.facts.summaryLines.joined(separator: "\n")
        let evidence = reading.sections
            .flatMap(\.rules)
            .map { "- (\($0.title)) \($0.text)" }
            .joined(separator: "\n")

        recipe = Recipe(
            container: container,
            instructions: """
            \(Self.instructions)

            [명식 사실]
            \(facts)

            [참고 근거]
            \(evidence)
            """
        )
        session = makeSession()
    }

    private func makeSession() -> ChatSession? {
        guard let recipe else { return nil }
        var params = GenerateParameters()
        params.temperature = 0.6
        params.maxTokens = 400
        return ChatSession(
            recipe.container,
            instructions: recipe.instructions,
            generateParameters: params
        )
    }

    func reset() {
        task?.cancel()
        task = nil
        session = nil
        recipe = nil
        messages = []
        isResponding = false
        errorMessage = nil
        boundKey = nil
    }

    /// 대화 내용만 지운다. 명식과 근거는 그대로 유지한다.
    func clearHistory() {
        task?.cancel()
        task = nil
        messages = []
        isResponding = false
        errorMessage = nil
        session = makeSession()
    }

    func stop() {
        task?.cancel()
        task = nil
        isResponding = false
        if let last = messages.indices.last, messages[last].role == .assistant {
            messages[last].isComplete = true
            if messages[last].text.isEmpty {
                messages.removeLast()
            }
        }
    }

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isResponding else { return }
        guard let session else {
            errorMessage = "모델이 준비되지 않았습니다. 설정에서 Gemma 4를 설치하세요."
            return
        }

        errorMessage = nil
        messages.append(Message(role: .user, text: trimmed))
        messages.append(Message(role: .assistant, text: "", isComplete: false))
        isResponding = true
        let index = messages.count - 1

        task = Task { [weak self] in
            do {
                for try await chunk in session.streamResponse(to: trimmed) {
                    guard let self, !Task.isCancelled else { return }
                    guard self.messages.indices.contains(index) else { return }
                    self.messages[index].text += chunk
                }
                guard let self, !Task.isCancelled else { return }
                if self.messages.indices.contains(index) {
                    self.messages[index].isComplete = true
                }
            } catch is CancellationError {
                // stop()이 이미 정리했다.
            } catch {
                self?.errorMessage = error.localizedDescription
                if let self, self.messages.indices.contains(index) {
                    self.messages[index].isComplete = true
                    if self.messages[index].text.isEmpty { self.messages.remove(at: index) }
                }
            }
            self?.isResponding = false
            self?.task = nil
        }
    }

    /// 근거가 실제로 있는 주제로만 만든 추천 질문.
    /// 답할 수 없는 질문을 권하지 않는 것이 정직하다.
    static func suggestions(for reading: Reading) -> [String] {
        var items: [String] = []
        let tags = Set(reading.facts.tags)

        items.append("제 일간을 한 문장으로 설명해 주세요.")
        if tags.contains(where: { $0.hasPrefix("strength:") }) {
            items.append("제 사주가 신강한지 신약한지, 그게 무슨 뜻인가요?")
        }
        if tags.contains(where: { $0.hasPrefix("oheng_lack:") }) {
            items.append("부족한 오행은 어떻게 이해하면 좋을까요?")
        }
        if tags.contains(where: { $0.hasPrefix("sibsin:") }) {
            items.append("발달한 십신이 성격에 어떻게 나타나나요?")
        }
        if tags.contains(where: { $0.hasPrefix("daeun_sibsin:") }) {
            items.append("지금 대운은 어떤 흐름인가요?")
        }
        return items
    }
}
