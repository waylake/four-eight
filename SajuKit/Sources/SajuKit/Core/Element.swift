/// 오행(五行). 상생·상극 관계의 근원 타입.
public enum Element: Int, CaseIterable, Sendable, Codable, Hashable {
    case wood, fire, earth, metal, water

    public var korean: String {
        switch self {
        case .wood: "목"
        case .fire: "화"
        case .earth: "토"
        case .metal: "금"
        case .water: "수"
        }
    }

    public var hanja: String {
        switch self {
        case .wood: "木"
        case .fire: "火"
        case .earth: "土"
        case .metal: "金"
        case .water: "水"
        }
    }

    /// 내가 생(生)하는 오행. 목생화 화생토 토생금 금생수 수생목.
    public var generates: Element {
        Element(rawValue: (rawValue + 1) % 5)!
    }

    /// 내가 극(剋)하는 오행. 목극토 토극수 수극화 화극금 금극목.
    public var controls: Element {
        Element(rawValue: (rawValue + 2) % 5)!
    }

    /// 나를 생하는 오행.
    public var generatedBy: Element {
        Element(rawValue: (rawValue + 4) % 5)!
    }

    /// 나를 극하는 오행.
    public var controlledBy: Element {
        Element(rawValue: (rawValue + 3) % 5)!
    }
}

/// 음양(陰陽).
public enum YinYang: Sendable, Codable, Hashable {
    case yang, yin

    public var korean: String { self == .yang ? "양" : "음" }
    public var hanja: String { self == .yang ? "陽" : "陰" }
}
