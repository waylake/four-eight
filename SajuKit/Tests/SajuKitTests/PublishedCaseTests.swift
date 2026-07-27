import Foundation
import Testing
@testable import SajuKit

/// 공개 만세력 사례 대조 — 경계 케이스 위주의 외부 검증.
///
/// 출처: 명리보감 계산 예시(firstname.kr), 일진은 uncle.tools 만세력 달력으로
/// 교차 확인. 상세는 docs/research/manseryeok-validation.md.
///
/// 이 사례들은 하나같이 어렵다. 서머타임 + UTC+8:30 시대 + 절입 2분 차이 +
/// 자시 경계 + 해외 출생이 섞여 있다.
@Suite("공개 사례 대조")
struct PublishedCaseTests {
    static let busan = BirthPlace(name: "부산", longitude: 129.075)
    static let seoul = BirthPlace(name: "서울", longitude: 126.978)

    struct Case {
        let label: String
        let input: BirthInput
        let expected: String
        let note: String
    }

    @Test("1988-06-08 05:40 부산 — 서머타임 적용")
    func case1988June() throws {
        let chart = try PillarsEngine.chart(for: BirthInput(
            year: 1988, month: 6, day: 8, hour: 5, minute: 40,
            gender: .male, place: Self.busan
        ))
        #expect(chart.corrections.isDST)
        #expect(chart.compactHanja == "戊辰 戊午 甲午 丙寅")
    }

    @Test("1988-09-05 00:50 서울 — 서머타임 + 야자시 경계")
    func case1988Sept() throws {
        // 벽시계 00:50 → 표준시 23:50(전날) → 진태양시 23:18 → 야자시.
        let chart = try PillarsEngine.chart(for: BirthInput(
            year: 1988, month: 9, day: 5, hour: 0, minute: 50,
            gender: .male, place: Self.seoul
        ))
        #expect(chart.corrections.isDST)
        #expect(chart.isNightJasi)
        // 야자시: 일주는 9/4 임술 유지, 시주는 익일 계해일 기준 임자.
        #expect(chart.compactHanja == "戊辰 庚申 壬戌 壬子")

        // 자시일수 정책에서는 일주가 계해로 넘어간다.
        var rollover = SajuOptions.default
        rollover.jasiPolicy = .rollover
        let b = try PillarsEngine.chart(for: BirthInput(
            year: 1988, month: 9, day: 5, hour: 0, minute: 50,
            gender: .male, place: Self.seoul, options: rollover
        ))
        #expect(b.dayPillar.hanja == "癸亥")
        #expect(b.hourPillar?.hanja == "壬子")
    }

    @Test("1955-08-08 17:28 서울 — UTC+8:30 시대 + 서머타임 + 입추 경계")
    func case1955() throws {
        let chart = try PillarsEngine.chart(for: BirthInput(
            year: 1955, month: 8, day: 8, hour: 17, minute: 28,
            gender: .male, place: Self.seoul
        ))
        // 당시 서머타임 KDT = UTC+9:30.
        #expect(chart.corrections.isDST)
        #expect(chart.corrections.utcOffsetSeconds == 34200)
        // 입추 직후 → 신월.
        #expect(chart.governingJeol == .ipchu)
        #expect(chart.compactHanja == "乙未 甲申 辛丑 丙申")
    }

    @Test("1956-07-07 13:30 부산 — 소서 절입 2분 차")
    func case1956() throws {
        let chart = try PillarsEngine.chart(for: BirthInput(
            year: 1956, month: 7, day: 7, hour: 13, minute: 30,
            gender: .male, place: Self.busan
        ))
        #expect(chart.corrections.isDST)
        #expect(chart.governingJeol == .soseo)
        #expect(chart.compactHanja == "丙申 乙未 乙亥 壬午")
    }

    @Test("2005-05-10 00:20 부산 — 야자시로 넘어가는 자정 직후")
    func case2005Busan() throws {
        // 경도 보정 −23.7분 → 2005-05-09 23:56 → 야자시.
        let chart = try PillarsEngine.chart(for: BirthInput(
            year: 2005, month: 5, day: 10, hour: 0, minute: 20,
            gender: .male, place: Self.busan
        ))
        #expect(chart.isNightJasi)
        #expect(chart.compactHanja == "乙酉 辛巳 癸巳 甲子")
    }

    @Test("2005-05-10 00:52 서울 — 보정 후에도 조자시")
    func case2005Seoul() throws {
        // 경도 보정 −32분 → 00:20 → 조자시(당일 자시).
        let chart = try PillarsEngine.chart(for: BirthInput(
            year: 2005, month: 5, day: 10, hour: 0, minute: 52,
            gender: .male, place: Self.seoul
        ))
        #expect(chart.isNightJasi == false)
        #expect(chart.compactHanja == "乙酉 辛巳 甲午 甲子")
    }

    @Test("2005-05-05 05:55 워싱턴 D.C. — 해외 출생 + 미국 서머타임")
    func case2005DC() throws {
        let dc = BirthPlace(
            name: "워싱턴 D.C.", longitude: -77.0369,
            timeZoneIdentifier: "America/New_York"
        )
        let chart = try PillarsEngine.chart(for: BirthInput(
            year: 2005, month: 5, day: 5, hour: 5, minute: 55,
            gender: .male, place: dc
        ))
        #expect(chart.corrections.isDST)
        #expect(chart.governingJeol == .ipha)
        #expect(chart.compactHanja == "乙酉 辛巳 己丑 丙寅")
    }
}
