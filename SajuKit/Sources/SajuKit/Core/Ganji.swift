/// 육십갑자(六十甲子)의 한 기둥. 천간 + 지지.
public struct Ganji: Sendable, Codable, Hashable, CustomStringConvertible {
    public let stem: Cheongan
    public let branch: Jiji

    public init(stem: Cheongan, branch: Jiji) {
        self.stem = stem
        self.branch = branch
    }

    /// 육십갑자 순환 인덱스(0 = 갑자, 59 = 계해)로 생성.
    public init(cycleIndex: Int) {
        let i = ((cycleIndex % 60) + 60) % 60
        self.stem = Cheongan(rawValue: i % 10)!
        self.branch = Jiji(rawValue: i % 12)!
    }

    /// 육십갑자 순환 인덱스 (0 = 갑자).
    public var cycleIndex: Int {
        // stem ≡ i (mod 10), branch ≡ i (mod 12) → CRT로 유일해 존재.
        var i = stem.rawValue
        while i % 12 != branch.rawValue { i += 10 }
        return i
    }

    /// 순환상 n칸 이동한 간지.
    public func advanced(by n: Int) -> Ganji {
        Ganji(cycleIndex: cycleIndex + n)
    }

    /// 갑자순(旬) 기준 공망(空亡) 지지 두 개.
    public var voidBranches: [Jiji] {
        let decadeStart = (cycleIndex / 10) * 10
        let firstBranch = decadeStart % 12
        return [Jiji(rawValue: (firstBranch + 10) % 12)!, Jiji(rawValue: (firstBranch + 11) % 12)!]
    }

    public var korean: String { stem.korean + branch.korean }
    public var hanja: String { stem.hanja + branch.hanja }
    public var description: String { "\(korean)(\(hanja))" }
}
