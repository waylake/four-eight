import Foundation

/// 음력 날짜.
public struct LunarDate: Sendable, Codable, Hashable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int
    public let isLeapMonth: Bool

    public init(year: Int, month: Int, day: Int, isLeapMonth: Bool = false) {
        self.year = year
        self.month = month
        self.day = day
        self.isLeapMonth = isLeapMonth
    }

    public var description: String {
        "\(year)년 \(isLeapMonth ? "윤" : "")\(month)월 \(day)일"
    }
}

/// 한국 음양력 변환 — 천문 계산 기반.
///
/// 규칙(KASI 관례와 동일):
/// - 월초 = 삭(新月)이 드는 KST 날짜
/// - 동지가 드는 달 = 음력 11월 (동짓달 고정)
/// - 두 동짓달 사이가 13삭망월이면 중기(中氣) 없는 첫 달이 윤달 (무중치윤)
///
/// 한계: 삭·중기가 KST 자정에 수 초 이내로 근접하는 극단 사례(수십 년에
/// 한 번 꼴)는 공표 역서와 다를 수 있다. docs/research 참고.
public enum KoreanLunarCalendar {
    /// 역학시(TT) 순간 → 그 순간이 속한 KST 날짜의 JDN.
    static func kstJDN(fromTT jde: Double) -> Int {
        let ut = DeltaT.ut(fromTT: jde)
        return Int((ut + 9.0 / 24.0 + 0.5).rounded(.down))
    }

    /// 한 음력월: [삭일, 다음 삭일) — KST JDN 구간.
    struct LunarMonth {
        let startJDN: Int
        let endJDN: Int      // exclusive
        var length: Int { endJDN - startJDN }
        var number: Int = 0
        var isLeap: Bool = false
        var lunarYear: Int = 0
    }

    /// 동지(year)를 포함하는 음력 연주기(동짓달 ~ 다음 동짓달 전)를 구성.
    static func cycle(anchorYear: Int) -> [LunarMonth] {
        let dongji0 = SolarTerms.jde(of: .dongji, year: anchorYear)
        let dongji1 = SolarTerms.jde(of: .dongji, year: anchorYear + 1)
        let dongji0JDN = kstJDN(fromTT: dongji0)
        let dongji1JDN = kstJDN(fromTT: dongji1)

        // 동지 직전 삭부터 다음 동지 이후 삭까지 나열.
        var k = MoonPhase.nearestNewMoonK(jd: dongji0) - 2
        var newMoonJDNs: [Int] = []
        while true {
            let jde = MoonPhase.newMoonJDE(k: k)
            let jdn = kstJDN(fromTT: jde)
            if let last = newMoonJDNs.last, jdn <= last { k += 1; continue }
            newMoonJDNs.append(jdn)
            if jdn > dongji1JDN + 1 { break }
            k += 1
        }

        var months: [LunarMonth] = []
        for i in 0..<(newMoonJDNs.count - 1) {
            months.append(LunarMonth(startJDN: newMoonJDNs[i], endJDN: newMoonJDNs[i + 1]))
        }

        // 동짓달 인덱스.
        guard let m11 = months.firstIndex(where: { $0.startJDN <= dongji0JDN && dongji0JDN < $0.endJDN }),
              let m11Next = months.firstIndex(where: { $0.startJDN <= dongji1JDN && dongji1JDN < $0.endJDN })
        else { return [] }

        var cycleMonths = Array(months[m11..<m11Next])
        let isLeapCycle = cycleMonths.count == 13

        // 중기(中氣) 포함 여부 — 무중치윤.
        if isLeapCycle {
            let majorTermJDNs = majorTerms(coveringYears: anchorYear...(anchorYear + 1))
            var leapAssigned = false
            for i in 1..<cycleMonths.count {
                let m = cycleMonths[i]
                let hasMajor = majorTermJDNs.contains { m.startJDN <= $0 && $0 < m.endJDN }
                if !hasMajor && !leapAssigned {
                    cycleMonths[i].isLeap = true
                    leapAssigned = true
                }
            }
        }

        // 달 번호와 음력 연도 부여. 동짓달 = 11월, 소속 음력년은 anchorYear.
        var number = 11
        var lunarYear = anchorYear
        for i in 0..<cycleMonths.count {
            if cycleMonths[i].isLeap {
                cycleMonths[i].number = number
                cycleMonths[i].lunarYear = lunarYear
                continue
            }
            cycleMonths[i].number = number
            cycleMonths[i].lunarYear = lunarYear
            // 다음 달 준비.
            if number == 12 {
                number = 1
                lunarYear += 1
            } else {
                number += 1
            }
        }
        // 윤달은 앞 달과 같은 번호를 가져야 하므로 재보정.
        for i in 1..<cycleMonths.count where cycleMonths[i].isLeap {
            cycleMonths[i].number = cycleMonths[i - 1].number
            cycleMonths[i].lunarYear = cycleMonths[i - 1].lunarYear
        }
        return cycleMonths
    }

    /// 범위 내 중기(氣) 12종의 KST JDN 목록.
    private static func majorTerms(coveringYears years: ClosedRange<Int>) -> [Int] {
        var result: [Int] = []
        for y in years {
            for term in SolarTerm.allCases where !term.isJeol {
                result.append(kstJDN(fromTT: SolarTerms.jde(of: term, year: y)))
            }
        }
        return result
    }

    /// 양력 → 음력.
    public static func lunar(fromSolarYear year: Int, month: Int, day: Int) -> LunarDate? {
        let target = JulianDay.jdn(year: year, month: month, day: day)
        // 후보 주기: 당년 동지 주기와 전년 동지 주기.
        for anchor in [year, year - 1, year - 2] {
            for m in cycle(anchorYear: anchor) where m.startJDN <= target && target < m.endJDN {
                return LunarDate(
                    year: m.lunarYear,
                    month: m.number,
                    day: target - m.startJDN + 1,
                    isLeapMonth: m.isLeap
                )
            }
        }
        return nil
    }

    /// 음력 → 양력.
    public static func solar(from lunar: LunarDate) -> (year: Int, month: Int, day: Int)? {
        // 11·12월은 anchor = lunarYear, 1~10월은 anchor = lunarYear − 1 주기에 있다.
        let anchor = lunar.month >= 11 ? lunar.year : lunar.year - 1
        for a in [anchor, anchor + 1, anchor - 1] {
            for m in cycle(anchorYear: a)
            where m.lunarYear == lunar.year && m.number == lunar.month && m.isLeap == lunar.isLeapMonth {
                guard lunar.day >= 1 && lunar.day <= m.length else { return nil }
                return JulianDay.civil(fromJDN: m.startJDN + lunar.day - 1)
            }
        }
        return nil
    }

    /// 해당 음력년의 윤달 번호 (없으면 nil).
    public static func leapMonth(inLunarYear year: Int) -> Int? {
        for anchor in [year - 1, year] {
            for m in cycle(anchorYear: anchor) where m.isLeap && m.lunarYear == year {
                return m.number
            }
        }
        return nil
    }
}
