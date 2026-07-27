import Foundation

/// 그날·그달·그해가 명식과 맺는 관계.
///
/// 설계 원칙: **날을 평가하지 않는다.** 길일·흉일 같은 등급을 매기지 않고
/// 어떤 성격의 기운이 실리는 국면인지만 서술한다. 등급을 매기는 순간
/// 공포 마케팅이 되고, 근거 추적이라는 이 앱의 정체성과도 어긋난다.
public struct DayReading: Sendable, Hashable, Identifiable {
    /// 해당 날짜(로컬 자정 기준).
    public let date: Date
    public let ganji: Ganji
    /// 그날 천간이 일간에 대해 갖는 십신.
    public let stemGod: TenGod
    /// 그날 지지가 일간에 대해 갖는 십신.
    public let branchGod: TenGod
    /// 그날 지지에서의 일간 십이운성.
    public let stage: TwelveStage
    /// 명식 지지와 맺는 관계.
    public let relations: [DayRelation]
    /// 일주 공망에 해당하는 날인가.
    public let isVoid: Bool
    /// 그날 천간이 일간과 천간합인가.
    public let combinesDayMaster: Bool

    public var id: Date { date }

    /// 명식이 이 날과 만나는 지점.
    public struct DayRelation: Sendable, Hashable {
        public enum Kind: String, Sendable, CaseIterable {
            case chung = "충"
            case yukhap = "육합"
            case samhap = "삼합"
            case hyeong = "형"
        }
        public let kind: Kind
        /// 어느 기둥과 만나는가.
        public let position: PillarPosition
        public let display: String
    }
}

/// 한 달·한 해의 흐름.
public struct PeriodReading: Sendable, Hashable {
    public let ganji: Ganji
    public let stemGod: TenGod
    public let branchGod: TenGod
    /// 표시용 라벨. "2026년", "2026년 7월".
    public let label: String
}

public enum TimeFortune {
    /// 하루 판독.
    public static func day(_ date: Date, chart: SajuChart, timeZone: TimeZone = .current) -> DayReading {
        let ganji = PillarsEngine.dayGanji(on: date, timeZone: timeZone)
        let master = chart.dayMaster

        var relations: [DayReading.DayRelation] = []
        let natal = chart.pillars
        let natalBranches = Set(natal.map(\.ganji.branch))

        for (position, pillar) in natal {
            let b = pillar.branch
            if ganji.branch.clashes == b {
                relations.append(.init(
                    kind: .chung, position: position,
                    display: "\(ganji.branch.korean)\(b.korean)충"
                ))
            }
            if ganji.branch.combines == b {
                relations.append(.init(
                    kind: .yukhap, position: position,
                    display: "\(ganji.branch.korean)\(b.korean)합"
                ))
            }
            if isHyeong(ganji.branch, b) {
                relations.append(.init(
                    kind: .hyeong, position: position,
                    display: "\(ganji.branch.korean)\(b.korean)형"
                ))
            }
        }

        // 삼합은 그날 지지가 명식의 나머지 둘을 채워 국을 이룰 때만 성립.
        let trio = Set(ganji.branch.trineGroup)
        if trio.subtracting([ganji.branch]).isSubset(of: natalBranches) {
            let name = ganji.branch.trineGroup.map(\.korean).joined()
            if let position = natal.first(where: {
                trio.contains($0.ganji.branch) && $0.ganji.branch != ganji.branch
            })?.position {
                relations.append(.init(
                    kind: .samhap, position: position,
                    display: "\(name) 삼합(\(ganji.branch.trineElement.korean))"
                ))
            }
        }

        return DayReading(
            date: Calendar.startOfDay(date, in: timeZone),
            ganji: ganji,
            stemGod: TenGod.of(dayMaster: master, target: ganji.stem),
            branchGod: TenGod.of(dayMaster: master, branch: ganji.branch),
            stage: TwelveStage.of(stem: master, branch: ganji.branch),
            relations: relations,
            isVoid: chart.dayPillar.voidBranches.contains(ganji.branch),
            combinesDayMaster: master.combines == ganji.stem
        )
    }

    /// 자형(自刑)을 포함한 형 판정. 삼형은 명식 전체 맥락이 필요하므로
    /// 하루 판독에서는 두 지지 사이의 형만 본다.
    static func isHyeong(_ a: Jiji, _ b: Jiji) -> Bool {
        let pair: Set<Jiji> = [a, b]
        if pair == [.ja, .myo] { return true }
        if a == b, [Jiji.jin, .o, .yu, .hae].contains(a) { return true }
        // 인사신·축술미 삼형의 부분 관계.
        let trios: [Set<Jiji>] = [[.inn, .sa, .shin], [.chuk, .sul, .mi]]
        return trios.contains { pair.isSubset(of: $0) && a != b }
    }

    /// 세운 — 입춘 기준 연도.
    public static func year(_ sajuYear: Int, chart: SajuChart) -> PeriodReading {
        let ganji = PillarsEngine.yearGanji(forSajuYear: sajuYear)
        return PeriodReading(
            ganji: ganji,
            stemGod: TenGod.of(dayMaster: chart.dayMaster, target: ganji.stem),
            branchGod: TenGod.of(dayMaster: chart.dayMaster, branch: ganji.branch),
            label: "\(sajuYear)년"
        )
    }

    /// 월운 — 절기 기준 사주 월.
    public static func month(containing date: Date, chart: SajuChart) -> PeriodReading {
        let jeol = SolarTerms.governingJeol(at: date)
        let branch = jeol.term.monthBranch!
        // 관할 절 시점의 사주 연도로 월간을 세운다.
        var sajuYear = Calendar.gregorianUTC.component(.year, from: jeol.instant)
        if jeol.instant < SolarTerms.instant(of: .ipchun, year: sajuYear) {
            sajuYear -= 1
        }
        let yearStem = PillarsEngine.yearGanji(forSajuYear: sajuYear).stem
        let offset = (branch.rawValue - Jiji.inn.rawValue + 12) % 12
        let stem = Cheongan(rawValue: (yearStem.rawValue % 5 * 2 + 2 + offset) % 10)!
        let ganji = Ganji(stem: stem, branch: branch)
        return PeriodReading(
            ganji: ganji,
            stemGod: TenGod.of(dayMaster: chart.dayMaster, target: stem),
            branchGod: TenGod.of(dayMaster: chart.dayMaster, branch: branch),
            label: "\(jeol.term.korean)월"
        )
    }

    /// 달력 한 판. 표시 월의 앞뒤를 채워 주 단위로 정렬된 날짜를 낸다.
    public static func calendarGrid(
        year: Int, month: Int, chart: SajuChart, timeZone: TimeZone = .current
    ) -> [DayReading] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = cal.range(of: .day, in: .month, for: first)
        else { return [] }

        // 일요일 시작 격자.
        let leading = cal.component(.weekday, from: first) - 1
        let start = cal.date(byAdding: .day, value: -leading, to: first)!
        let total = ((leading + range.count) + 6) / 7 * 7

        return (0..<total).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            return day(date, chart: chart, timeZone: timeZone)
        }
    }
}

extension Calendar {
    static func startOfDay(_ date: Date, in timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.startOfDay(for: date)
    }
}
