import Foundation
import SajuKit

/// 상담 한 턴에 들어갈 재료와 그것으로 만든 프롬프트.
///
/// `Counselor`에서 떼어낸 것이다. 이유는 하나다. **프롬프트는 전송 수단이
/// 아니라 제품이다.** 톤 규약, 근거 밖으로 나가지 말라는 지시, 결정을
/// 대신하지 말라는 지시, 등급을 매기지 말라는 지시 — 이것들이 이 앱의
/// 해석 품질 자체이고, 온디바이스로 보내는지 원격으로 보내는지에 따라
/// 달라질 이유가 전혀 없다.
///
/// 각 전송 층이 자기 프롬프트를 갖게 두면 둘은 반드시 어긋난다. 한쪽에
/// 규칙을 추가하고 다른 쪽을 잊는 것이 아니라, **어긋났다는 사실 자체를
/// 아무도 모르는 것**이 문제다. 두 경로의 출력은 둘 다 그럴듯하다.
///
/// 그래서 재료와 문장을 여기 한 곳에 두고, 전송 층은 이것을 받아 나르기만
/// 한다. `ConsultationPromptTests`가 두 경로가 같은 글자를 보내는지 검사한다.
struct CounselBrief: Sendable, Equatable {
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
    ///
    /// 원격 모델이 더 크다는 이유로 이 값을 늘리지 않는다. 늘리면 같은
    /// 상담이 어느 경로로 갔는지에 따라 다른 맥락을 보게 되고, 사용자는
    /// 왜 답이 달라졌는지 알 수 없다.
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
    ///
    /// 모델의 기억에 이력을 맡기지 않는 이유는 4B 모델이 턴이 쌓이면
    /// 시스템 지시를 잊기 때문이었다. 원격의 큰 모델은 덜 잊겠지만,
    /// 그래도 같은 방식으로 보낸다 — 경로에 따라 맥락이 달라지면 같은
    /// 상담이 다른 물건이 된다.
    func promptText(for consultation: Consultation, followUp: String?) -> String {
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
}

/// 해석(명식·시간운)의 재료.
///
/// 상담과 같은 이유로 전송 층에서 떼어냈다. 섹션 하나의 프롬프트를 만드는
/// 규칙이 두 곳에 있으면 어긋난다.
struct InterpretationBrief: Sendable {
    /// 첫 섹션 앞에 붙는 명식 사실. 이미 확정된 값이다.
    let facts: [String]
    let instructions: String

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

    /// 섹션 하나의 프롬프트.
    ///
    /// `includesFacts`는 첫 섹션에만 참이다. 매 섹션에 사실을 다시 넣으면
    /// 토큰만 쓰고, 원격에서는 그것이 그대로 요금이 된다.
    func promptText(for section: InterpretationSection, includesFacts: Bool) -> String {
        let evidence = section.rules
            .map { "- (\($0.title)) \($0.text)" }
            .joined(separator: "\n")
        var prompt = ""
        if includesFacts {
            prompt += "[사실]\n\(facts.joined(separator: "\n"))\n\n"
        }
        prompt += "[섹션] \(section.title)\n[근거]\n\(evidence)\n\n위 근거를 통합해 이 섹션의 해설을 써 주세요."
        return prompt
    }
}
