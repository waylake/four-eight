/// ΔT = TT − UT1. 절기·삭망 순간(역학시)을 세계시로 환산할 때 사용.
///
/// 관측값 기반 구간 선형 보간. 출처: Espenak & Meeus, "Five Millennium Canon"
/// ΔT 표 및 IERS 관측치(2020년대 값). 분 단위 만세력 정밀도에서 ±수 초의
/// 오차는 무시 가능하다.
public enum DeltaT {
    /// (십진 연도, ΔT 초)
    static let table: [(Double, Double)] = [
        (1880, -5.4), (1890, -6.0), (1900, -2.8), (1910, 10.4), (1920, 21.2),
        (1930, 24.0), (1940, 24.3), (1950, 29.1), (1960, 33.1), (1970, 40.2),
        (1980, 50.5), (1990, 56.9), (2000, 63.8), (2005, 64.7), (2010, 66.1),
        (2015, 67.6), (2020, 69.4), (2023, 69.3), (2026, 69.2),
    ]

    /// 해당 연도의 ΔT(초).
    public static func seconds(decimalYear y: Double) -> Double {
        if y <= table.first!.0 { return table.first!.1 }
        if y >= table.last!.0 {
            // 2026년 이후 완만한 증가 가정(문서화된 외삽).
            return table.last!.1 + 0.1 * (y - table.last!.0)
        }
        for i in 1..<table.count where y <= table[i].0 {
            let (y0, v0) = table[i - 1]
            let (y1, v1) = table[i]
            return v0 + (v1 - v0) * (y - y0) / (y1 - y0)
        }
        return table.last!.1
    }

    /// 세계시 율리우스일 → 역학시(TT) 율리우스일.
    public static func tt(fromUT jd: Double) -> Double {
        jd + seconds(decimalYear: JulianDay.decimalYear(jd: jd)) / 86400.0
    }

    /// 역학시(TT) 율리우스일 → 세계시 율리우스일.
    public static func ut(fromTT jde: Double) -> Double {
        jde - seconds(decimalYear: JulianDay.decimalYear(jd: jde)) / 86400.0
    }
}
