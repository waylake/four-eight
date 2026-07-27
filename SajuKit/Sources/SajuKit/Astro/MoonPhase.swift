import Foundation

/// 삭(新月) 순간 — Meeus "Astronomical Algorithms" ch.49.
///
/// 정밀도 수 초 수준으로, 음력 월초(삭일) 판정에 충분하다.
/// 포팅 참조: soniakeys/meeus moonphase (MIT License).
public enum MoonPhase {
    /// 2000년 1월 첫 삭 기준의 삭망월 번호 k (정수 = 삭).
    public static func nearestNewMoonK(jd: Double) -> Double {
        ((JulianDay.decimalYear(jd: jd) - 2000) * 12.3685).rounded()
    }

    /// k번째 삭의 순간 — 역학시(TT) 율리우스일.
    public static func newMoonJDE(k: Double) -> Double {
        let T = k / 1236.85
        let deg = Double.pi / 180
        let T2 = T * T, T3 = T2 * T, T4 = T3 * T

        let mean = 2451550.09766 + 29.530588861 * k
            + 0.00015437 * T2 - 0.000000150 * T3 + 0.00000000073 * T4

        let E = 1 - 0.002516 * T - 0.0000074 * T2
        let M = (2.5534 + 29.10535670 * k - 0.0000014 * T2 - 0.00000011 * T3) * deg
        let Mp = (201.5643 + 385.81693528 * k + 0.0107582 * T2
            + 0.00001238 * T3 - 0.000000058 * T4) * deg
        let F = (160.7108 + 390.67050284 * k - 0.0016118 * T2
            - 0.00000227 * T3 + 0.000000011 * T4) * deg
        let O = (124.7746 - 1.56375588 * k + 0.0020672 * T2 + 0.00000215 * T3) * deg

        // 삭 보정항 (Meeus table 49.a).
        var c = -0.40720 * sin(Mp)
        c += 0.17241 * E * sin(M)
        c += 0.01608 * sin(2 * Mp)
        c += 0.01039 * sin(2 * F)
        c += 0.00739 * E * sin(Mp - M)
        c += -0.00514 * E * sin(Mp + M)
        c += 0.00208 * E * E * sin(2 * M)
        c += -0.00111 * sin(Mp - 2 * F)
        c += -0.00057 * sin(Mp + 2 * F)
        c += 0.00056 * E * sin(2 * Mp + M)
        c += -0.00042 * sin(3 * Mp)
        c += 0.00042 * E * sin(M + 2 * F)
        c += 0.00038 * E * sin(M - 2 * F)
        c += -0.00024 * E * sin(2 * Mp - M)
        c += -0.00017 * sin(O)
        c += -0.00007 * sin(Mp + 2 * M)
        c += 0.00004 * sin(2 * Mp - 2 * F)
        c += 0.00004 * sin(3 * M)
        c += 0.00003 * sin(Mp + M - 2 * F)
        c += 0.00003 * sin(2 * Mp + 2 * F)
        c += -0.00003 * sin(Mp + M + 2 * F)
        c += 0.00003 * sin(Mp - M + 2 * F)
        c += -0.00002 * sin(Mp - M - 2 * F)
        c += -0.00002 * sin(3 * Mp + M)
        c += 0.00002 * sin(4 * Mp)

        // 행성 섭동 추가항 (Meeus table 49.b 인수).
        let A: [Double] = [
            299.77 + 0.107408 * k - 0.009173 * T2,
            251.88 + 0.016321 * k,
            251.83 + 26.651886 * k,
            349.42 + 36.412478 * k,
            84.66 + 18.206239 * k,
            141.74 + 53.303771 * k,
            207.14 + 2.453732 * k,
            154.84 + 7.30686 * k,
            34.52 + 27.261239 * k,
            207.19 + 0.121824 * k,
            291.34 + 1.844379 * k,
            161.72 + 24.198154 * k,
            239.56 + 25.513099 * k,
            331.55 + 3.592518 * k,
        ]
        let ac: [Double] = [
            0.000325, 0.000165, 0.000164, 0.000126, 0.000110, 0.000062, 0.000060,
            0.000056, 0.000047, 0.000042, 0.000040, 0.000037, 0.000035, 0.000023,
        ]
        var add = 0.0
        for i in 0..<14 {
            add += ac[i] * sin(A[i] * deg)
        }
        return mean + c + add
    }
}
