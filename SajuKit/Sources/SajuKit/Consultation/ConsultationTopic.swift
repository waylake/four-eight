import Foundation

/// 고민의 축.
///
/// 사용자가 적은 고민을 **명리의 축으로 옮기는 것**이 대화 기능의 첫 단계다.
/// 이 단계를 모델에게 맡기지 않는 이유는 계산을 맡기지 않는 이유와 같다.
/// 4B 모델은 "이직할까요"를 관성(官星)의 문제로 옮기는 일을 그럴듯하게
/// 틀리고, 틀리면 엉뚱한 근거로 답한다.
///
/// 고민의 축도 사주의 온톨로지처럼 닫혀 있다. 십신 10개가 사람이 겪는
/// 일의 범주를 이미 나눠 놓았기 때문이다. 그래서 벡터 검색이 아니라
/// 열거와 정확 매칭으로 충분하다 — ADR 0004와 같은 판단이다.
public enum ConsultationTopic: String, Sendable, Hashable, Identifiable, Codable, CaseIterable {
    case identity      // 나와 성향
    case career        // 일과 진로
    case wealth        // 돈과 재물
    case relationship  // 관계와 인연
    case study         // 배움과 자격
    case people        // 사람과 조직
    case expression    // 표현과 창작
    case wellbeing     // 몸과 마음의 기운
    case movement      // 이동과 거처
    case timing        // 지금 이 시기

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .identity: "나와 성향"
        case .career: "일과 진로"
        case .wealth: "돈과 재물"
        case .relationship: "관계와 인연"
        case .study: "배움과 자격"
        case .people: "사람과 조직"
        case .expression: "표현과 창작"
        case .wellbeing: "몸과 마음의 기운"
        case .movement: "이동과 거처"
        case .timing: "지금 이 시기"
        }
    }

    /// 이 주제를 어떤 명리 축으로 읽는가. 화면에 그대로 보여준다.
    /// 사용자가 "왜 이 근거가 나왔는지"를 알 수 있어야 한다.
    public var axis: String {
        switch self {
        case .identity: "일간 · 신강약"
        case .career: "관성 · 식상 · 신강약"
        case .wealth: "재성"
        case .relationship: "재성 · 관성 · 도화"
        case .study: "인성"
        case .people: "비견 · 겁재 · 천을귀인"
        case .expression: "식신 · 상관"
        case .wellbeing: "오행 균형 · 조후"
        case .movement: "역마 · 지지 충"
        case .timing: "대운 · 세운 · 월운 · 일진"
        }
    }

    /// 상담가가 되묻는 말.
    ///
    /// 명리 상담의 실제 형식은 질의응답이 아니다. 먼저 사정을 듣고, 그
    /// 다음에 명식에 비추어 되돌려준다. 이 문구를 모델이 만들게 하지 않는
    /// 이유는, 모델에게 맡기면 되묻는 대신 곧바로 판정하려 들기 때문이다.
    public var clarifier: String {
        switch self {
        case .identity:
            "어떤 상황에서 스스로가 낯설게 느껴지셨는지 한두 줄만 더 적어 주시면, 그 대목을 명식에 비추어 보겠습니다."
        case .career:
            "지금 자리에서 가장 걸리는 것이 일의 내용인지, 함께 일하는 사람인지, 아니면 앞으로의 방향인지 알려 주시면 근거를 좁혀 보겠습니다."
        case .wealth:
            "들어오는 쪽이 고민이신지 나가는 쪽이 고민이신지 짚어 주시면, 재성이 명식에서 어떻게 놓여 있는지와 함께 보겠습니다."
        case .relationship:
            "특정한 관계 하나가 고민이신지, 관계를 맺는 방식 자체가 고민이신지 알려 주시면 좋겠습니다."
        case .study:
            "배우려는 것이 자격이나 시험처럼 끝이 정해진 일인지, 오래 익혀야 하는 일인지 알려 주시면 인성을 그 결로 읽겠습니다."
        case .people:
            "부딪히는 상대가 대등한 위치인지, 위아래가 있는 관계인지 알려 주시면 비겁과 관성을 나누어 보겠습니다."
        case .expression:
            "만들고 계신 것을 혼자 하시는지 함께 하시는지 알려 주시면, 식신과 상관 중 어느 결에 가까운지 보겠습니다."
        case .wellbeing:
            "요즘 기운이 처지는 때가 하루 중 언제인지, 아니면 특정 계절마다 그러신지 알려 주시면 조후와 함께 보겠습니다."
        case .movement:
            "옮기는 것을 이미 결정하셨는지, 결정 전이신지 알려 주시면 좋겠습니다. 명식은 결정을 대신하지 않고 그 국면의 성격만 말해 줍니다."
        case .timing:
            "언제쯤을 두고 물으시는지 — 이번 달인지, 올해인지, 몇 년의 흐름인지 — 알려 주시면 그 층의 운을 보겠습니다."
        }
    }

    /// 이 주제를 읽을 때 쓰는 태그. 값이 nil이면 접두사 전체를 쓴다.
    ///
    /// 여기 없는 근거는 답변에 들어가지 않는다. 질문과 무관한 근거를
    /// 컨텍스트에 밀어 넣으면 4B 모델은 그것까지 답에 섞는다.
    var tagFilters: [(prefix: String, values: Set<String>?)] {
        switch self {
        case .identity:
            [("ilgan", nil), ("strength", nil)]
        case .career:
            [("sibsin", ["정관", "편관", "식신", "상관"]), ("strength", nil),
             ("daeun_sibsin", ["정관", "편관", "식신", "상관"])]
        case .wealth:
            [("sibsin", ["정재", "편재"]), ("daeun_sibsin", ["정재", "편재"]),
             ("sewoon_sibsin", ["정재", "편재"])]
        case .relationship:
            [("sibsin", ["정재", "편재", "정관", "편관"]), ("sinsal", ["도화", "공망"]),
             ("daeun_sibsin", ["정재", "편재", "정관", "편관"])]
        case .study:
            [("sibsin", ["정인", "편인"]), ("daeun_sibsin", ["정인", "편인"])]
        case .people:
            [("sibsin", ["비견", "겁재"]), ("sinsal", ["천을귀인"]),
             ("daeun_sibsin", ["비견", "겁재"])]
        case .expression:
            [("sibsin", ["식신", "상관"]), ("daeun_sibsin", ["식신", "상관"])]
        case .wellbeing:
            [("oheng_excess", nil), ("oheng_lack", nil), ("wolji", nil)]
        case .movement:
            [("sinsal", ["역마"]), ("iljin_rel", ["충"])]
        case .timing:
            [("daeun_sibsin", nil), ("sewoon_sibsin", nil),
             ("wolwoon_sibsin", nil), ("iljin_sibsin", nil), ("iljin_unseong", nil)]
        }
    }

    /// 고민 문장에서 찾는 말.
    ///
    /// 형태소 분석을 하지 않는다. 한국어에서 "이직할까요"는 "이직"을
    /// 부분 문자열로 포함하므로 어미 처리 없이 잡힌다. 못 잡는 문장이
    /// 있는 것은 인정하고, 그때는 사용자가 주제를 직접 고른다 —
    /// 틀린 주제로 답하는 것보다 모른다고 말하는 편이 낫다.
    var terms: [String] {
        switch self {
        case .identity:
            ["나는 어떤", "제 성격", "내 성격", "성향", "기질", "저는 어떤", "자존", "정체성", "타고난"]
        case .career:
            ["직장", "회사", "이직", "퇴사", "취업", "진로", "커리어", "승진", "직업",
             "일이 ", "업무", "상사", "사업", "창업", "면접", "구직", "부서", "계약직", "정규직"]
        case .wealth:
            ["돈", "재물", "재테크", "저축", "빚", "대출", "투자", "월급", "연봉",
             "수입", "지출", "금전", "재산", "생활비", "파산"]
        case .relationship:
            ["연애", "결혼", "이혼", "배우자", "남편", "아내", "애인", "남자친구", "여자친구",
             "짝", "인연", "소개팅", "썸", "헤어", "재혼", "궁합", "가족", "부모", "자녀", "아이"]
        case .study:
            ["공부", "시험", "자격", "학교", "대학", "입시", "유학", "논문", "학위",
             "배우", "수험", "합격", "고시", "전공"]
        case .people:
            ["동료", "친구", "사람들", "인간관계", "대인", "조직", "팀", "동업",
             "질투", "경쟁", "무리", "모임", "따돌", "갈등"]
        case .expression:
            ["글", "작품", "창작", "그림", "음악", "표현", "만들", "발표", "말하는",
             "콘텐츠", "디자인", "기획", "브랜드"]
        case .wellbeing:
            ["건강", "몸", "체력", "피로", "지치", "잠", "불면", "우울", "불안",
             "번아웃", "스트레스", "기운", "무기력", "소진"]
        case .movement:
            ["이사", "이동", "해외", "이민", "출장", "여행", "옮기", "거처", "집을",
             "전학", "전근", "떠나"]
        case .timing:
            ["언제", "시기", "올해", "내년", "이번 달", "요즘", "지금", "타이밍",
             "대운", "세운", "몇 년", "당장", "앞으로"]
        }
    }
}
