import Foundation

/// 대운(大運) — 10년 주기의 운.
public struct DaeUn: Sendable, Codable, Hashable {
    public struct Period: Sendable, Codable, Hashable, Identifiable {
        public let index: Int
        public let ganji: Ganji
        /// 시작 나이(만, 년 단위 내림).
        public let startAge: Int
        /// 시작 그레고리력 연도(근사 — 생일 기준).
        public let startYear: Int
        public var id: Int { index }
    }

    /// 순행 여부. 양남음녀 순행, 음남양녀 역행.
    public let isForward: Bool
    /// 출생 후 대운 시작까지의 개월 수 (일수 × 4개월 / 3일 규칙의 정밀값).
    public let startMonths: Int
    /// 표시용 대운수 (끝처리 옵션 적용).
    public let daeunSu: Int
    public let periods: [Period]

    /// 현재 나이에 해당하는 대운.
    public func current(ageYears: Int) -> Period? {
        periods.last { $0.startAge <= ageYears }
    }
}

public enum DaeUnEngine {
    /// 출생 벽시계 → UTC 순간 (엔진과 동일 규칙).
    static func utcInstant(of input: BirthInput, solarYMD: (Int, Int, Int)) -> Date? {
        guard let tz = TimeZone(identifier: input.place.timeZoneIdentifier) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        var comps = DateComponents()
        comps.year = solarYMD.0
        comps.month = solarYMD.1
        comps.day = solarYMD.2
        comps.hour = input.hour ?? 12
        comps.minute = input.minute
        return cal.date(from: comps)
    }

    public static func daeun(for chart: SajuChart) -> DaeUn? {
        guard let birthUTC = utcInstant(
            of: chart.input,
            solarYMD: (chart.solarYear, chart.solarMonth, chart.solarDay)
        ) else { return nil }

        let yearStem = chart.yearPillar.stem
        let isForward = (yearStem.yinYang == .yang) == (chart.input.gender == .male)

        // 절입까지의 간격.
        let intervalDays: Double
        if isForward {
            let next = SolarTerms.nextJeol(after: birthUTC)
            intervalDays = next.instant.timeIntervalSince(birthUTC) / 86400.0
        } else {
            let prev = SolarTerms.governingJeol(at: birthUTC)
            intervalDays = birthUTC.timeIntervalSince(prev.instant) / 86400.0
        }

        // 3일 = 1년 → 1일 = 4개월.
        let months = Int((intervalDays * 4).rounded())
        let daeunSu: Int
        switch chart.input.options.daeunRounding {
        case .round: daeunSu = max(1, Int((intervalDays / 3).rounded()))
        case .floor: daeunSu = max(1, Int(intervalDays / 3))
        }

        let startAgeYears = months / 12
        var periods: [DaeUn.Period] = []
        for i in 0..<10 {
            let step = isForward ? i + 1 : -(i + 1)
            periods.append(DaeUn.Period(
                index: i,
                ganji: chart.monthPillar.advanced(by: step),
                startAge: startAgeYears + i * 10,
                startYear: chart.solarYear + startAgeYears + i * 10
            ))
        }
        return DaeUn(isForward: isForward, startMonths: months, daeunSu: daeunSu, periods: periods)
    }

    /// 세운 목록 — 입춘 기준 연도의 간지.
    public static func annualCycle(fromYear year: Int, count: Int) -> [(year: Int, ganji: Ganji)] {
        (0..<count).map { offset in
            let y = year + offset
            return (y, PillarsEngine.yearGanji(forSajuYear: y))
        }
    }
}

extension SolarTerms {
    /// 주어진 UTC 순간 이후 첫 절(節).
    public static func nextJeol(after utc: Date) -> (term: SolarTerm, instant: Date, year: Int) {
        let year = Calendar.gregorianUTC.component(.year, from: utc)
        var candidates: [(SolarTerm, Date, Int)] = []
        for y in (year - 1)...(year + 1) {
            for term in SolarTerm.allCases where term.isJeol {
                candidates.append((term, instant(of: term, year: y), y))
            }
        }
        candidates.sort { $0.1 < $1.1 }
        return candidates.first { $0.1 > utc }!
    }
}
