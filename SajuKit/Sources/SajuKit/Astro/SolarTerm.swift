import Foundation

/// 24절기. 태양 시황경 15° 간격.
///
/// 절(節) 12개가 사주 월주의 경계이고, 기(氣) 12개 중 동지는
/// 음력 11월 고정의 기준(치윤법)이다.
public enum SolarTerm: Int, CaseIterable, Sendable, Codable, Hashable {
    // 그레고리력 연초부터의 순서.
    case sohan, daehan, ipchun, usu, gyeongchip, chunbun
    case cheongmyeong, gogu, ipha, soman, mangjong, haji
    case soseo, daeseo, ipchu, cheoseo, baekro, chubun
    case hanro, sanggang, ipdong, soseol, daeseol, dongji

    public var korean: String {
        ["소한", "대한", "입춘", "우수", "경칩", "춘분", "청명", "곡우",
         "입하", "소만", "망종", "하지", "소서", "대서", "입추", "처서",
         "백로", "추분", "한로", "상강", "입동", "소설", "대설", "동지"][rawValue]
    }

    public var hanja: String {
        ["小寒", "大寒", "立春", "雨水", "驚蟄", "春分", "淸明", "穀雨",
         "立夏", "小滿", "芒種", "夏至", "小暑", "大暑", "立秋", "處暑",
         "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"][rawValue]
    }

    /// 태양 시황경(도). 소한 285° → 15°씩 증가.
    public var longitudeDegrees: Double {
        Double((285 + 15 * rawValue) % 360)
    }

    /// 절(節) 여부 — 월주 경계가 되는 12절.
    public var isJeol: Bool {
        rawValue.isMultiple(of: 2)
    }

    /// 절(節)이 여는 사주 월의 지지. 입춘→인 … 소한→축.
    public var monthBranch: Jiji? {
        guard isJeol else { return nil }
        // 소한(0)→축, 입춘(2)→인, 경칩(4)→묘 …
        return Jiji(rawValue: (rawValue / 2 + 1) % 12)
    }
}

/// 절기 순간 계산기.
public enum SolarTerms {
    /// 해당 그레고리력 연도에 드는 절기의 순간 — 역학시(TT) 율리우스일.
    public static func jde(of term: SolarTerm, year: Int) -> Double {
        let targetDeg = term.longitudeDegrees
        // 초기 추정: 1월 1일 태양 황경 ≈ 280°, 평균 이동 0.9856°/일.
        let jan1 = Double(JulianDay.jdn(year: year, month: 1, day: 1))
        let offsetDays = ((targetDeg - 280) + 360).truncatingRemainder(dividingBy: 360) / 0.9856
        var jde = jan1 + offsetDays
        let targetRad = targetDeg * .pi / 180
        // 뉴턴 반복 — 수치 미분, 6회면 마이크로초 수준 수렴.
        for _ in 0..<8 {
            let lambda = Solar.apparentLongitude(jde: jde)
            var delta = lambda - targetRad
            // 최단 각거리로 정규화.
            delta = (delta + .pi).truncatingRemainder(dividingBy: 2 * .pi)
            if delta < 0 { delta += 2 * .pi }
            delta -= .pi
            if abs(delta) < 1e-10 { break }
            let rate = angularRate(jde: jde)
            jde -= delta / rate
        }
        return jde
    }

    /// 절기 순간 — UTC.
    public static func instant(of term: SolarTerm, year: Int) -> Date {
        JulianDay.date(fromJD: DeltaT.ut(fromTT: jde(of: term, year: year)))
    }

    /// 황경 변화율(rad/일) — 수치 미분.
    private static func angularRate(jde: Double) -> Double {
        let h = 0.05
        var d = Solar.apparentLongitude(jde: jde + h) - Solar.apparentLongitude(jde: jde - h)
        d = (d + .pi).truncatingRemainder(dividingBy: 2 * .pi)
        if d < 0 { d += 2 * .pi }
        d -= .pi
        return d / (2 * h)
    }

    /// 어떤 UTC 순간을 관할하는 절(節)과 그 순간 — 월주 판정용.
    /// 반환: (절, 절입 UTC) — 해당 순간 이전의 가장 최근 절.
    public static func governingJeol(at utc: Date) -> (term: SolarTerm, instant: Date, year: Int) {
        let year = Calendar.gregorianUTC.component(.year, from: utc)
        // 후보: 전년 대설부터 당년 대설까지 — 충분한 범위를 정렬 검색.
        var candidates: [(SolarTerm, Date, Int)] = []
        for y in (year - 1)...(year + 1) {
            for term in SolarTerm.allCases where term.isJeol {
                candidates.append((term, instant(of: term, year: y), y))
            }
        }
        candidates.sort { $0.1 < $1.1 }
        var last = candidates.first!
        for c in candidates {
            if c.1 <= utc { last = c } else { break }
        }
        return last
    }
}

extension Calendar {
    /// UTC 고정 그레고리력.
    static let gregorianUTC: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
}
