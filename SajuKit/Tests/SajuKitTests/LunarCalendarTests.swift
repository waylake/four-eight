import Testing
@testable import SajuKit

@Suite("한국 음양력")
struct LunarCalendarTests {
    @Test("설날 앵커", arguments: [
        (2003, 2, 1), (2024, 2, 10), (2025, 1, 29), (2026, 2, 17),
    ])
    func seollal(year: Int, month: Int, day: Int) {
        let lunar = KoreanLunarCalendar.lunar(fromSolarYear: year, month: month, day: day)
        #expect(lunar == LunarDate(year: year, month: 1, day: 1, isLeapMonth: false))
    }

    @Test("추석 앵커", arguments: [
        (2024, 9, 17), (2025, 10, 6),
    ])
    func chuseok(year: Int, month: Int, day: Int) {
        let lunar = KoreanLunarCalendar.lunar(fromSolarYear: year, month: month, day: day)
        #expect(lunar == LunarDate(year: year, month: 8, day: 15, isLeapMonth: false))
    }

    @Test("윤달", arguments: [
        (2020, 4), (2023, 2), (2025, 6),
    ])
    func leapMonths(year: Int, month: Int) {
        #expect(KoreanLunarCalendar.leapMonth(inLunarYear: year) == month)
    }

    @Test("음→양 역변환")
    func lunarToSolar() {
        let solar = KoreanLunarCalendar.solar(from: LunarDate(year: 2024, month: 1, day: 1))
        #expect(solar?.year == 2024 && solar?.month == 2 && solar?.day == 10)
        let chuseok = KoreanLunarCalendar.solar(from: LunarDate(year: 2025, month: 8, day: 15))
        #expect(chuseok?.year == 2025 && chuseok?.month == 10 && chuseok?.day == 6)
    }

    @Test("왕복 일관성 — 2003년 전체")
    func roundtrip() {
        for jdn in JulianDay.jdn(year: 2003, month: 1, day: 1)...JulianDay.jdn(year: 2003, month: 12, day: 31) {
            let (y, m, d) = JulianDay.civil(fromJDN: jdn)
            guard let lunar = KoreanLunarCalendar.lunar(fromSolarYear: y, month: m, day: d) else {
                Issue.record("음력 변환 실패: \(y)-\(m)-\(d)")
                continue
            }
            let back = KoreanLunarCalendar.solar(from: lunar)
            #expect(back?.year == y && back?.month == m && back?.day == d, "\(y)-\(m)-\(d) → \(lunar)")
        }
    }

    @Test("오너 생일 음력 확인 — 2003-02-22는 음력 1월 22일")
    func ownerLunar() {
        let lunar = KoreanLunarCalendar.lunar(fromSolarYear: 2003, month: 2, day: 22)
        #expect(lunar == LunarDate(year: 2003, month: 1, day: 22, isLeapMonth: false))
    }
}
