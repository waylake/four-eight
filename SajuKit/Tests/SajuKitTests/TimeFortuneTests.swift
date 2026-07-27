import Foundation
import Testing
@testable import SajuKit

@Suite("시간운")
struct TimeFortuneTests {
    static let seoulTZ = TimeZone(identifier: "Asia/Seoul")!

    static func chart() throws -> SajuChart {
        try PillarsEngine.chart(for: BirthInput(
            year: 2003, month: 2, day: 22, hour: 13, minute: 13, gender: .male
        ))
    }

    static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = seoulTZ
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test("일진 십신 — 병화 일간 기준")
    func dayGods() throws {
        let chart = try Self.chart()
        // 2000-01-01 무오일. 병화 일간에게 무토는 식신, 오화는 겁재.
        let reading = TimeFortune.day(Self.date(2000, 1, 1), chart: chart, timeZone: Self.seoulTZ)
        #expect(reading.ganji.korean == "무오")
        #expect(reading.stemGod == .siksin)
        #expect(reading.branchGod == .geopjae)
        #expect(reading.stage == .jewang)   // 병화는 오에서 제왕.
    }

    @Test("명식과의 충 검출")
    func clashDetection() throws {
        let chart = try Self.chart()
        // 명식 지지: 미 인 인 오. 신(申)일은 인(寅)과 충 — 월지·일지 둘 다.
        var found: DayReading?
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.seoulTZ
        var probe = Self.date(2026, 1, 1)
        for _ in 0..<12 {
            let r = TimeFortune.day(probe, chart: chart, timeZone: Self.seoulTZ)
            if r.ganji.branch == .shin { found = r; break }
            probe = cal.date(byAdding: .day, value: 1, to: probe)!
        }
        let reading = try #require(found)
        let clashes = reading.relations.filter { $0.kind == .chung }
        #expect(clashes.count == 2)
        #expect(Set(clashes.map(\.position)) == [.month, .day])
    }

    @Test("공망일 판정")
    func voidDay() throws {
        let chart = try Self.chart()
        // 병인 일주의 공망은 술·해.
        #expect(chart.dayPillar.voidBranches == [.sul, .hae])
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.seoulTZ
        var probe = Self.date(2026, 3, 1)
        var checked = 0
        for _ in 0..<24 {
            let r = TimeFortune.day(probe, chart: chart, timeZone: Self.seoulTZ)
            let expected = r.ganji.branch == .sul || r.ganji.branch == .hae
            #expect(r.isVoid == expected)
            checked += 1
            probe = cal.date(byAdding: .day, value: 1, to: probe)!
        }
        #expect(checked == 24)
    }

    @Test("세운·월운 간지")
    func periods() throws {
        let chart = try Self.chart()
        let year = TimeFortune.year(2026, chart: chart)
        #expect(year.ganji.korean == "병오")
        #expect(year.stemGod == .bigyeon)   // 병화 일간에게 병화는 비견.

        // 2026-07-28은 소서(7/7) 이후 입추(8/7) 이전 → 미월.
        let month = TimeFortune.month(containing: Self.date(2026, 7, 28), chart: chart)
        #expect(month.ganji.branch == .mi)
        #expect(month.label == "소서월")
        // 병오년의 미월은 을미월 (병신년 기준 월두: 병·신년 → 경인월 시작).
        #expect(month.ganji.korean == "을미")
    }

    @Test("달력 격자 — 주 단위 정렬")
    func calendarGrid() throws {
        let chart = try Self.chart()
        let grid = TimeFortune.calendarGrid(year: 2026, month: 7, chart: chart, timeZone: Self.seoulTZ)
        #expect(grid.count % 7 == 0)
        #expect(grid.count >= 28 && grid.count <= 42)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.seoulTZ
        // 첫 칸은 일요일이어야 한다.
        #expect(cal.component(.weekday, from: grid[0].date) == 1)
        // 격자가 7월 1일을 포함해야 한다.
        let july1 = cal.startOfDay(for: Self.date(2026, 7, 1))
        #expect(grid.contains { $0.date == july1 })
        // 일진은 하루마다 정확히 하나씩 전진한다.
        for i in 1..<grid.count {
            let prev = grid[i - 1].ganji.cycleIndex
            #expect(grid[i].ganji.cycleIndex == (prev + 1) % 60)
        }
    }

    @Test("시간운 태그와 섹션 구성")
    func timeFactsAndSections() throws {
        let chart = try Self.chart()
        let ruleSet = try RuleSet.bundled()
        let today = Self.date(2026, 7, 28)
        let day = TimeFortune.day(today, chart: chart, timeZone: Self.seoulTZ)
        let facts = TimeFactExtractor.facts(
            day: day,
            month: TimeFortune.month(containing: today, chart: chart),
            year: TimeFortune.year(2026, chart: chart),
            chart: chart
        )
        #expect(facts.tags.contains { $0.hasPrefix("iljin_sibsin:") })
        #expect(facts.tags.contains { $0.hasPrefix("iljin_unseong:") })
        #expect(facts.tags.contains { $0.hasPrefix("sewoon_sibsin:") })
        #expect(!facts.summaryLines.isEmpty)

        let sections = Composer.timeSections(facts: facts, ruleSet: ruleSet)
        #expect(sections.count == 2)
        #expect(sections.allSatisfy { !$0.rules.isEmpty })
    }

    @Test("해석 콘텐츠에 길흉 판정어가 없다")
    func noVerdictLanguage() throws {
        let ruleSet = try RuleSet.bundled()
        // 날과 시기를 평가하지 않는다는 원칙이 콘텐츠에서도 지켜져야 한다.
        //
        // 단어 단위가 아니라 판정 표현 단위로 검사한다. "감정의 불길"(불꽃)이나
        // "불길한 표식이 아니라"(부정문) 같은 정상적인 문장을 벌주면 안 된다.
        let banned = ["흉일", "길일", "액운", "재앙", "나쁜 날", "좋은 날", "불운한", "운이 나쁜"]
        for rule in ruleSet.rules {
            for phrase in banned {
                #expect(!rule.text.contains(phrase), "\(rule.id)에 판정 표현 '\(phrase)' 포함")
            }
        }
    }
}
