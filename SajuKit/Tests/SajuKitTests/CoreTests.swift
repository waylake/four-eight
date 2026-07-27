import Testing
@testable import SajuKit

@Suite("육십갑자 기본기")
struct CoreTests {
    @Test("갑자 순환 왕복")
    func cycleRoundtrip() {
        for i in 0..<60 {
            let g = Ganji(cycleIndex: i)
            #expect(g.cycleIndex == i)
        }
        #expect(Ganji(cycleIndex: 0).korean == "갑자")
        #expect(Ganji(cycleIndex: 59).korean == "계해")
        #expect(Ganji(cycleIndex: 2).korean == "병인")
    }

    @Test("천간 오행·음양")
    func stemProperties() {
        #expect(Cheongan.byeong.element == .fire)
        #expect(Cheongan.byeong.yinYang == .yang)
        #expect(Cheongan.gye.element == .water)
        #expect(Cheongan.gye.yinYang == .yin)
        #expect(Cheongan.gap.combines == .gi)
    }

    @Test("오행 상생상극")
    func elementRelations() {
        #expect(Element.wood.generates == .fire)
        #expect(Element.wood.controls == .earth)
        #expect(Element.water.generatedBy == .metal)
        #expect(Element.fire.controlledBy == .water)
    }

    @Test("십신 판정")
    func tenGods() {
        // 병화 일간: 갑목은 편인(목생화, 양양), 계수는 정관(수극화, 음양 상이).
        #expect(TenGod.of(dayMaster: .byeong, target: .gap) == .pyeonin)
        #expect(TenGod.of(dayMaster: .byeong, target: .gye) == .jeonggwan)
        #expect(TenGod.of(dayMaster: .byeong, target: .byeong) == .bigyeon)
        #expect(TenGod.of(dayMaster: .byeong, target: .jeong) == .geopjae)
        #expect(TenGod.of(dayMaster: .byeong, target: .gyeong) == .pyeonjae)
        // 지지는 정기 기준: 인 → 갑 → 편인.
        #expect(TenGod.of(dayMaster: .byeong, branch: .inn) == .pyeonin)
        // 오 → 정 → 겁재.
        #expect(TenGod.of(dayMaster: .byeong, branch: .o) == .geopjae)
    }

    @Test("십이운성 — 화토동법")
    func twelveStages() {
        #expect(TwelveStage.of(stem: .byeong, branch: .inn) == .jangsaeng)
        #expect(TwelveStage.of(stem: .gap, branch: .hae) == .jangsaeng)
        #expect(TwelveStage.of(stem: .eul, branch: .o) == .jangsaeng)
        #expect(TwelveStage.of(stem: .byeong, branch: .o) == .jewang)
        #expect(TwelveStage.of(stem: .mu, branch: .inn) == .jangsaeng)
        // 음간 역행: 계수 묘 장생 → 인 목욕.
        #expect(TwelveStage.of(stem: .gye, branch: .inn) == .mokyok)
    }

    @Test("공망 — 갑자순 술해")
    func voidBranches() {
        #expect(Ganji(cycleIndex: 0).voidBranches == [.sul, .hae])   // 갑자순
        #expect(Ganji(stem: .byeong, branch: .inn).voidBranches == [.sul, .hae])
        #expect(Ganji(cycleIndex: 10).voidBranches == [.shin, .yu])  // 갑술순
    }

    @Test("지장간 정기")
    func hiddenStems() {
        #expect(Jiji.inn.principalStem == .gap)
        #expect(Jiji.o.principalStem == .jeong)
        #expect(Jiji.ja.principalStem == .gye)
        #expect(Jiji.hae.hiddenStems == [.mu, .gap, .im])
    }
}
