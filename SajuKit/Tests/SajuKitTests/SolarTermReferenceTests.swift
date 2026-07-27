import Foundation
import Testing
@testable import SajuKit

/// 절기 시각 대조 — 공표 만세력·역서 값과의 회귀 검증.
///
/// 기준값 출처는 docs/research/manseryeok-validation.md에 정리되어 있다.
/// 역서(曆書) 기반 값과 JPL DE441 기반 값이 1분 어긋나는 사례가 있어
/// 허용 오차는 ±90초로 잡는다.
///
/// 주의: 표준시가 UTC+8:30이던 시기(1908–1911, 1954-03-21–1961-08-09)의
/// 공표 절기 시각은 그 시대 표준시로 기록되어 있다. 이 스위트는 UTC+9로
/// 환산된 값만 비교하며, 시대별 표준시는 tzdb가 처리한다.
@Suite("절기 기준값 대조")
struct SolarTermReferenceTests {
    static let tolerance: TimeInterval = 90

    static func kst(_ iso: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        f.timeZone = TimeZone(secondsFromGMT: 9 * 3600)
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: iso)!
    }

    /// 2003년 24절기 전체 — 절입 시각 완전 대조.
    @Test("2003년 24절기 전수", arguments: [
        (SolarTerm.sohan, "2003-01-06T03:27"),
        (.daehan, "2003-01-20T20:52"),
        (.ipchun, "2003-02-04T15:05"),
        (.usu, "2003-02-19T11:00"),
        (.gyeongchip, "2003-03-06T09:04"),
        (.chunbun, "2003-03-21T09:59"),
        (.cheongmyeong, "2003-04-05T13:52"),
        (.gogu, "2003-04-20T21:02"),
        (.ipha, "2003-05-06T07:10"),
        (.soman, "2003-05-21T20:12"),
        (.mangjong, "2003-06-06T11:19"),
        (.haji, "2003-06-22T04:10"),
        (.soseo, "2003-07-07T21:35"),
        (.daeseo, "2003-07-23T15:04"),
        (.ipchu, "2003-08-08T07:24"),
        (.cheoseo, "2003-08-23T22:08"),
        (.baekro, "2003-09-08T10:20"),
        (.chubun, "2003-09-23T19:46"),
        (.hanro, "2003-10-09T02:00"),
        (.sanggang, "2003-10-24T05:08"),
        (.ipdong, "2003-11-08T05:13"),
        (.soseol, "2003-11-23T02:43"),
        (.daeseol, "2003-12-07T22:05"),
        (.dongji, "2003-12-22T16:03"),
    ])
    func terms2003(term: SolarTerm, expected: String) {
        assertTerm(term, year: 2003, expectedKST: expected)
    }

    /// 역대 입춘 — 년주 경계 판정의 핵심.
    @Test("역대 입춘", arguments: [
        (1954, "1954-02-04T17:31"),
        (1987, "1987-02-04T17:52"),
        (1988, "1988-02-04T23:43"),
        (2000, "2000-02-04T21:40"),
        (2003, "2003-02-04T15:05"),
        (2004, "2004-02-04T20:56"),
        (2005, "2005-02-04T02:42"),
        (2024, "2024-02-04T17:27"),
        (2025, "2025-02-03T23:10"),
        (2026, "2026-02-04T05:02"),
    ])
    func ipchunHistory(year: Int, expected: String) {
        assertTerm(.ipchun, year: year, expectedKST: expected)
    }

    /// 2026년 12절 — 앞으로의 월주 경계.
    @Test("2026년 12절", arguments: [
        (SolarTerm.sohan, 2026, "2026-01-05T17:23"),
        (.gyeongchip, 2026, "2026-03-05T22:58"),
        (.cheongmyeong, 2026, "2026-04-05T03:39"),
        (.ipha, 2026, "2026-05-05T20:48"),
        (.mangjong, 2026, "2026-06-06T00:48"),
        (.soseo, 2026, "2026-07-07T10:56"),
        (.ipchu, 2026, "2026-08-07T20:42"),
        (.baekro, 2026, "2026-09-07T23:41"),
        (.hanro, 2026, "2026-10-08T15:29"),
        (.ipdong, 2026, "2026-11-07T18:52"),
        (.daeseol, 2026, "2026-12-07T11:52"),
        (.dongji, 2025, "2025-12-22T00:03"),
    ])
    func terms2026(term: SolarTerm, year: Int, expected: String) {
        assertTerm(term, year: year, expectedKST: expected)
    }

    /// 서머타임 시기 절기 — 절입 시각 자체는 표준시로 공표된다.
    @Test("1988년 절기", arguments: [
        (SolarTerm.mangjong, "1988-06-05T20:15"),
        (.soseo, "1988-07-07T06:33"),
        (.ipchu, "1988-08-07T16:20"),
        (.baekro, "1988-09-07T19:11"),
    ])
    func terms1988(term: SolarTerm, expected: String) {
        assertTerm(term, year: 1988, expectedKST: expected)
    }

    /// UTC+8:30 시대의 공표 절기 — 그 시대 표준시로 기록된 값과 대조한다.
    ///
    /// 1961년 입춘은 역서에 09:53으로 실려 있으나 이는 당시 표준시(UTC+8:30)
    /// 기준이다. UTC+9로 읽으면 10:23이 되므로, 시대 표준시를 명시하지 않으면
    /// 30분이 통째로 어긋난다. 만세력에서 반복해서 나오는 함정이다.
    @Test("1961년 입춘 — 당시 표준시 UTC+8:30 기준")
    func ipchun1961HistoricalOffset() {
        let computed = SolarTerms.instant(of: .ipchun, year: 1961)

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")

        // 당시 표준시로 읽으면 공표값 09:53과 맞는다 (DE441 계산은 09:52).
        f.timeZone = TimeZone(secondsFromGMT: 8 * 3600 + 1800)!
        let historical = f.date(from: "1961-02-04T09:53")!
        #expect(abs(computed.timeIntervalSince(historical)) <= Self.tolerance)

        // 같은 순간을 UTC+9로 읽으면 30분 뒤다.
        f.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let naive = f.date(from: "1961-02-04T10:23")!
        #expect(abs(computed.timeIntervalSince(naive)) <= Self.tolerance)
    }

    private func assertTerm(
        _ term: SolarTerm, year: Int, expectedKST: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let computed = SolarTerms.instant(of: term, year: year)
        let expected = Self.kst(expectedKST)
        let diff = computed.timeIntervalSince(expected)
        #expect(
            abs(diff) <= Self.tolerance,
            "\(year) \(term.korean): 계산 \(Self.format(computed)) vs 기준 \(expectedKST) (차이 \(Int(diff))초)",
            sourceLocation: sourceLocation
        )
    }

    static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone(secondsFromGMT: 9 * 3600)
        return f.string(from: date)
    }
}
