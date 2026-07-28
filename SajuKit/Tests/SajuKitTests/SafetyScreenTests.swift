import Testing
@testable import SajuKit

/// 안전 선별 — 양방향으로 고정한다.
///
/// 놓치는 쪽과 과하게 잡는 쪽의 대가가 다르다. 놓치면 위기의 사용자에게
/// 운세 문장이 나가고, 과하게 잡으면 평범한 고민이 매번 안내문으로 끊긴다.
/// 어느 쪽도 나중에 조용히 나빠지면 안 되므로 둘 다 테스트로 박아 둔다.
@Suite("상담 안전 선별")
struct SafetyScreenTests {
    @Test("위기 표현을 잡는다")
    func detectsCrisis() {
        let inputs = [
            "요즘 죽고 싶다는 생각이 자주 듭니다",
            "다 끝내고 싶어요",
            "자해를 한 적이 있습니다",
            "살기 싫어요",
            "그냥 사라지고 싶습니다",
        ]
        for input in inputs {
            guard case .crisis = SafetyScreen.evaluate(input) else {
                Issue.record("위기 표현을 놓쳤다: \(input)")
                continue
            }
        }
    }

    /// 실제로 밟은 오탐.
    ///
    /// 처음 목록에는 "목을 매"가 있었고, "이 종목을 **매수**해도 될까요"가
    /// 낱말 경계를 넘어 걸렸다. 투자 질문에 자살예방 상담 안내가 나가는
    /// 것은 오탐 중에서도 최악이므로 이 문장을 영구히 남겨 둔다.
    @Test("낱말 경계를 넘는 오탐이 없다")
    func avoidsCrossWordCollisions() {
        let inputs = [
            "이 종목을 매수해도 될까요",
            "제 목을 매만지는 습관이 있습니다",
            "유서희 선생님을 만나야 할까요",
        ]
        for input in inputs {
            if case .crisis(let matched) = SafetyScreen.evaluate(input) {
                Issue.record("오탐: \(input) — \(matched)")
            }
        }
    }

    /// 한국어 관용 표현. 여기서 걸리면 상담이 매번 끊긴다.
    @Test("관용적 과장은 위기로 보지 않는다")
    func ignoresHyperbole() {
        let inputs = [
            "일이 너무 많아서 힘들어 죽겠어요",
            "배고파 죽겠습니다",
            "웃겨 죽을 것 같았어요",
            "요즘 회사 일이 죽을 만큼 바쁩니다",
            "죽어라 일했는데 인정을 못 받아요",
        ]
        for input in inputs {
            #expect(SafetyScreen.evaluate(input) == .clear, "관용 표현을 위기로 잡았다: \(input)")
        }
    }

    @Test("의료·법률·투자 요구는 범위 밖으로 표시한다")
    func detectsOutOfScope() {
        let inputs = [
            "제 병명이 무엇일지 봐 주세요",
            "이 종목을 매수해도 될까요",
            "소송을 걸면 이길까요",
        ]
        for input in inputs {
            guard case .outOfScope = SafetyScreen.evaluate(input) else {
                Issue.record("범위 밖 요구를 놓쳤다: \(input)")
                continue
            }
        }
    }

    /// 위기가 범위 밖 표현보다 먼저다. 둘이 함께 있으면 위기로 다룬다.
    @Test("위기가 다른 판정보다 앞선다")
    func crisisTakesPrecedence() {
        guard case .crisis = SafetyScreen.evaluate("약을 모아 두었습니다. 처방을 받아야 할까요") else {
            Issue.record("위기 우선순위가 지켜지지 않았다")
            return
        }
    }

    @Test("평범한 고민은 통과한다")
    func passesOrdinaryConcerns() {
        let inputs = [
            "이직을 할까 고민입니다",
            "연애가 잘 안 됩니다",
            "돈 관리가 어렵습니다",
            "요즘 기운이 없고 지칩니다",
        ]
        for input in inputs {
            #expect(SafetyScreen.evaluate(input) == .clear, "평범한 고민이 걸렸다: \(input)")
        }
    }
}
