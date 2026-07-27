import Foundation

/// 사주의 네 기둥 위치.
public enum PillarPosition: String, CaseIterable, Sendable, Codable {
    case year = "년주"
    case month = "월주"
    case day = "일주"
    case hour = "시주"

    public var hanja: String {
        switch self {
        case .year: "年柱"
        case .month: "月柱"
        case .day: "日柱"
        case .hour: "時柱"
        }
    }
}

/// 계산 과정에서 적용된 시간 보정 내역 — UI에 그대로 노출한다.
public struct TimeCorrections: Sendable, Codable, Hashable {
    /// 입력 벽시계 시각의 UTC 오프셋(초). 예: 서머타임기 36000.
    public let utcOffsetSeconds: Int
    /// 서머타임 적용 여부.
    public let isDST: Bool
    /// 경도 보정(분). 서울 기준 약 −32.
    public let longitudeCorrectionMinutes: Double
    /// 균시차(분). 옵션이 꺼져 있으면 0.
    public let equationOfTimeMinutes: Double
    /// 최종 보정 시각(태양시) — "HH:mm" 표기용 초 단위 하루 오프셋.
    public let solarTimeSecondsOfDay: Int
    /// 태양시 기준 날짜의 JDN.
    public let solarDateJDN: Int
}

/// 명식(命式) — 계산 결과의 전부.
public struct SajuChart: Sendable, Codable, Hashable {
    public let input: BirthInput
    /// 양력 환산 생년월일 (음력 입력 시 변환 결과).
    public let solarYear: Int
    public let solarMonth: Int
    public let solarDay: Int
    /// 음력 환산 (양력 입력 시 변환 결과).
    public let lunarDate: LunarDate?

    public let yearPillar: Ganji
    public let monthPillar: Ganji
    public let dayPillar: Ganji
    /// 시간 미상이면 nil.
    public let hourPillar: Ganji?

    /// 야자시 여부 (23시대 출생, yajasi 정책에서 시두만 익일 기준).
    public let isNightJasi: Bool
    /// 사주 연도 (입춘 기준).
    public let sajuYear: Int
    /// 월주를 연 절기.
    public let governingJeol: SolarTerm
    public let corrections: TimeCorrections

    public var dayMaster: Cheongan { dayPillar.stem }

    public var pillars: [(position: PillarPosition, ganji: Ganji)] {
        var result: [(PillarPosition, Ganji)] = [
            (.year, yearPillar), (.month, monthPillar), (.day, dayPillar),
        ]
        if let hourPillar {
            result.append((.hour, hourPillar))
        }
        return result
    }

    public func pillar(at position: PillarPosition) -> Ganji? {
        switch position {
        case .year: yearPillar
        case .month: monthPillar
        case .day: dayPillar
        case .hour: hourPillar
        }
    }

    /// 위치별 십신 (일간 자신은 nil).
    public func tenGod(at position: PillarPosition, stem: Bool) -> TenGod? {
        guard let ganji = pillar(at: position) else { return nil }
        if stem {
            if position == .day { return nil }
            return TenGod.of(dayMaster: dayMaster, target: ganji.stem)
        }
        return TenGod.of(dayMaster: dayMaster, branch: ganji.branch)
    }

    /// 위치별 십이운성 (일간 기준).
    public func twelveStage(at position: PillarPosition) -> TwelveStage? {
        guard let ganji = pillar(at: position) else { return nil }
        return TwelveStage.of(stem: dayMaster, branch: ganji.branch)
    }

    /// 팔자 압축 표기: "癸未 甲寅 丙寅 甲午" (년월일시 순).
    public var compactHanja: String {
        var parts = [yearPillar.hanja, monthPillar.hanja, dayPillar.hanja]
        if let hourPillar { parts.append(hourPillar.hanja) }
        return parts.joined(separator: " ")
    }
}
