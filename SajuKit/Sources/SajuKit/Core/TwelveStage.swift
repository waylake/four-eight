/// 십이운성(十二運星). 화토동법(火土同法), 양간 순행·음간 역행.
public enum TwelveStage: Int, CaseIterable, Sendable, Codable, Hashable {
    case jangsaeng, mokyok, gwandae, geonrok, jewang, soe, byeong, sa, myo, jeol, tae, yang

    public var korean: String {
        ["장생", "목욕", "관대", "건록", "제왕", "쇠", "병", "사", "묘", "절", "태", "양"][rawValue]
    }

    public var hanja: String {
        ["長生", "沐浴", "冠帶", "建祿", "帝旺", "衰", "病", "死", "墓", "絶", "胎", "養"][rawValue]
    }

    /// 각 천간의 장생(長生) 지지. 화토동법 기준.
    static func birthAnchor(of stem: Cheongan) -> Jiji {
        switch stem {
        case .gap: .hae
        case .eul: .o
        case .byeong, .mu: .inn
        case .jeong, .gi: .yu
        case .gyeong: .sa
        case .sin: .ja
        case .im: .shin
        case .gye: .myo
        }
    }

    /// 천간이 지지에서 갖는 십이운성.
    public static func of(stem: Cheongan, branch: Jiji) -> TwelveStage {
        let anchor = birthAnchor(of: stem).rawValue
        let offset: Int
        if stem.yinYang == .yang {
            offset = (branch.rawValue - anchor + 12) % 12
        } else {
            offset = (anchor - branch.rawValue + 12) % 12
        }
        return TwelveStage(rawValue: offset)!
    }
}
