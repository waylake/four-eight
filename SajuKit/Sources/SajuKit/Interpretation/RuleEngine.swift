import Foundation

/// 해석 룰 — 번들 JSON에서 로드.
public struct Rule: Sendable, Codable, Hashable, Identifiable {
    public let id: String
    public let category: String
    public let title: String
    public let hanja: String?
    public let tags: [String]
    public let text: String
}

public struct RuleSet: Sendable {
    public let rules: [Rule]
    private let byTag: [String: [Rule]]

    public init(rules: [Rule]) {
        self.rules = rules
        var index: [String: [Rule]] = [:]
        for rule in rules {
            for tag in rule.tags {
                index[tag, default: []].append(rule)
            }
        }
        self.byTag = index
    }

    /// 번들 리소스(rules.json) 로드.
    public static func bundled() throws -> RuleSet {
        guard let url = Bundle.module.url(forResource: "rules", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        struct File: Codable { let version: Int; let rules: [Rule] }
        return RuleSet(rules: try JSONDecoder().decode(File.self, from: data).rules)
    }

    public func matching(tag: String) -> [Rule] {
        byTag[tag] ?? []
    }

    public func matching(tags: [String]) -> [Rule] {
        var seen = Set<String>()
        var result: [Rule] = []
        for tag in tags {
            for rule in matching(tag: tag) where seen.insert(rule.id).inserted {
                result.append(rule)
            }
        }
        return result
    }
}

/// 해석 섹션 — 근거 룰이 부착된 구조화 출력.
public struct InterpretationSection: Sendable, Codable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let rules: [Rule]
}

/// 섹션 컴포저 — 태그를 섹션별 룰 묶음으로.
public enum Composer {
    public static func sections(facts: FactSet, ruleSet: RuleSet) -> [InterpretationSection] {
        func tags(withPrefix prefixes: [String]) -> [String] {
            facts.tags.filter { tag in prefixes.contains { tag.hasPrefix($0 + ":") } }
        }
        let plan: [(id: String, title: String, prefixes: [String])] = [
            ("overview", "총평", ["ilgan", "strength"]),
            ("personality", "성격과 기질", ["sibsin"]),
            ("balance", "오행과 균형", ["oheng_excess", "oheng_lack", "wolji"]),
            ("flow", "흐름과 시기", ["daeun_sibsin", "sinsal"]),
        ]
        return plan.compactMap { section in
            let rules = ruleSet.matching(tags: tags(withPrefix: section.prefixes))
            guard !rules.isEmpty else { return nil }
            return InterpretationSection(id: section.id, title: section.title, rules: rules)
        }
    }
}
