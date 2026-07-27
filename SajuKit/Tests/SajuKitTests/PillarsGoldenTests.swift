import Foundation
import Testing
@testable import SajuKit

@Suite("사주 골든 케이스")
struct PillarsGoldenTests {
    @Test("골든 — 2003-02-22 13:13 서울 → 계미 갑인 병인 갑오")
    func golden20030222() throws {
        let input = BirthInput(
            year: 2003, month: 2, day: 22, hour: 13, minute: 13,
            gender: .male
        )
        let chart = try PillarsEngine.chart(for: input)
        #expect(chart.compactHanja == "癸未 甲寅 丙寅 甲午")
        #expect(chart.yearPillar.korean == "계미")
        #expect(chart.monthPillar.korean == "갑인")
        #expect(chart.dayPillar.korean == "병인")
        #expect(chart.hourPillar?.korean == "갑오")
        #expect(chart.sajuYear == 2003)
        #expect(chart.governingJeol == .ipchun)
        // 서울 경도 보정 ≈ −32분.
        #expect(abs(chart.corrections.longitudeCorrectionMinutes - (-32.088)) < 0.1)
        #expect(chart.corrections.isDST == false)
        // 진태양시 12:40 부근.
        let solarHour = chart.corrections.solarTimeSecondsOfDay / 3600
        #expect(solarHour == 12)
    }

    @Test("보정 끔 — 같은 출생이 미시(을미)로 이동")
    func golden20030222NoCorrection() throws {
        var options = SajuOptions.default
        options.solarTimeMode = .none
        let input = BirthInput(
            year: 2003, month: 2, day: 22, hour: 13, minute: 13,
            gender: .male, options: options
        )
        let chart = try PillarsEngine.chart(for: input)
        #expect(chart.hourPillar?.korean == "을미")
        #expect(chart.dayPillar.korean == "병인")   // 일주는 불변.
    }

    @Test("음력 입력 동치 — 2003년 음력 1월 22일")
    func lunarInputEquivalence() throws {
        let input = BirthInput(
            year: 2003, month: 1, day: 22, hour: 13, minute: 13,
            calendarType: .lunar(isLeapMonth: false),
            gender: .male
        )
        let chart = try PillarsEngine.chart(for: input)
        #expect(chart.compactHanja == "癸未 甲寅 丙寅 甲午")
        #expect(chart.solarYear == 2003 && chart.solarMonth == 2 && chart.solarDay == 22)
    }

    @Test("일진 앵커 — 1900-01-01 갑술, 2000-01-01 무오")
    func dayAnchors() {
        let tz = TimeZone(identifier: "Asia/Seoul")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let d1900 = cal.date(from: DateComponents(year: 1900, month: 1, day: 1, hour: 12))!
        #expect(PillarsEngine.dayGanji(on: d1900, timeZone: tz).korean == "갑술")
        let d2000 = cal.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 12))!
        #expect(PillarsEngine.dayGanji(on: d2000, timeZone: tz).korean == "무오")
    }

    @Test("서머타임 — 1987-07-01 12:00 출생")
    func dst1987() throws {
        let input = BirthInput(
            year: 1987, month: 7, day: 1, hour: 12, minute: 0,
            gender: .female
        )
        let chart = try PillarsEngine.chart(for: input)
        // 1987년 여름 KDT(UTC+10) 적용 확인.
        #expect(chart.corrections.isDST == true)
        #expect(chart.corrections.utcOffsetSeconds == 36000)
        // 벽시계 12:00 = 표준시 11:00 → 진태양시 10:28 → 사시.
        #expect(chart.hourPillar?.branch == .sa)
    }

    @Test("입춘 경계 — 절입 순간 전후로 년주가 갈린다")
    func ipchunBoundary() throws {
        let ipchun = SolarTerms.instant(of: .ipchun, year: 2003)
        let tz = TimeZone(identifier: "Asia/Seoul")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        func chart(minutesFromIpchun: Double) throws -> SajuChart {
            let date = ipchun.addingTimeInterval(minutesFromIpchun * 60)
            let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let input = BirthInput(
                year: c.year!, month: c.month!, day: c.day!,
                hour: c.hour!, minute: c.minute!, gender: .male
            )
            return try PillarsEngine.chart(for: input)
        }
        let before = try chart(minutesFromIpchun: -10)
        let after = try chart(minutesFromIpchun: +10)
        #expect(before.yearPillar.korean == "임오")   // 전년 임오년.
        #expect(before.sajuYear == 2002)
        #expect(after.yearPillar.korean == "계미")
        #expect(after.monthPillar.branch == .inn)
        #expect(before.monthPillar.branch == .chuk)  // 입춘 전은 축월(소한 관할).
    }

    @Test("야자시 정책 — 23시대 출생")
    func yajasiPolicy() throws {
        // 2003-02-22 23:40 서울 → 진태양시 23:08 자시.
        var yajasi = SajuOptions.default
        yajasi.jasiPolicy = .yajasi
        let a = try PillarsEngine.chart(for: BirthInput(
            year: 2003, month: 2, day: 22, hour: 23, minute: 40,
            gender: .male, options: yajasi
        ))
        #expect(a.isNightJasi == true)
        #expect(a.dayPillar.korean == "병인")        // 일주 유지.
        #expect(a.hourPillar?.korean == "경자")      // 시두는 익일 정묘일 기준.

        var rollover = SajuOptions.default
        rollover.jasiPolicy = .rollover
        let b = try PillarsEngine.chart(for: BirthInput(
            year: 2003, month: 2, day: 22, hour: 23, minute: 40,
            gender: .male, options: rollover
        ))
        #expect(b.dayPillar.korean == "정묘")        // 일주가 넘어간다.
        #expect(b.hourPillar?.korean == "경자")
    }

    @Test("시간 미상 — 삼주 계산")
    func unknownHour() throws {
        let input = BirthInput(year: 2003, month: 2, day: 22, gender: .male)
        let chart = try PillarsEngine.chart(for: input)
        #expect(chart.hourPillar == nil)
        #expect(chart.dayPillar.korean == "병인")
        #expect(chart.compactHanja == "癸未 甲寅 丙寅")
    }

    @Test("대운 — 계미년생 남녀 순역")
    func daeun() throws {
        let male = try PillarsEngine.chart(for: BirthInput(
            year: 2003, month: 2, day: 22, hour: 13, minute: 13, gender: .male
        ))
        let maleDaeun = try #require(DaeUnEngine.daeun(for: male))
        // 계(음간) + 남 → 역행. 첫 대운 = 월주 갑인 − 1 = 계축.
        #expect(maleDaeun.isForward == false)
        #expect(maleDaeun.periods[0].ganji.korean == "계축")
        // 역행 간격: 입춘(2/4)까지 약 18일 → 대운수 6 전후.
        #expect((5...7).contains(maleDaeun.daeunSu))

        let female = try PillarsEngine.chart(for: BirthInput(
            year: 2003, month: 2, day: 22, hour: 13, minute: 13, gender: .female
        ))
        let femaleDaeun = try #require(DaeUnEngine.daeun(for: female))
        #expect(femaleDaeun.isForward == true)
        #expect(femaleDaeun.periods[0].ganji.korean == "을묘")
    }

    @Test("분석 — 골든 명식의 구조값")
    func analysis() throws {
        let chart = try PillarsEngine.chart(for: BirthInput(
            year: 2003, month: 2, day: 22, hour: 13, minute: 13, gender: .male
        ))
        let a = Analyzer.analyze(chart)
        // 癸未 甲寅 丙寅 甲午: 목4(갑갑인인) 화2(병오) 토1(미) 수1(계).
        #expect(a.elementCounts[.wood] == 4)
        #expect(a.elementCounts[.fire] == 2)
        #expect(a.elementCounts[.earth] == 1)
        #expect(a.elementCounts[.water] == 1)
        #expect(a.elementCounts[.metal] == 0)
        // 인성(목) 과다 + 비겁 → 신강.
        #expect(a.strength == .strong)
        // 병인 일주 공망 술해 — 사주 내 술해 없음.
        #expect(a.voidBranches == [.sul, .hae])
        #expect(a.voidPositions.isEmpty)
    }

    @Test("룰 엔진 — 번들 로드와 섹션 구성")
    func ruleEngine() throws {
        let ruleSet = try RuleSet.bundled()
        #expect(ruleSet.rules.count == 108)
        let chart = try PillarsEngine.chart(for: BirthInput(
            year: 2003, month: 2, day: 22, hour: 13, minute: 13, gender: .male
        ))
        let analysis = Analyzer.analyze(chart)
        let daeun = DaeUnEngine.daeun(for: chart)
        let facts = FactExtractor.facts(chart: chart, analysis: analysis, daeun: daeun)
        #expect(facts.tags.contains("ilgan:병"))
        #expect(facts.tags.contains("strength:신강"))
        #expect(facts.tags.contains("oheng_excess:목"))
        #expect(facts.tags.contains("oheng_lack:금"))
        let sections = Composer.sections(facts: facts, ruleSet: ruleSet)
        #expect(sections.count >= 3)
        #expect(sections.first?.title == "총평")
    }
}
