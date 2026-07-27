/// 십신(十神). 일간과 다른 글자의 오행·음양 관계.
public enum TenGod: String, CaseIterable, Sendable, Codable, Hashable {
    case bigyeon = "비견"
    case geopjae = "겁재"
    case siksin = "식신"
    case sanggwan = "상관"
    case pyeonjae = "편재"
    case jeongjae = "정재"
    case pyeongwan = "편관"
    case jeonggwan = "정관"
    case pyeonin = "편인"
    case jeongin = "정인"

    public var korean: String { rawValue }

    public var hanja: String {
        switch self {
        case .bigyeon: "比肩"
        case .geopjae: "劫財"
        case .siksin: "食神"
        case .sanggwan: "傷官"
        case .pyeonjae: "偏財"
        case .jeongjae: "正財"
        case .pyeongwan: "偏官"
        case .jeonggwan: "正官"
        case .pyeonin: "偏印"
        case .jeongin: "正印"
        }
    }

    /// 다섯 그룹: 비겁·식상·재성·관성·인성.
    public var group: Group {
        switch self {
        case .bigyeon, .geopjae: .bigeop
        case .siksin, .sanggwan: .siksang
        case .pyeonjae, .jeongjae: .jaeseong
        case .pyeongwan, .jeonggwan: .gwanseong
        case .pyeonin, .jeongin: .inseong
        }
    }

    public enum Group: String, CaseIterable, Sendable, Codable {
        case bigeop = "비겁"
        case siksang = "식상"
        case jaeseong = "재성"
        case gwanseong = "관성"
        case inseong = "인성"

        /// 일간을 돕는 세력인가 (비겁·인성).
        public var supportsDayMaster: Bool {
            self == .bigeop || self == .inseong
        }
    }

    /// 일간 기준 대상 천간의 십신.
    public static func of(dayMaster: Cheongan, target: Cheongan) -> TenGod {
        let samePolarity = dayMaster.yinYang == target.yinYang
        let me = dayMaster.element
        switch target.element {
        case me:
            return samePolarity ? .bigyeon : .geopjae
        case me.generates:
            return samePolarity ? .siksin : .sanggwan
        case me.controls:
            return samePolarity ? .pyeonjae : .jeongjae
        case me.controlledBy:
            return samePolarity ? .pyeongwan : .jeonggwan
        case me.generatedBy:
            return samePolarity ? .pyeonin : .jeongin
        default:
            fatalError("unreachable")
        }
    }

    /// 일간 기준 지지의 십신 — 정기(正氣) 지장간으로 판정.
    public static func of(dayMaster: Cheongan, branch: Jiji) -> TenGod {
        of(dayMaster: dayMaster, target: branch.principalStem)
    }
}
