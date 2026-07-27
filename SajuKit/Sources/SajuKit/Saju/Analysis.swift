import Foundation

/// 신살(神煞) — 핵심 5종.
public enum Sinsal: String, CaseIterable, Sendable, Codable {
    case cheoneul = "천을귀인"
    case dohwa = "도화"
    case yeokma = "역마"
    case hwagae = "화개"
    case yangin = "양인"

    public var hanja: String {
        switch self {
        case .cheoneul: "天乙貴人"
        case .dohwa: "桃花"
        case .yeokma: "驛馬"
        case .hwagae: "華蓋"
        case .yangin: "羊刃"
        }
    }
}

/// 신살 검출 결과.
public struct SinsalHit: Sendable, Codable, Hashable {
    public let sinsal: Sinsal
    /// 어느 기둥의 지지에서 발견되었는가.
    public let position: PillarPosition
    /// 판정 기준 (예: "일간 병", "일지 인 삼합").
    public let basis: String
}

/// 지지 관계 (합충형파해).
public struct BranchRelation: Sendable, Codable, Hashable {
    public enum Kind: String, Sendable, Codable, CaseIterable {
        case yukhap = "육합"
        case samhap = "삼합"
        case banghap = "방합"
        case chung = "충"
        case hyeong = "형"
        case pa = "파"
        case hae = "해"
        case cheonganHap = "천간합"
    }

    public let kind: Kind
    public let positions: [PillarPosition]
    public let display: String
}

/// 신강·신약.
public enum Strength: String, Sendable, Codable {
    case strong = "신강"
    case weak = "신약"
    case balanced = "중화"
}

/// 명식 분석 결과.
public struct SajuAnalysis: Sendable, Codable, Hashable {
    /// 오행 분포 — 여덟 글자(시간 미상 시 여섯) 단순 계수.
    public let elementCounts: [Element: Int]
    /// 십신 분포 (일간 제외 천간 + 지지 정기).
    public let tenGodCounts: [TenGod: Int]
    /// 일간 세력 비율 (0..1) — 위치 가중 모델.
    public let strengthRatio: Double
    public let strength: Strength
    public let sinsalHits: [SinsalHit]
    /// 공망 지지와 해당 기둥.
    public let voidBranches: [Jiji]
    public let voidPositions: [PillarPosition]
    public let relations: [BranchRelation]
}

public enum Analyzer {
    public static func analyze(_ chart: SajuChart) -> SajuAnalysis {
        let pillars = chart.pillars

        // 오행 계수.
        var elements: [Element: Int] = [:]
        for e in Element.allCases { elements[e] = 0 }
        for (_, g) in pillars {
            elements[g.stem.element]! += 1
            elements[g.branch.element]! += 1
        }

        // 십신 계수 (일간 제외).
        var tenGods: [TenGod: Int] = [:]
        for (pos, g) in pillars {
            if pos != .day {
                tenGods[TenGod.of(dayMaster: chart.dayMaster, target: g.stem), default: 0] += 1
            }
            tenGods[TenGod.of(dayMaster: chart.dayMaster, branch: g.branch), default: 0] += 1
        }

        // 신강신약 — 위치 가중.
        let stemWeights: [PillarPosition: Double] = [.year: 1.0, .month: 1.2, .hour: 1.2]
        let branchWeights: [PillarPosition: Double] = [.year: 1.0, .month: 3.0, .day: 2.0, .hour: 1.5]
        var mine = 0.0, total = 0.0
        for (pos, g) in pillars {
            if pos != .day, let w = stemWeights[pos] {
                total += w
                let god = TenGod.of(dayMaster: chart.dayMaster, target: g.stem)
                if god.group.supportsDayMaster { mine += w }
            }
            if let w = branchWeights[pos] {
                total += w
                let god = TenGod.of(dayMaster: chart.dayMaster, branch: g.branch)
                if god.group.supportsDayMaster { mine += w }
            }
        }
        let ratio = total > 0 ? mine / total : 0.5
        let strength: Strength = ratio >= 0.55 ? .strong : (ratio <= 0.45 ? .weak : .balanced)

        return SajuAnalysis(
            elementCounts: elements,
            tenGodCounts: tenGods,
            strengthRatio: ratio,
            strength: strength,
            sinsalHits: detectSinsal(chart),
            voidBranches: chart.dayPillar.voidBranches,
            voidPositions: pillars.filter { pos, g in
                pos != .day && chart.dayPillar.voidBranches.contains(g.branch)
            }.map(\.position),
            relations: detectRelations(chart)
        )
    }

    // MARK: - 신살

    static func detectSinsal(_ chart: SajuChart) -> [SinsalHit] {
        var hits: [SinsalHit] = []
        let pillars = chart.pillars

        // 천을귀인 — 일간 기준.
        let cheoneulTargets: [Cheongan: [Jiji]] = [
            .gap: [.chuk, .mi], .mu: [.chuk, .mi], .gyeong: [.chuk, .mi],
            .eul: [.ja, .shin], .gi: [.ja, .shin],
            .byeong: [.hae, .yu], .jeong: [.hae, .yu],
            .sin: [.o, .inn],
            .im: [.sa, .myo], .gye: [.sa, .myo],
        ]
        if let targets = cheoneulTargets[chart.dayMaster] {
            for (pos, g) in pillars where targets.contains(g.branch) {
                hits.append(SinsalHit(
                    sinsal: .cheoneul, position: pos,
                    basis: "일간 \(chart.dayMaster.korean) 기준"
                ))
            }
        }

        // 도화·역마·화개 — 년지·일지 삼합 기준.
        func trineBased(_ sinsal: Sinsal, target: (Int) -> Int) {
            for (baseName, base) in [("년지", chart.yearPillar.branch), ("일지", chart.dayPillar.branch)] {
                let t = Jiji(rawValue: target(base.rawValue % 4))!
                for (pos, g) in pillars where g.branch == t {
                    // 자기 자신 기준 위치는 제외하지 않는다 — 동주 성립도 유효.
                    let hit = SinsalHit(
                        sinsal: sinsal, position: pos,
                        basis: "\(baseName) \(base.korean) 삼합 기준"
                    )
                    if !hits.contains(hit) { hits.append(hit) }
                }
            }
        }
        // 삼합군(rawValue % 4): 0 신자진, 1 사유축, 2 인오술, 3 해묘미.
        trineBased(.dohwa) { [9, 6, 3, 0][$0] }    // 유 오 묘 자
        trineBased(.yeokma) { [2, 11, 8, 5][$0] }  // 인 해 신 사
        trineBased(.hwagae) { [4, 1, 10, 7][$0] }  // 진 축 술 미

        // 양인 — 양간 일간 기준.
        let yanginTargets: [Cheongan: Jiji] = [.gap: .myo, .byeong: .o, .mu: .o, .gyeong: .yu, .im: .ja]
        if let t = yanginTargets[chart.dayMaster] {
            for (pos, g) in pillars where g.branch == t {
                hits.append(SinsalHit(sinsal: .yangin, position: pos, basis: "일간 \(chart.dayMaster.korean) 기준"))
            }
        }
        return hits
    }

    // MARK: - 합충형파해

    static func detectRelations(_ chart: SajuChart) -> [BranchRelation] {
        var result: [BranchRelation] = []
        let pillars = chart.pillars
        let branches = pillars.map { ($0.position, $0.ganji.branch) }
        let stems = pillars.map { ($0.position, $0.ganji.stem) }

        func pairKorean(_ a: Jiji, _ b: Jiji) -> String { "\(a.korean)\(b.korean)" }

        // 쌍 관계.
        let paPairs: Set<Set<Int>> = [[0, 9], [1, 4], [2, 11], [3, 6], [5, 8], [10, 7]]
        let haePairs: Set<Set<Int>> = [[0, 7], [1, 6], [2, 5], [3, 4], [8, 11], [9, 10]]
        let hyeongPairs: Set<Set<Int>> = [[0, 3]]   // 자묘형
        for i in 0..<branches.count {
            for j in (i + 1)..<branches.count {
                let (pa, a) = branches[i], (pb, b) = branches[j]
                let key: Set<Int> = [a.rawValue, b.rawValue]
                if a.combines == b {
                    result.append(.init(kind: .yukhap, positions: [pa, pb], display: pairKorean(a, b) + "합"))
                }
                if a.clashes == b {
                    result.append(.init(kind: .chung, positions: [pa, pb], display: pairKorean(a, b) + "충"))
                }
                if paPairs.contains(key) {
                    result.append(.init(kind: .pa, positions: [pa, pb], display: pairKorean(a, b) + "파"))
                }
                if haePairs.contains(key) {
                    result.append(.init(kind: .hae, positions: [pa, pb], display: pairKorean(a, b) + "해"))
                }
                if hyeongPairs.contains(key) || (a == b && [Jiji.jin, .o, .yu, .hae].contains(a)) {
                    result.append(.init(kind: .hyeong, positions: [pa, pb], display: pairKorean(a, b) + "형"))
                }
            }
        }

        // 삼형 (인사신·축술미) — 세 지지 모두 존재할 때.
        let branchSet = Set(branches.map(\.1))
        for (trio, name) in [([Jiji.inn, .sa, .shin], "인사신 삼형"), ([Jiji.chuk, .sul, .mi], "축술미 삼형")] {
            if Set(trio).isSubset(of: branchSet) {
                let positions = branches.filter { trio.contains($0.1) }.map(\.0)
                result.append(.init(kind: .hyeong, positions: positions, display: name))
            }
        }

        // 삼합·방합 — 세 지지 완전 성립.
        for start in 0..<4 {
            let trio = [Jiji(rawValue: start)!, Jiji(rawValue: start + 4)!, Jiji(rawValue: start + 8)!]
            if Set(trio).isSubset(of: branchSet) {
                let positions = branches.filter { trio.contains($0.1) }.map(\.0)
                let name = trio.map(\.korean).joined() + " 삼합(\(trio[0].trineElement.korean))"
                result.append(.init(kind: .samhap, positions: positions, display: name))
            }
        }
        let banghapGroups: [([Jiji], String)] = [
            ([.inn, .myo, .jin], "인묘진 방합(목)"),
            ([.sa, .o, .mi], "사오미 방합(화)"),
            ([.shin, .yu, .sul], "신유술 방합(금)"),
            ([.hae, .ja, .chuk], "해자축 방합(수)"),
        ]
        for (trio, name) in banghapGroups where Set(trio).isSubset(of: branchSet) {
            let positions = branches.filter { trio.contains($0.1) }.map(\.0)
            result.append(.init(kind: .banghap, positions: positions, display: name))
        }

        // 천간합.
        for i in 0..<stems.count {
            for j in (i + 1)..<stems.count {
                let (pa, a) = stems[i], (pb, b) = stems[j]
                if a.combines == b {
                    result.append(.init(
                        kind: .cheonganHap, positions: [pa, pb],
                        display: "\(a.korean)\(b.korean)합"
                    ))
                }
            }
        }
        return result
    }
}
