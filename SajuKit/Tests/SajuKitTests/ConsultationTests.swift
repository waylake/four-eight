import Testing
import Foundation
@testable import SajuKit

/// 고민 라우팅 — 대화 기능의 결정론적 부분.
///
/// 이 층이 틀리면 모델은 엉뚱한 근거로 답한다. 그리고 그 실패는 조용하다.
/// 답변이 그럴듯하게 나오므로 아무도 알아채지 못한다. 그래서 라우팅을
/// 테스트로 고정한다.
@Suite("상담 라우팅")
struct ConsultationTests {
    private let ruleSet = try! RuleSet.bundled()

    /// 스크린샷·골든 케이스와 같은 인물. 이미지에 보이는 명식을 테스트가 검증한다.
    private func demoFacts() throws -> FactSet {
        let input = BirthInput(
            year: 2003, month: 2, day: 22, hour: 13, minute: 13,
            gender: .male, place: .seoul
        )
        let chart = try PillarsEngine.chart(for: input)
        let analysis = Analyzer.analyze(chart)
        let daeun = DaeUnEngine.daeun(for: chart)
        return FactExtractor.facts(chart: chart, analysis: analysis, daeun: daeun)
    }

    @Test("고민 문장을 명리 축으로 옮긴다")
    func classifies() {
        #expect(ConsultationRouter.classify("회사를 옮길까 고민이에요").first?.topic == .career)
        #expect(ConsultationRouter.classify("돈 관리가 계속 안 됩니다").first?.topic == .wealth)
        #expect(ConsultationRouter.classify("연애가 잘 안 돼요").first?.topic == .relationship)
        #expect(ConsultationRouter.classify("요즘 너무 지치고 무기력해요").first?.topic == .wellbeing)
        #expect(ConsultationRouter.classify("해외로 이민을 갈까요").first?.topic == .movement)
    }

    /// 못 알아듣는 것이 정상적인 결과다. 아무 주제나 골라 답하는 것보다
    /// 사용자에게 주제를 고르게 하는 편이 낫다.
    @Test("주제를 못 찾으면 빈 결과를 준다")
    func classifiesNothing() {
        #expect(ConsultationRouter.classify("안녕하세요").isEmpty)
        #expect(ConsultationRouter.classify("").isEmpty)
        #expect(ConsultationRouter.classify("ㅁㄴㅇㄹ").isEmpty)
    }

    /// 같은 입력에 같은 순서. 점수가 같을 때 순서가 흔들리면 같은 고민에
    /// 다른 근거가 붙는다.
    @Test("분류는 결정론적이다")
    func classificationIsDeterministic() {
        let text = "회사 일도 돈도 사람도 다 힘들어요"
        let first = ConsultationRouter.classify(text, limit: 5)
        for _ in 0..<20 {
            #expect(ConsultationRouter.classify(text, limit: 5) == first)
        }
    }

    /// 여러 축에 걸친 고민은 여러 축으로 읽는다. 하나로 눌러 담으면
    /// 나머지 축의 근거가 사라진다.
    @Test("복합 고민은 여러 주제로 읽는다")
    func classifiesMultiple() {
        let matches = ConsultationRouter.classify("이직하면 월급이 줄어드는데 언제가 좋을까요", limit: 3)
        let topics = Set(matches.map(\.topic))
        #expect(topics.contains(.career))
        #expect(topics.contains(.wealth))
        #expect(topics.count >= 2)
    }

    @Test("근거는 이 명식에서 성립한 것만 쓴다")
    func evidenceComesFromThisChart() throws {
        let facts = try demoFacts()
        for topic in ConsultationTopic.allCases {
            let rules = ConsultationRouter.evidence(for: topic, facts: facts, ruleSet: ruleSet)
            for rule in rules {
                // 규칙의 태그 중 최소 하나가 이 사람의 사실에 있어야 한다.
                #expect(
                    rule.tags.contains(where: { facts.tags.contains($0) }),
                    "\(topic.rawValue) 근거 \(rule.id)가 이 명식의 사실과 무관하다"
                )
            }
        }
    }

    @Test("주제의 태그 필터 밖 근거는 섞이지 않는다")
    func evidenceStaysInsideTopic() throws {
        let facts = try demoFacts()
        for topic in ConsultationTopic.allCases {
            let rules = ConsultationRouter.evidence(for: topic, facts: facts, ruleSet: ruleSet)
            for rule in rules {
                let inside = rule.tags.contains { tag in
                    let parts = tag.split(separator: ":", maxSplits: 1)
                    guard parts.count == 2 else { return false }
                    return topic.tagFilters.contains { filter in
                        filter.prefix == String(parts[0])
                            && (filter.values?.contains(String(parts[1])) ?? true)
                    }
                }
                #expect(inside, "\(topic.rawValue)에 축 밖 근거 \(rule.id)가 들어왔다")
            }
        }
    }

    /// 나와 성향은 일간이 항상 있으므로 어느 명식에서도 이야기할 수 있다.
    @Test("권하는 주제는 근거가 있는 것뿐")
    func availableTopicsHaveEvidence() throws {
        let facts = try demoFacts()
        let topics = ConsultationRouter.availableTopics(facts: facts, ruleSet: ruleSet)
        #expect(topics.contains(.identity))
        for topic in topics {
            #expect(!ConsultationRouter.evidence(for: topic, facts: facts, ruleSet: ruleSet).isEmpty)
        }
        for topic in Set(ConsultationTopic.allCases).subtracting(topics) {
            #expect(ConsultationRouter.evidence(for: topic, facts: facts, ruleSet: ruleSet).isEmpty)
        }
    }

    /// 되묻는 말도 콘텐츠다. 톤 규약은 해석 문장과 같이 적용된다.
    @Test("되묻는 말에 판정 표현과 단정이 없다")
    func clarifiersFollowToneRules() {
        let banned = ["흉일", "길일", "액운", "재앙", "나쁜 날", "좋은 날", "불운한", "운이 나쁜",
                      "반드시", "틀림없이", "확실히", "해야 합니다"]
        for topic in ConsultationTopic.allCases {
            for phrase in banned {
                #expect(
                    !topic.clarifier.contains(phrase),
                    "\(topic.rawValue) 되묻기에 '\(phrase)' 포함"
                )
            }
            #expect(topic.clarifier.hasSuffix("."), "\(topic.rawValue) 되묻기가 문장으로 끝나지 않는다")
            #expect(topic.clarifier.count >= 20)
        }
    }

    /// 모든 주제에 고유한 내용이 있어야 한다. 복사해 붙인 문구가 있으면
    /// 사용자는 같은 말을 두 번 듣는다.
    @Test("주제마다 고유한 축과 되묻기를 갖는다")
    func topicsAreDistinct() {
        let axes = Set(ConsultationTopic.allCases.map(\.axis))
        let clarifiers = Set(ConsultationTopic.allCases.map(\.clarifier))
        let titles = Set(ConsultationTopic.allCases.map(\.title))
        #expect(axes.count == ConsultationTopic.allCases.count)
        #expect(clarifiers.count == ConsultationTopic.allCases.count)
        #expect(titles.count == ConsultationTopic.allCases.count)
    }

    /// 이어 물을 거리도 콘텐츠다. 되묻기와 같은 규약을 받는다.
    ///
    /// 특히 **질문이어야 한다.** 권유문("이것도 살펴보세요")이 되면 앱이
    /// 사용자를 끌고 가는 말이 되고, 그것은 §6-3이 막는 종류의 장치다.
    /// 물음표로 끝나는지 검사하는 것이 그 경계를 기계적으로 지킨다.
    @Test("이어 물을 거리가 톤 규약을 지킨다")
    func followUpsFollowToneRules() {
        let banned = ["흉일", "길일", "액운", "재앙", "나쁜 날", "좋은 날", "불운한", "운이 나쁜",
                      "반드시", "틀림없이", "확실히", "해야 합니다"]
        for topic in ConsultationTopic.allCases {
            #expect(topic.followUps.count >= 2, "\(topic.rawValue)에 이어 물을 거리가 부족하다")
            for question in topic.followUps {
                for phrase in banned {
                    #expect(!question.contains(phrase), "\(topic.rawValue) 후속 질문에 '\(phrase)' 포함")
                }
                #expect(question.hasSuffix("?"), "\(topic.rawValue) 후속 질문이 물음이 아니다 — \(question)")
                #expect(question.count >= 15)
                // 상담자가 스스로 적는 말이므로 상담자의 입장에서 쓴다.
                #expect(!question.contains("당신"), "\(topic.rawValue) 후속 질문이 상담자를 2인칭으로 부른다")
            }
        }
    }

    /// 같은 질문이 두 축에 있으면 축을 바꿔도 같은 것을 묻게 된다.
    @Test("이어 물을 거리는 전부 다르다")
    func followUpsAreDistinct() {
        let all = ConsultationTopic.allCases.flatMap(\.followUps)
        #expect(Set(all).count == all.count)
    }
}
