/// 천간(天干). 갑을병정무기경신임계.
public enum Cheongan: Int, CaseIterable, Sendable, Codable, Hashable {
    case gap, eul, byeong, jeong, mu, gi, gyeong, sin, im, gye

    public var korean: String {
        ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"][rawValue]
    }

    public var hanja: String {
        ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"][rawValue]
    }

    public var element: Element {
        Element(rawValue: rawValue / 2)!
    }

    public var yinYang: YinYang {
        rawValue.isMultiple(of: 2) ? .yang : .yin
    }

    /// 천간합(天干合) 상대. 갑기·을경·병신·정임·무계.
    public var combines: Cheongan {
        Cheongan(rawValue: (rawValue + 5) % 10)!
    }

    /// 천간충(天干沖) 상대. 갑경·을신·병임·정계 (무기는 충이 없음).
    public var clashes: Cheongan? {
        let e = element
        guard e != .earth else { return nil }
        let other = Cheongan(rawValue: (rawValue + 6) % 10)!
        return other.element == e.controlledBy || other.element == e.controls ? other : nil
    }
}
