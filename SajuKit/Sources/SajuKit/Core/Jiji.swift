/// 지지(地支). 자축인묘진사오미신유술해.
public enum Jiji: Int, CaseIterable, Sendable, Codable, Hashable {
    case ja, chuk, inn, myo, jin, sa, o, mi, shin, yu, sul, hae

    public var korean: String {
        ["자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"][rawValue]
    }

    public var hanja: String {
        ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"][rawValue]
    }

    public var animal: String {
        ["쥐", "소", "호랑이", "토끼", "용", "뱀", "말", "양", "원숭이", "닭", "개", "돼지"][rawValue]
    }

    public var element: Element {
        switch self {
        case .ja: .water
        case .chuk: .earth
        case .inn: .wood
        case .myo: .wood
        case .jin: .earth
        case .sa: .fire
        case .o: .fire
        case .mi: .earth
        case .shin: .metal
        case .yu: .metal
        case .sul: .earth
        case .hae: .water
        }
    }

    public var yinYang: YinYang {
        rawValue.isMultiple(of: 2) ? .yang : .yin
    }

    /// 지장간(支藏干) — 인원용사(人元用事) 기준. 마지막 원소가 정기(正氣).
    public var hiddenStems: [Cheongan] {
        switch self {
        case .ja: [.im, .gye]
        case .chuk: [.gye, .sin, .gi]
        case .inn: [.mu, .byeong, .gap]
        case .myo: [.gap, .eul]
        case .jin: [.eul, .gye, .mu]
        case .sa: [.mu, .gyeong, .byeong]
        case .o: [.byeong, .gi, .jeong]
        case .mi: [.jeong, .eul, .gi]
        case .shin: [.mu, .im, .gyeong]
        case .yu: [.gyeong, .sin]
        case .sul: [.sin, .jeong, .mu]
        case .hae: [.mu, .gap, .im]
        }
    }

    /// 정기(正氣) — 지지의 대표 천간. 십신 산출의 기준.
    public var principalStem: Cheongan {
        hiddenStems.last!
    }

    /// 충(沖) 상대. 자오·축미·인신·묘유·진술·사해.
    public var clashes: Jiji {
        Jiji(rawValue: (rawValue + 6) % 12)!
    }

    /// 육합(六合) 상대. 자축·인해·묘술·진유·사신·오미.
    public var combines: Jiji {
        // (i + j) mod 12 == 1 인 쌍이 육합.
        Jiji(rawValue: ((13 - rawValue) % 12))!
    }

    /// 삼합(三合) 그룹. 신자진(수)·해묘미(목)·인오술(화)·사유축(금).
    public var trineGroup: [Jiji] {
        let start = Jiji(rawValue: rawValue % 4)!
        return [start, Jiji(rawValue: (start.rawValue + 4) % 12)!, Jiji(rawValue: (start.rawValue + 8) % 12)!]
    }

    /// 삼합국(三合局)의 오행. 왕지(旺支, 자오묘유) 기준.
    public var trineElement: Element {
        switch rawValue % 4 {
        case 0: .water   // 신자진
        case 1: .metal   // 사유축
        case 2: .fire    // 인오술
        default: .wood   // 해묘미
        }
    }
}
