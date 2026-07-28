import Foundation

/// 고민을 명리 축으로 라우팅하고, 그 축의 근거만 골라 준다.
///
/// 대화 기능의 설계 원칙은 해석과 같다. **모델은 계산하지도 판단하지도
/// 않는다.** 무엇에 대한 고민인지 정하는 일(라우팅), 어떤 근거를 쓸지
/// 정하는 일(선별), 답할 수 있는지 정하는 일(가용성 판정)은 전부 여기서
/// 결정론적으로 끝난다. 모델은 고른 근거를 사용자의 사정에 맞춰 문장으로
/// 옮기는 일만 한다.
///
/// 그래서 답변마다 근거 칩을 붙일 수 있다. 어떤 문장이 어떤 규칙에서
/// 나왔는지 항상 아는 것 — 이 앱의 정체성이 대화에서도 유지된다.
public enum ConsultationRouter {
    public struct Match: Sendable, Hashable {
        public let topic: ConsultationTopic
        /// 실제로 걸린 말. 화면에 보여준다. 앱이 왜 이 주제로 읽었는지
        /// 사용자가 확인하고 고칠 수 있어야 한다.
        public let matchedTerms: [String]
    }

    /// 고민 문장을 주제로 옮긴다. 많이 걸린 순서로 돌려준다.
    ///
    /// 빈 배열을 돌려주는 것이 정상적인 결과다. 그때는 사용자가 주제를
    /// 직접 고른다. 아무 주제나 골라 답하는 것보다 낫다.
    public static func classify(_ text: String, limit: Int = 3) -> [Match] {
        let normalized = text.lowercased()
        var matches: [Match] = []
        for topic in ConsultationTopic.allCases {
            let hits = topic.terms.filter { normalized.contains($0) }
            guard !hits.isEmpty else { continue }
            matches.append(Match(topic: topic, matchedTerms: hits))
        }
        // 걸린 말이 많은 주제가 먼저. 같으면 열거 순서를 지켜 결과를
        // 결정론적으로 만든다 — 같은 입력에 같은 순서가 나와야 한다.
        return matches
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.matchedTerms.count != rhs.element.matchedTerms.count {
                    return lhs.element.matchedTerms.count > rhs.element.matchedTerms.count
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
            .prefix(limit)
            .map { $0 }
    }

    /// 이 주제로 답할 근거. **이 사람의 명식에서 실제로 성립한 것만** 쓴다.
    ///
    /// 주제에 해당하는 규칙을 전부 넣으면 안 된다. 재성이 없는 명식에
    /// 재성 설명을 붙이면 그것은 이 사람의 이야기가 아니다.
    public static func evidence(
        for topic: ConsultationTopic,
        facts: FactSet,
        timeFacts: FactSet? = nil,
        ruleSet: RuleSet
    ) -> [Rule] {
        let tags = facts.tags + (timeFacts?.tags ?? [])
        let selected = tags.filter { tag in
            let parts = tag.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return false }
            let prefix = String(parts[0])
            let value = String(parts[1])
            return topic.tagFilters.contains { filter in
                filter.prefix == prefix && (filter.values?.contains(value) ?? true)
            }
        }
        return ruleSet.matching(tags: selected)
    }

    /// 이 명식에서 실제로 이야기할 수 있는 주제만.
    ///
    /// 답할 수 없는 주제를 권하지 않는 것이 정직하다. 재성이 발달하지
    /// 않은 명식에 "돈과 재물"을 권하면, 사용자는 근거 없는 답을 받거나
    /// "말씀드리기 어렵다"는 답을 받는다. 권하지 않는 편이 낫다.
    public static func availableTopics(
        facts: FactSet,
        timeFacts: FactSet? = nil,
        ruleSet: RuleSet
    ) -> [ConsultationTopic] {
        ConsultationTopic.allCases.filter { topic in
            !evidence(for: topic, facts: facts, timeFacts: timeFacts, ruleSet: ruleSet).isEmpty
        }
    }
}
