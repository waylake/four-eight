import Foundation

/// 시간운(일진·월운·세운) 사실 추출.
///
/// 명식 팩트와 같은 규약을 쓴다. 태그를 뽑고 룰 인덱스가 정확 매칭한다.
/// 벡터 검색을 쓰지 않는 이유는 ADR 0004에 있다.
public enum TimeFactExtractor {
    /// 하루치 사실. 캘린더 상세와 오늘 화면이 공유한다.
    public static func facts(
        day: DayReading,
        month: PeriodReading,
        year: PeriodReading,
        chart: SajuChart
    ) -> FactSet {
        var tags: [String] = []
        var lines: [String] = []

        tags.append("iljin_sibsin:\(day.stemGod.korean)")
        tags.append("iljin_unseong:\(day.stage.korean)")
        tags.append("wolwoon_sibsin:\(month.stemGod.korean)")
        tags.append("sewoon_sibsin:\(year.stemGod.korean)")

        for relation in day.relations {
            let tag = "iljin_rel:\(relation.kind.rawValue)"
            if !tags.contains(tag) { tags.append(tag) }
        }
        if day.isVoid { tags.append("iljin_rel:공망") }
        if day.combinesDayMaster { tags.append("iljin_rel:일간합") }

        // 프롬프트 주입용 사실 라인 — 해석 없이 값만.
        lines.append("일간: \(chart.dayMaster.korean)\(chart.dayMaster.hanja)")
        lines.append("일진: \(day.ganji.korean)(\(day.ganji.hanja)) · 천간 \(day.stemGod.korean) · 지지 \(day.branchGod.korean) · \(day.stage.korean)")
        lines.append("월운: \(month.ganji.korean)(\(month.ganji.hanja)) \(month.stemGod.korean)")
        lines.append("세운: \(year.ganji.korean)(\(year.ganji.hanja)) \(year.stemGod.korean)")
        if !day.relations.isEmpty {
            lines.append("명식과의 관계: " + day.relations.map { "\($0.display)(\($0.position.rawValue))" }.joined(separator: ", "))
        }
        if day.isVoid { lines.append("공망일") }
        if day.combinesDayMaster { lines.append("일간과 천간합") }

        return FactSet(tags: tags, summaryLines: lines)
    }
}

public extension Composer {
    /// 시간운 섹션 구성. 명식 해석보다 짧게 두 섹션으로 나눈다.
    static func timeSections(facts: FactSet, ruleSet: RuleSet) -> [InterpretationSection] {
        let plan: [(id: String, title: String, prefixes: [String])] = [
            ("today", "오늘의 기운", ["iljin_sibsin", "iljin_unseong", "iljin_rel"]),
            ("period", "이달과 올해", ["wolwoon_sibsin", "sewoon_sibsin"]),
        ]
        return plan.compactMap { section in
            let matched = facts.tags.filter { tag in
                section.prefixes.contains { tag.hasPrefix($0 + ":") }
            }
            let rules = ruleSet.matching(tags: matched)
            guard !rules.isEmpty else { return nil }
            return InterpretationSection(id: section.id, title: section.title, rules: rules)
        }
    }
}
