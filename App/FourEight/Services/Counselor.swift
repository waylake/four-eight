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
/// 매 턴 세션을 새로 만든다. 4B 모델은 턴이 쌓이면 시스템 지시를 잊고,
/// 잊는 순간 근거 밖으로 나간다. 그래서 대화 이력을 모델의 기억에 맡기지
/// 않고 **매 턴 근거와 최근 발언을 다시 넣는다.** 화면에도 그렇게 적는다 —
/// 기억하는 척하지 않는 것이 정직하다.
struct Counselor: Sendable {
    let container: ModelContainer
    /// 명식 사실. 이미 확정된 값이다.
    let facts: [String]
    /// 오늘의 기운. 사용자가 켰을 때만 들어간다.
    let todayFacts: [String]?
    let topic: ConsultationTopic
    let evidence: [Rule]

    /// 다시 넣는 최근 발언 수.
    ///
    /// 늘리면 맥락이 좋아지지만 근거가 밀려나고 지시 준수가 무너진다.
    /// 이 값은 정직하게 작다. 화면에 그대로 표시한다.
    static let recentTurnWindow = 4

    static let instructions = """
    당신은 한국 명리학 상담가입니다. 상담자가 적은 고민을, 아래 [근거]에 있는 명리 내용으로만 풀어 줍니다.

    지켜야 할 것:
    - [명식 사실]과 [근거]에 있는 내용만 사용합니다. 새로운 간지, 십신, 신살, 관계를 만들어내지 않습니다.
    - 근거에 없는 것을 물으면 아는 척하지 않고, 지금 근거로는 말씀드리기 어렵다고 밝힙니다. 이것이 지어내는 것보다 낫습니다.
    - **결정을 대신하지 않습니다.** "이직하세요", "하지 마세요"처럼 행동을 지시하지 않습니다. 그 결정을 앞두고 명식이 어떤 국면을 보여 주는지, 무엇을 살펴보면 좋을지만 말합니다.
    - 날과 시기에 등급을 매기지 않습니다. "좋은 시기", "나쁜 시기", "조심해야 할 해" 같은 표현을 쓰지 않고, 어떤 성격의 기운이 실리는 국면인지만 서술합니다.
    - 미래를 단정하지 않습니다. "~하게 됩니다"가 아니라 "~한 편입니다", "~경향이 있습니다", "~국면입니다"로 씁니다.
    - 상담자를 칭찬하거나 비위를 맞추지 않습니다. "훌륭한 질문입니다", "좋은 마음가짐이십니다" 같은 말로 시작하지 않습니다.
    - 의료·투자·법률 판단을 하지 않습니다. 진단, 치료, 종목, 계약에 대해 말하지 않습니다.
    - 공포를 조장하지 않습니다. 불안을 키워 다시 묻게 만드는 문장을 쓰지 않습니다.

    쓰는 방식:
    - 첫 문장에서 상담자가 말한 사정을 한 문장으로 되짚습니다. 그다음 근거로 넘어갑니다.
    - 2~3문단, 각 문단 2~4문장. 제목이나 목록 없이 본문만 씁니다.
    - 존댓말을 씁니다. 이모지를 쓰지 않습니다.
    - 마지막에 상담자가 스스로 살펴볼 수 있는 관점 하나를 남깁니다. 지시가 아니라 관점입니다.
    """

    /// 이 턴의 프롬프트. 근거와 최근 발언을 매번 다시 넣는다.
    func prompt(for consultation: Consultation, followUp: String?) -> String {
        var blocks: [String] = []
        blocks.append("[명식 사실]\n" + facts.joined(separator: "\n"))
        if let todayFacts, !todayFacts.isEmpty {
            blocks.append("[오늘의 기운]\n" + todayFacts.joined(separator: "\n"))
        }
        blocks.append("[상담 주제] \(topic.title) — \(topic.axis)로 읽습니다.")
        blocks.append(
            "[근거]\n" + evidence.map { "- (\($0.title)) \($0.text)" }.joined(separator: "\n")
        )
        blocks.append("[상담자가 처음 적은 고민]\n\(consultation.concern)")

        // 최근 발언만. 모델의 기억이 아니라 프롬프트가 맥락을 나른다.
        let recent = consultation.turns
            .filter { $0.speaker != .app }
            .suffix(Self.recentTurnWindow)
        if !recent.isEmpty {
            let lines = recent.map { turn in
                (turn.speaker == .person ? "상담자: " : "상담가: ") + turn.text
            }
            blocks.append("[최근 주고받은 말]\n" + lines.joined(separator: "\n\n"))
        }
        if let followUp, !followUp.isEmpty {
            blocks.append("[상담자가 지금 덧붙인 말]\n\(followUp)")
        }
        blocks.append("위 근거만 써서 이 고민에 대한 풀이를 써 주세요.")
        return blocks.joined(separator: "\n\n")
    }

    func stream(for consultation: Consultation, followUp: String?) -> AsyncThrowingStream<String, Error> {
        let text = prompt(for: consultation, followUp: followUp)
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
                        instructions: Self.instructions,
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
