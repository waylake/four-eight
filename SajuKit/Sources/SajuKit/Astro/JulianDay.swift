import Foundation

/// 율리우스일 변환. 그레고리력 기준(1583년 이후 유효).
public enum JulianDay {
    /// 자정 시작 달력 날짜의 정수 율리우스일 번호(정오 앵커).
    /// Fliegel & Van Flandern (1968).
    public static func jdn(year: Int, month: Int, day: Int) -> Int {
        let a = (month - 14) / 12
        return (1461 * (year + 4800 + a)) / 4
            + (367 * (month - 2 - 12 * a)) / 12
            - (3 * ((year + 4900 + a) / 100)) / 4
            + day - 32075
    }

    /// 정수 JDN → 그레고리력 날짜.
    public static func civil(fromJDN jdn: Int) -> (year: Int, month: Int, day: Int) {
        var l = jdn + 68569
        let n = (4 * l) / 146097
        l -= (146097 * n + 3) / 4
        let i = (4000 * (l + 1)) / 1461001
        l -= (1461 * i) / 4 - 31
        let j = (80 * l) / 2447
        let d = l - (2447 * j) / 80
        l = j / 11
        let m = j + 2 - 12 * l
        let y = 100 * (n - 49) + i + l
        return (y, m, d)
    }

    /// Date(UTC 순간) → 율리우스일.
    public static func jd(from date: Date) -> Double {
        date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    /// 율리우스일 → Date(UTC 순간).
    public static func date(fromJD jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - 2440587.5) * 86400.0)
    }

    /// 율리우스일이 속한 십진 연도 (근사, ΔT·k 추정용).
    public static func decimalYear(jd: Double) -> Double {
        2000.0 + (jd - 2451545.0) / 365.2425
    }
}
