import Foundation
import SajuKit

/// 한 사람의 완성된 판독 — 명식·분석·대운·사실·해석 섹션.
struct Reading: Sendable {
    let person: Person
    let chart: SajuChart
    let analysis: SajuAnalysis
    let daeun: DaeUn?
    let facts: FactSet
    let sections: [InterpretationSection]
}

enum SajuService {
    static let ruleSet: RuleSet = {
        (try? RuleSet.bundled()) ?? RuleSet(rules: [])
    }()

    static func reading(for person: Person, options: SajuOptions) throws -> Reading {
        var input = person.birth
        input.options = options
        let chart = try PillarsEngine.chart(for: input)
        let analysis = Analyzer.analyze(chart)
        let daeun = DaeUnEngine.daeun(for: chart)
        let facts = FactExtractor.facts(chart: chart, analysis: analysis, daeun: daeun)
        let sections = Composer.sections(facts: facts, ruleSet: ruleSet)
        return Reading(
            person: person, chart: chart, analysis: analysis,
            daeun: daeun, facts: facts, sections: sections
        )
    }
}
