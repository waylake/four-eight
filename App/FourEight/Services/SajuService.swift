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

/// 특정 날짜의 시간운 판독.
struct DayFortune: Sendable {
    let date: Date
    let day: DayReading
    let month: PeriodReading
    let year: PeriodReading
    let facts: FactSet
    let sections: [InterpretationSection]
    /// 현재 대운.
    let daeunPeriod: DaeUn.Period?
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

    static func fortune(on date: Date, reading: Reading, timeZone: TimeZone = .current) -> DayFortune {
        let chart = reading.chart
        let day = TimeFortune.day(date, chart: chart, timeZone: timeZone)
        let month = TimeFortune.month(containing: date, chart: chart)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        var sajuYear = cal.component(.year, from: date)
        if date < SolarTerms.instant(of: .ipchun, year: sajuYear) { sajuYear -= 1 }
        let year = TimeFortune.year(sajuYear, chart: chart)

        let facts = TimeFactExtractor.facts(day: day, month: month, year: year, chart: chart)
        let sections = Composer.timeSections(facts: facts, ruleSet: ruleSet)

        let age = FactExtractor.ageYears(chart: chart, at: date)
        return DayFortune(
            date: day.date, day: day, month: month, year: year,
            facts: facts, sections: sections,
            daeunPeriod: reading.daeun?.current(ageYears: age)
        )
    }
}
