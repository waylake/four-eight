import Foundation

/// 상담 입력의 안전 선별.
///
/// **모델에게 안전 판단을 맡기지 않는다.** 계산을 맡기지 않는 것과 같은
/// 이유다. 4B 모델은 위기 표현을 그럴듯하게 놓치고, 놓치면 "지금은 재성이
/// 흔들리는 국면입니다" 같은 답이 나간다. 그 실패는 조용하지 않다.
///
/// 그래서 순서를 뒤집었다. 사용자의 글은 **모델에 닿기 전에** 여기를
/// 통과한다. 위기 표현이 걸리면 앱은 모델을 부르지 않고, 고정된 안내를
/// 직접 보여준다. 생성이 없으므로 실패할 여지도 없다.
///
/// 판정은 여기서 하고 문구는 앱이 갖는다. 전화번호와 안내문은 나라와
/// 시점에 따라 바뀌는 UI 문자열이고, 이 엔진은 그것을 모른 채로 있어야
/// 한다. 출처는 docs/research/consultation-safety.md에 있다.
public enum SafetyScreen {
    public enum Verdict: Sendable, Equatable {
        /// 자해·자살·타해 표현. 모델을 부르지 않는다.
        case crisis(matched: [String])
        /// 의료·법률·투자 판단 요구. 답하기 전에 한계를 먼저 밝힌다.
        case outOfScope(matched: [String])
        case clear
    }

    /// 위기 표현.
    ///
    /// 한국어 관용 표현과 구분해야 한다. "힘들어 죽겠어요", "배고파 죽겠다"는
    /// 위기가 아니다. 그래서 `죽` 하나로 잡지 않고 표현 단위로 잡는다.
    /// 과하게 잡으면 상담이 매번 끊기고, 사용자는 앱을 닫는다.
    ///
    /// 놓치는 쪽과 과하게 잡는 쪽의 대가가 다르다는 것을 알고 고른 목록이다.
    /// 양쪽을 테스트로 고정했다 — `SafetyScreenTests`.
    ///
    /// 부분 문자열 검사는 한국어에서 **낱말 경계를 넘어 충돌한다.**
    /// 처음 목록에는 "목을 매"가 있었고, "이 종목을 매수해도 될까요"가
    /// 위기로 걸렸다. 투자 질문을 한 사용자에게 자살예방 상담 안내가 나가는
    /// 것은 오탐 중에서도 최악이다. 그래서 이 어구들은 뒤를 더 붙여
    /// 어미까지 고정한다. 이 케이스는 테스트에 남겨 두었다.
    static let crisisPhrases = [
        "죽고 싶", "죽고싶", "자살", "자해", "살기 싫", "살기싫",
        "사라지고 싶", "없어지고 싶", "다 끝내고 싶", "끝내버리고 싶",
        "목을 맬", "목을 매달", "목을 매려", "목을 맸",
        // "유서"만 두면 유서희·유서연 같은 이름에 걸린다.
        "손목을 그", "뛰어내리", "유서를 쓰", "유서를 남기", "유서 써",
        "약을 모으", "약을 모아",
        "죽어버리고", "죽는 게 낫", "죽는게 낫", "죽여버리고 싶",
    ]

    /// 이 앱이 답할 수 없는 종류의 요구.
    static let outOfScopePhrases = [
        "진단", "처방", "복용", "수술", "암인가", "병명",
        "고소", "소송", "합의금", "변호", "형량",
        "종목", "매수", "매도", "코인", "주식을 살", "상장",
    ]

    public static func evaluate(_ text: String) -> Verdict {
        let normalized = text.replacingOccurrences(of: " ", with: " ").lowercased()
        let crisis = crisisPhrases.filter { normalized.contains($0) }
        if !crisis.isEmpty { return .crisis(matched: crisis) }
        let scope = outOfScopePhrases.filter { normalized.contains($0) }
        if !scope.isEmpty { return .outOfScope(matched: scope) }
        return .clear
    }
}
