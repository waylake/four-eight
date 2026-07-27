import Foundation

/// 명식에서 추출한 사실 태그 — 룰 매칭과 LLM 프롬프트의 공통 기반.
public struct FactSet: Sendable, Codable, Hashable {
    /// 룰 매칭 태그 (예: "ilgan:병", "strength:신약", "sibsin:편재").
    public let tags: [String]
    /// 프롬프트·UI용 압축 명식 요약 라인.
    public let summaryLines: [String]

    public init(tags: [String], summaryLines: [String]) {
        self.tags = tags
        self.summaryLines = summaryLines
    }
}

public enum FactExtractor {
    /// 오행 과다 판정 기준 (8글자 중).
    static let excessThreshold = 3

    public static func facts(
        chart: SajuChart,
        analysis: SajuAnalysis,
        daeun: DaeUn?,
        currentDate: Date = Date()
    ) -> FactSet {
        var tags: [String] = []
        var lines: [String] = []

        // 일간.
        tags.append("ilgan:\(chart.dayMaster.korean)")

        // 신강신약.
        tags.append("strength:\(analysis.strength.rawValue)")

        // 월지 조후.
        tags.append("wolji:\(chart.monthPillar.branch.korean)")

        // 오행 과다·부족.
        for e in Element.allCases {
            let count = analysis.elementCounts[e] ?? 0
            if count >= excessThreshold { tags.append("oheng_excess:\(e.korean)") }
            if count == 0 { tags.append("oheng_lack:\(e.korean)") }
        }

        // 발달 십신 (2개 이상).
        let developed = analysis.tenGodCounts
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
        for (god, _) in developed.prefix(3) {
            tags.append("sibsin:\(god.korean)")
        }

        // 신살 (+ 공망은 별도 검출값에서).
        for hit in analysis.sinsalHits {
            let tag = "sinsal:\(hit.sinsal.rawValue)"
            if !tags.contains(tag) { tags.append(tag) }
        }
        if !analysis.voidPositions.isEmpty {
            tags.append("sinsal:공망")
        }

        // 현재 대운의 십신.
        if let daeun {
            let age = ageYears(chart: chart, at: currentDate)
            if let period = daeun.current(ageYears: age) {
                let god = TenGod.of(dayMaster: chart.dayMaster, target: period.ganji.stem)
                tags.append("daeun_sibsin:\(god.korean)")
            }
        }

        // 요약 라인 — LLM 프롬프트 주입용 (사실만, 해석 없음).
        lines.append("사주: \(chart.compactHanja) (년월일시 순)")
        lines.append("일간: \(chart.dayMaster.korean)\(chart.dayMaster.hanja) \(chart.dayMaster.element.korean)\(chart.dayMaster.yinYang.korean)")
        let elementSummary = Element.allCases
            .map { "\($0.korean)\(analysis.elementCounts[$0] ?? 0)" }
            .joined(separator: " ")
        lines.append("오행 분포: \(elementSummary)")
        lines.append("신강약: \(analysis.strength.rawValue) (세력비 \(String(format: "%.0f", analysis.strengthRatio * 100))%)")
        let godSummary = developed.prefix(3).map { "\($0.key.korean)\($0.value)" }.joined(separator: " ")
        if !godSummary.isEmpty { lines.append("발달 십신: \(godSummary)") }
        if !analysis.sinsalHits.isEmpty {
            let s = Set(analysis.sinsalHits.map(\.sinsal.rawValue)).sorted().joined(separator: " ")
            lines.append("신살: \(s)")
        }
        if !analysis.relations.isEmpty {
            let r = analysis.relations.map(\.display).joined(separator: ", ")
            lines.append("지지 관계: \(r)")
        }
        if let daeun {
            let age = ageYears(chart: chart, at: currentDate)
            if let period = daeun.current(ageYears: age) {
                lines.append("현재 대운: \(period.ganji.korean)(\(period.ganji.hanja)) \(period.startAge)세~")
            }
        }
        return FactSet(tags: tags, summaryLines: lines)
    }

    /// 만 나이 (해석·대운 현재 위치 판정용).
    public static func ageYears(chart: SajuChart, at date: Date) -> Int {
        let cal = Calendar.gregorianUTC
        let now = cal.dateComponents([.year, .month, .day], from: date)
        var age = now.year! - chart.solarYear
        if (now.month!, now.day!) < (chart.solarMonth, chart.solarDay) { age -= 1 }
        return max(0, age)
    }
}
