import Foundation
import Testing
@testable import SajuKit

@Suite("천문 계산")
struct AstroTests {
    @Test("율리우스일 앵커")
    func julianDay() {
        #expect(JulianDay.jdn(year: 2000, month: 1, day: 1) == 2451545)
        #expect(JulianDay.jdn(year: 1900, month: 1, day: 1) == 2415021)
        #expect(JulianDay.jdn(year: 2003, month: 2, day: 22) == 2452693)
        let civil = JulianDay.civil(fromJDN: 2452693)
        #expect(civil.year == 2003 && civil.month == 2 && civil.day == 22)
    }

    @Test("Meeus 예제 25.b — 1992-10-13 0h TD 태양 위치")
    func meeusExample() {
        let jde = 2448908.5
        let (_, _, r) = Solar.earthHeliocentric(jde: jde)
        // R = 0.99760775 AU (Meeus p.165).
        #expect(abs(r - 0.99760775) < 5e-6)
        let lambda = Solar.apparentLongitude(jde: jde) * 180 / .pi
        // 겉보기 황경 199°54′21″.5 ≈ 199.90599° (허용 ±2″).
        #expect(abs(lambda - 199.90599) < 0.0006)
    }

    @Test("절기 스모크 — 통용 공표값 대비 ±5분", arguments: [
        // (절기, 연도, KST "yyyy-MM-dd HH:mm")
        (SolarTerm.dongji, 2023, "2023-12-22 12:27"),
        (SolarTerm.ipchun, 2024, "2024-02-04 17:27"),
        (SolarTerm.chunbun, 2024, "2024-03-20 12:06"),
        (SolarTerm.haji, 2024, "2024-06-21 05:51"),
    ])
    func solarTermSmoke(term: SolarTerm, year: Int, expectedKST: String) throws {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        let expected = try #require(f.date(from: expectedKST))
        let computed = SolarTerms.instant(of: term, year: year)
        #expect(abs(computed.timeIntervalSince(expected)) < 300)
    }

    @Test("절기 시황경 도달 검증")
    func termLongitude() {
        for term in [SolarTerm.ipchun, .haji, .dongji, .chubun] {
            let jde = SolarTerms.jde(of: term, year: 2003)
            let lambda = Solar.apparentLongitude(jde: jde) * 180 / .pi
            let target = term.longitudeDegrees
            var diff = abs(lambda - target)
            if diff > 180 { diff = 360 - diff }
            #expect(diff < 1e-6)
        }
    }

    @Test("균시차 — 2월 중순 최소 근방")
    func equationOfTime() {
        let jd = Double(JulianDay.jdn(year: 2026, month: 2, day: 12))
        let eot = Solar.equationOfTimeMinutes(jde: jd)
        #expect(eot > -15.0 && eot < -13.0)
    }

    @Test("삭 순간 — 2026년 설날 전후")
    func newMoon() {
        // 2026-02-17 KST 설날 → 그 부근의 삭.
        let jd = Double(JulianDay.jdn(year: 2026, month: 2, day: 17))
        let k = MoonPhase.nearestNewMoonK(jd: jd)
        let jde = MoonPhase.newMoonJDE(k: k)
        // 삭이 2026-02-17 KST 날짜에 들어야 한다.
        let kstJDN = KoreanLunarCalendar.kstJDN(fromTT: jde)
        #expect(kstJDN == JulianDay.jdn(year: 2026, month: 2, day: 17))
    }
}
