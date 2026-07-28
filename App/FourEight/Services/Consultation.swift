import Foundation
import SajuKit

/// 상담 한 건.
///
/// 예전 구조는 "대화"였다. 인물별로 세션 하나가 있고, 메시지가 시간순으로
/// 쌓이고, 뷰가 사라지면 함께 사라졌다. 세 가지가 잘못돼 있었다.
///
/// 첫째, 뷰의 `@State`에 있었다. 인물을 바꾸면 날아가고, 모델을 적재하면
/// `bind`가 다시 불려 지워졌다 — 해석 쪽에서 고친 결함과 같은 것이다.
///
/// 둘째, 근거를 통째로 넣었다. 모든 섹션의 모든 규칙이 시스템 지시에
/// 들어갔다. 4B 모델에서 이것은 두 가지로 실패한다. 컨텍스트가 길어져
/// 지시 준수가 무너지고, 질문과 무관한 근거가 답에 섞인다. 그리고
/// **어떤 근거로 답했는지 알 수 없었다** — 해석 화면에는 근거 칩이 있는데
/// 대화에는 없었고, 앱의 정체성이 대화에서 깨져 있었다.
///
/// 셋째, 고민을 다룰 장치가 없었다. "이직할까요"에 모델은 판정하려 든다.
///
/// 그래서 단위를 바꿨다. 상담은 **고민 하나에 대한 실타래**다. 축이
/// 정해져 있고, 쓰인 근거가 적혀 있고, 디스크에 남고, 다시 열면 이어진다.
struct Consultation: Codable, Sendable, Identifiable, Hashable {
    let id: UUID
    /// 어느 인물의 어느 명식에 대한 상담인가. 유파 옵션을 바꾸면 서명이
    /// 달라지므로, 근거가 달라졌다는 것을 화면이 알 수 있다.
    let personID: UUID
    let signature: String
    let openedAt: Date
    /// 사용자가 처음 적은 고민 원문. 요약하지 않고 그대로 둔다.
    var concern: String
    /// 확정된 명리 축. 앱이 라우팅하고 사용자가 고칠 수 있다.
    var topic: ConsultationTopic
    /// 라우팅에서 실제로 걸린 말. 왜 이 축으로 읽었는지 화면에 보여준다.
    var matchedTerms: [String]
    /// 이 상담이 쓰는 근거 규칙 ID.
    var evidenceIDs: [String]
    /// 오늘의 기운을 함께 보는가.
    var includesToday: Bool
    var turns: [Turn]
    /// 마지막 답을 무엇으로 썼는지.
    var provenance: InterpretationStore.Provenance?

    struct Turn: Codable, Sendable, Identifiable, Hashable {
        enum Speaker: String, Codable, Sendable {
            case person      // 사용자
            case counselor   // 모델
            /// 앱이 결정론적으로 말한 것 — 되묻기, 안전 안내, 한계 고지.
            /// 모델이 말한 것과 구분해서 표시한다. 어느 쪽이 기계적으로
            /// 확정된 말인지 사용자가 알아야 한다.
            case app
        }
        let id: UUID
        var speaker: Speaker
        var text: String
        var isComplete: Bool
        /// 이 답이 실제로 쓴 근거. 답변마다 근거 칩이 붙는 근거다.
        var evidenceIDs: [String]
        var writtenAt: Date

        init(
            id: UUID = UUID(), speaker: Speaker, text: String,
            isComplete: Bool = true, evidenceIDs: [String] = [], writtenAt: Date = Date()
        ) {
            self.id = id
            self.speaker = speaker
            self.text = text
            self.isComplete = isComplete
            self.evidenceIDs = evidenceIDs
            self.writtenAt = writtenAt
        }
    }

    /// 사용자가 실제로 무엇을 말했는가 — 고민 원문과 이후 사용자 발언.
    var personSaid: [String] {
        [concern] + turns.filter { $0.speaker == .person }.map(\.text)
    }

    var counselorTurnCount: Int {
        turns.filter { $0.speaker == .counselor }.count
    }

    /// 모델이 아직 한 번도 답하지 않은 상담. 되묻기 단계다.
    var awaitsFirstAnswer: Bool { counselorTurnCount == 0 }

    /// 한 줄 요약 — 목록에 쓴다. 고민 원문의 첫 줄을 쓴다.
    /// 모델에게 제목을 짓게 하지 않는다. 제목을 위해 생성을 돌리는 것은
    /// 사용자가 주문하지 않은 일이다.
    var headline: String {
        let firstLine = concern
            .split(separator: "\n", maxSplits: 1)
            .first
            .map(String.init) ?? concern
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.count <= 42 ? trimmed : String(trimmed.prefix(41)) + "…"
    }
}
