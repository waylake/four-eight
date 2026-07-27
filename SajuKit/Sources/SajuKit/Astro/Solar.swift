import Foundation

/// 태양 겉보기 황경 — VSOP87D 지구 계열 + FK5 보정 + 장동 + 광행차.
///
/// 절기 시각 산출의 핵심. 시황경 정밀도 ~0.01″ 수준으로,
/// 시간 오차 약 0.25초에 해당한다(태양 이동 1″ ≈ 24초).
public enum Solar {
    /// VSOP87 계열 평가. τ = J2000 기준 율리우스 천년.
    private static func evaluate(_ series: [[Double]], tau: Double) -> Double {
        var total = 0.0
        var power = 1.0
        for terms in series {
            var sum = 0.0
            var i = 0
            while i < terms.count {
                sum += terms[i] * cos(terms[i + 1] + terms[i + 2] * tau)
                i += 3
            }
            total += sum * power
            power *= tau
        }
        return total
    }

    /// 지구 일심 좌표 (L 황경 rad, B 황위 rad, R 거리 AU).
    static func earthHeliocentric(jde: Double) -> (l: Double, b: Double, r: Double) {
        let tau = (jde - 2451545.0) / 365250.0
        return (
            evaluate(VSOP87Earth.lSeries, tau: tau),
            evaluate(VSOP87Earth.bSeries, tau: tau),
            evaluate(VSOP87Earth.rSeries, tau: tau)
        )
    }

    /// 태양 겉보기 황경(라디안, 0..2π). jde는 역학시(TT).
    public static func apparentLongitude(jde: Double) -> Double {
        let sec = Double.pi / 180 / 3600
        let (l, b, r) = earthHeliocentric(jde: jde)
        // 지구 일심 → 태양 지심.
        var lambda = l + .pi
        var beta = -b
        // VSOP87 동역학 좌표계 → FK5 (Meeus 25.9).
        let T = (jde - 2451545.0) / 36525.0
        let lambdaP = lambda - (1.397 + 0.00031 * T) * T * .pi / 180
        lambda += -0.09033 * sec
        beta += 0.03916 * (cos(lambdaP) - sin(lambdaP)) * sec
        // 장동 + 광행차.
        lambda += Nutation.nutation(jde: jde).dPsi
        lambda -= 20.4898 / r * sec
        lambda = lambda.truncatingRemainder(dividingBy: 2 * .pi)
        if lambda < 0 { lambda += 2 * .pi }
        return lambda
    }

    /// 균시차(분). 양수 = 진태양시가 평균태양시보다 빠름 (Meeus ch.28).
    public static func equationOfTimeMinutes(jde: Double) -> Double {
        let tau = (jde - 2451545.0) / 365250.0
        // 태양 기하 평균 황경 (Meeus 28.2, 도 단위).
        var l0 = 280.4664567 + 360007.6982779 * tau + 0.03032028 * tau * tau
            + pow(tau, 3) / 49931 - pow(tau, 4) / 15300 - pow(tau, 5) / 2_000_000
        l0 = l0.truncatingRemainder(dividingBy: 360)
        if l0 < 0 { l0 += 360 }
        let lambda = apparentLongitude(jde: jde)
        let (dPsi, dEps) = Nutation.nutation(jde: jde)
        let eps = Nutation.meanObliquity(jde: jde) + dEps
        // 적경 (황위 ≈ 0 근사).
        var alpha = atan2(cos(eps) * sin(lambda), cos(lambda)) * 180 / .pi
        if alpha < 0 { alpha += 360 }
        var e = l0 - 0.0057183 - alpha + dPsi * 180 / .pi * cos(eps)
        // -180..180 범위 정규화 후 분 환산.
        e = (e + 180).truncatingRemainder(dividingBy: 360)
        if e < 0 { e += 360 }
        return (e - 180) * 4
    }
}
