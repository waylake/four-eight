# 조사: 상담 화면의 사용성

조사일 2026-07-28. 대상은 `App/FourEight/Views/ConsultationView.swift`(913줄, 커밋
하나 — `4986dad`)입니다.

이 문서는 두 부분입니다. **1부는 사실**이고 [docs/research/](./README.md)의
규약을 따릅니다. **2부는 제안**이며 아직 결정이 아닙니다 — 채택되는 항목은
ADR로 승격하거나 커밋 메시지에 근거를 남깁니다. 섞어 두는 이유는 제안이
1부의 어느 측정에서 나왔는지 추적 가능해야 하기 때문이고, 대신 경계를
분명히 표시했습니다.

출발점은 사용자의 말입니다. "보기 불편하고 직관적으로 와닿지 않는다.
ChatGPT·Claude 웹처럼 직관적이고 간단했으면 좋겠다."

## 근거 등급

모든 사실 주장에 등급을 붙였습니다. 이 표기 없이 적힌 문장은 없습니다.

| 표기 | 뜻 |
|---|---|
| `[벤더]` | 제작사 문서·릴리스 노트·헬프센터 |
| `[실측]` | 이 저장소의 코드·스크린샷·벤치마크에서 직접 잰 것 |
| `[실측-웹]` | 배포된 HTML/CSS 또는 아카이브 문서에서 잰 것 |
| `[티어다운]` | 스크린샷을 붙인 제3자 분석 |
| `[3자주장]` | 근거 없는 블로그·의견 |
| `[미확인]` | 확인하지 못함 |

**조사 이력을 밝힙니다.** 리서치 에이전트 둘을 병렬로 돌렸고, macOS/HIG
담당은 **끝내 보고하지 않았습니다.** 그 영역은 직접 확인했습니다. HIG는 JS
렌더라 본문을 받을 수 없으므로
`https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<slug>.json`
에서 받아 문구를 대조했습니다. 웹 UI 담당은 보고했고, 그 결과가 초기 전제
하나를 뒤집었습니다(§2.1).

---

# 1부 — 사실

## 1. 렌더 결과 `[실측]`

배포용 스크린샷 `docs/assets/screenshot-consultation.png`(1180×760)을 직접
읽었습니다.

- **콘텐츠가 창 높이의 위쪽 약 40%에만 있고 아래 절반 이상이 빈 배경입니다.**
- **화면에서 가장 눌리게 생긴 요소 6개가 눌리지 않습니다.** `topicOverview`의
  축 칩(`ConsultationView.swift:265-277`)은 굵은 제목 + 채워진 캡슐인데
  `Button`이 아니라 `HStack`입니다.
- **같은 캡슐이 세 가지 뜻으로 쓰입니다.** 축 칩(비활성 라벨, `:265-277`) ·
  축 선택 칩(액션, `:237-252`) · 근거 칩(팝오버, `:597-613`)의 모양이 거의
  같습니다.
- 주 버튼 "상담 열기"가 텍스트 상자에서 멀리 떨어진 오른쪽 아래에 흐린
  disabled 상태로 있습니다(`:222-224`).
- **콘텐츠 아래 절반이 11~12pt 회색 잔글씨 4줄입니다** — "권하지 않습니다"
  문장(`:278-283`) + `groundingNote` 2줄(`:293-296`) + `AIDisclosure`(`:387`).

해석 화면(`screenshot-chart.png`)과 비교하면 **이 앱은 이미 "근거 있는
산문"을 그리는 문법을 갖고 있습니다** — 왼쪽 주사 세로선 + 제목 + 본문 +
하단 근거 칩(`InterpretationPanel.swift:283-371`). 상담 화면만 다른 것을
발명했습니다.

부수 관찰: 이 스크린샷의 사이드바 선택은 `오늘`인데 본문은 상담입니다.
`ScreenshotRunner`가 뷰를 직접 올리는 방식(`ScreenshotRunner.swift:89-96`)
때문이며 출하 버그는 아닙니다.

## 2. 행 길이 — WCAG의 CJK 상한을 넘습니다 `[실측]`

코드의 제약에서 계산합니다.

```swift
// ConsultationView.swift:522-543  transcript
.padding(18)                                 // 좌우 각 18
.frame(maxWidth: 760, alignment: .leading)   // 제약은 760

// ConsultationView.swift:864-893  TurnBubble .counselor
.padding(13)              // 좌우 각 13
.paperCard(padding: 13)   // PaperCard가 다시 좌우 각 13
.padding(.trailing, 40)   // 우측 40 들여쓰기
```

| 단계 | 폭 |
|---|---|
| `frame(maxWidth: 760)` | 760 |
| − `padding(18)` × 2 | 724 |
| − `padding(.trailing, 40)` | 684 |
| − `paperCard(padding: 13)` × 2 | 658 |
| − `padding(13)` × 2 | **632 = 풀이 본문 폭** |

`.font(.body)` = macOS 13pt이고 한글 음절은 전각이므로 자폭 ≈ 13pt.
**632 ÷ 13 ≈ 48.6 글리프/행.**

WCAG 2.2 SC 1.4.8의 상한은 "Width is no more than 80 characters or glyphs
(**40 if CJK**)"입니다 `[벤더]`. 근거는 "CJK characters are approximately
twice as wide as non-CJK characters […] so the maximum line width for CJK
characters is half that of non-CJK characters"입니다. **즉 약 21% 초과입니다.**

기본 창(1180pt, `FourEightApp.swift:31`)에서는 760이 걸리지 않습니다.
사이드바 236 + 목록 260 → 상세 ≈ 684 → 본문 ≈ 556pt ≈ **43 글리프**.
**좁은 창에서도 넓은 창에서도 넘습니다.** `concernCard`(`:619-632`)는 더
넓습니다 — 676pt ≈ **52 글리프**.

**목표값의 도출.** ChatGPT의 메시지 열은 아카이브된 SSR 문서에서 잰 값이
`--thread-content-max-width: 40rem`(640px), 넓은 컨테이너에서 `48rem`(768px)
입니다 `[실측-웹]`. 40rem을 이 앱의 본문 폰트로 환산하면 40em × 13pt =
**520pt**입니다. 그리고 한글 40 글리프 × 13pt = 520pt. 라틴 80자 × 약
0.5em × 13pt = 520pt. **세 계산이 같은 값으로 수렴합니다.**

앱 전체의 폭 정책은 지금 셋으로 갈립니다.

| 화면 | 코드 제약 | 코드 | 본문 → 글리프 |
|---|---|---|---|
| 오늘 | 없음 (padding 20만) | `TodayView.swift:22-30` | 창 폭 전체 → 50자 이상 |
| 상담 — 새 상담 | `maxWidth: 720` 중앙 | `:178-179` | 선언값 미도달 (아래) |
| 상담 — 상세 | `maxWidth: 760` **왼쪽** | `:543` | 632 → 48.6 |
| 명식 해석 패널 | `idealWidth: 400` | `ContentView.swift:47-48` | 약 350 → 약 27 |

새 상담 패널의 `.frame(maxWidth: 720, alignment: .leading)` +
`.frame(maxWidth: .infinity)` 조합(`:178-179`)은 스크린샷에서 약 530pt로
렌더됩니다 — **선언한 720에 도달하지 않습니다.** `TextEditor`는 폭에
탐욕적이므로 예상과 다르고, **원인을 규명하지 못했습니다** `[미확인]`.

행간은 이미 맞습니다. `.lineSpacing(4)` + 13pt ≈ 1.54배로 KRDS의 "줄 간격은
최소 150% 이상" `[벤더]`을 만족합니다. **한글 행장의 수치 규범은 KRDS에도
없고, 찾은 유일한 1차 규범은 위 WCAG의 40 글리프입니다.**

## 3. 한 화면의 어포던스 수 `[실측]`

**새 상담** (모델 미선택, 지난 상담 없음)

| 종류 | 수 |
|---|---|
| 조작 가능 (상세 패널 내부) | **2** — `TextEditor`, `상담 열기` |
| **버튼처럼 보이나 조작 불가** | **6** (축 칩) |
| 텍스트 블록 | 7 |

**상담 상세** (답변 1개, 모델 사용 가능)

| 종류 | 수 |
|---|---|
| 조작 가능 | 14~15 |
| 텍스트 블록 | 9 |
| **그릇(컨테이너) 문법** | **5** |

그릇 5종: `.quaternary` 카드(축 머리 `:615-616`, 앱 발언 `:847-849`) ·
`paperCard`(고민 `:631`, 풀이 `:892`) · 주사 말풍선(사용자 `:859-862`) ·
테두리 상자(입력 `:695-699`) · 회색 알림 박스(모델 힌트 `:680-681`).

특히 어긋나는 둘:

- **`paperCard`가 사용자의 말과 모델의 말 둘 다를 뜻합니다**(`:631`, `:892`).
- **사용자의 말이 두 모습입니다.** 최초 고민은 전폭 종이 카드, 이후 발언은
  우측 주사 말풍선(`:850-863`).

## 4. 첫 풀이까지 몇 번 누르는가 `[실측]`

모델이 이미 설치·선택된 상태에서 **클릭 5회, 그중 2회는 순수 포커스용**입니다.
`grep -rn "FocusState" App` 결과가 **0건** — 자동 포커스가 없습니다.

그리고 후속 입력 플레이스홀더가 "되물음에 답하거나 사정을 덧붙여
주세요"(`:686-688`)라고 말하므로 사용자는 **입력이 필수라고 읽습니다.**
실제로는 빈 상태로 `풀이 받기`를 눌러도 됩니다(`:740`이 빈 문자열을 허용).
**가장 중요한 다음 행동이 막혀 보입니다.**

## 5. 근거 머리가 스크롤과 경쟁합니다 `[실측]`

`transcript`(`:519-551`) 내부 순서는 `axisHeader` → `concernCard` → 발언들 →
`contextNote`. **근거 머리가 스크롤 컨테이너 맨 위에 있습니다.** 첫 진입에서는
CLAUDE.md §6-2를 만족하지만, **턴이 뷰포트를 넘어가는 순간(사실상 두 번째
답변부터) 근거는 화면에서 사라집니다.**

추측이 아닙니다. NN/g가 그 행동을 이름 붙여 측정했습니다 `[벤더]` —
**"apple picking"**: 사용자가 앞선 답변을 참조하려 손으로 복사하며
"**requiring excessive scrolling**", "**Users cannot hold all this
information in their working memory and must often scroll back up.**"
(2023-09, 8명, 90분 세션.)

## 6. 스트리밍 중 실제로 보이는 것 `[실측]`

```swift
// ConsultationView.swift:545-549
.onChange(of: consultation.turns.last?.text) {
    withAnimation(.easeOut(duration: 0.15)) {
        proxy.scrollTo("bottom", anchor: .bottom)
    }
}
```

1. **청크마다 애니메이션 스크롤이 새로 시작됩니다.** 토큰마다 0.15초
   easeOut → 흔들립니다.
2. **`"bottom"` 센티넬(`:540`)이 `contextNote`(`:539`) 아래에 있습니다.**
   뷰포트 하단에 고정되는 것은 자라는 풀이가 아니라 **고지 3줄**입니다.
   30초 동안 사용자가 보는 하단은 잔글씨입니다.

NN/g 10원칙 #7 `[벤더]`: "**Don't Autoscroll Users to the End of a
Response.** Maintain scroll position at the message start so users read
naturally." 스트리밍에서 특히 문제라고 명시합니다.

## 7. 컴포저 `[실측]`

- **버튼이 둘이고 어느 쪽도 강조되지 않습니다.** `적어만 두기`(`:728-735`)와
  `풀이 받기`(`:736-753`). 전자는 입력이 비면 사라지므로 **타이핑을 시작하면
  버튼이 늘어나 레이아웃이 움직입니다.** `.borderedProminent`도
  `.keyboardShortcut(.defaultAction)`도 없습니다.
- HIG Toolbars `[벤더]`: "Use the […] style for key actions such as Done or
  Submit. This separates and tints the action so there's a clear focal point.
  **Only specify one primary action, and put it on the trailing side.**"
- `풀이 받기`의 아이콘이 `wand.and.stars`(`:745`)입니다. NN/g 프롬프트 컨트롤
  4대 원칙의 첫 항목 `[벤더]`: "**Use labeled, standard icons** (not
  enigmatic symbols like **magic wands**)." 정확히 이 아이콘이 예시로
  지목됩니다.
- **스트리밍 중 입력 필드가 `.disabled`됩니다**(`:700`).
- `중단`(`:718-724`)에 단축키가 없습니다.
- `내보내기` 툴바 버튼(`:490-499`)에 대응하는 메뉴 명령이 없습니다.
  HIG Toolbars `[벤더]`: "**Make every toolbar item available as a command in
  the menu bar.** […] **it can't be the only place that presents a command.**"
- **재생성 어포던스가 없습니다.** 해석 화면에는 `새로 쓰기`
  (`InterpretationPanel.swift:205`)와 `AI 문장 버리기`(`:219-227`)가 있습니다.

## 8. 목록 `[실측]`

- **`List`에 selection 바인딩이 없습니다.** 선택은 `.onTapGesture`(`:121`),
  표시는 `.listRowBackground`에 직접 칠한 주사 8%(`:122-125`). 화살표 키 이동
  불가, 시스템 강조색 무시, 창 포커스에 반응하지 않음. HIG Split views
  `[벤더]`: "**To support navigation, persistently highlight the current
  selection in each pane that leads to the detail view.**"
- 검색 없음(`grep -rn "searchable" App` = 0건), 날짜 묶음 없음.
- 열을 접을 수 없습니다. HIG Split views `[벤더]`: "**Provide multiple ways to
  reveal hidden panes.** For example, you might provide a toolbar button or a
  menu command — **including a keyboard shortcut**."
- 정렬은 최신순(`ConsultationStore.swift:34-38`) — 이건 맞습니다.

## 9. 축 선택기 `[실측]`

이 화면에서 **결과를 가장 크게 바꾸는 조작**(축을 바꾸면 근거 전체가 바뀝니다)이
11pt 텍스트 + 8pt 시브론의 테두리 없는 메뉴입니다(`:556-574`). 옆의
`오늘 기운 함께` 토글은 `.controlSize(.mini)` + `caption2`(`:580-588`)입니다.

## 10. 코드에서 발견한 정합성 결함 5건 `[실측]`

**(a) 답변별 근거 칩이 배선돼 있으나 렌더되지 않습니다.**

`TurnBubble`은 `evidence: [Rule]`과 `onRule:`을 받습니다(`:831-832`).
호출부는 counselor 턴에 실제 값을 넘깁니다(`:527-530`).
**`body`(`:834-895`) 어디에서도 두 값을 쓰지 않습니다.**
`Consultation.Turn.evidenceIDs`(`Consultation.swift:57`)에는 "답변마다 근거
칩이 붙는 근거다"라는 주석이 있고 `ConsultationStore`가 값을 채워 디스크에
저장하지만(`ConsultationStore.swift:143-145`), 화면에 나오지 않습니다.

ADR 0010 §9의 제목은 "답변에 근거 칩이 붙는다"입니다. **붙지 않습니다.**

**(b) `retopic`이 답변과 인용을 어긋나게 만듭니다.**

`retopic`(`:758-763`)은 `consultation.evidenceIDs`를 통째로 갈아치웁니다
(`ConsultationStore.swift:108-114`). `ConsultationDetail.evidence`(`:478-481`)는
턴별이 아니라 **상담 수준의** `evidenceIDs`를 읽습니다. 답변을 받은 뒤 축을
바꾸면 머리의 근거는 **그 위의 답변이 쓰지 않은 규칙**이 됩니다.
`markdown()`(`:806-809`)도 같은 값을 씁니다.

ADR 0010은 "인용과 답이 어긋날 구조가 없다"고 적습니다. **구조가 하나 있고,
함수 호출 한 번입니다.**

**(c) 축 메뉴가 시간 근거를 빼고 계산합니다.**

`NewConsultationPane.availableTopics`(`:158-162`)는 `timeFacts`를 넘기지만,
`axisHeader`의 메뉴(`:557-562`)와 `retopic`(`:759-761`)은 넘기지 않습니다.

- `.timing`은 필터 5개 중 4개가 시간 태그(`ConsultationTopic.swift:117-119`)
  → 메뉴에서 고르면 근거가 **대운 하나로 축소**됩니다.
- `.movement`는 `sinsal:역마`(명식) + `iljin_rel:충`(시간)(`:115-116`) →
  역마가 없는 명식에서 오늘의 충으로 열린 상담은 **메뉴에 자기 자신이
  나타나지 않고**, 재선택하면 근거가 빕니다.
- `includesToday` 토글(`ConsultationStore.swift:116-120`)은 두 계산 어디에도
  반영되지 않습니다. 토글을 켜면 프롬프트의 `[오늘의 기운]` 블록은 늘어나는데
  **머리의 근거 칩은 그대로**입니다 — "이 상담이 쓰는 근거"라는 주장이 그
  순간 거짓이 됩니다.

**(d) 라벨이 사실과 다릅니다.**

`:280-282`는 "**이 명식에는** … 근거가 성립하지 않아 권하지 않습니다"입니다.
그런데 `availableTopics`는 `timeFacts = SajuService.fortune(on: Date(), …)`를
포함합니다(`:154-156`). **오늘 날짜에 따라 이 문장이 바뀝니다.** 명식 탓으로
적혀 있지만 원인의 일부는 오늘의 일진입니다.

**(e) 패딩이 두 번 적용됩니다.**

`.padding(13)` + `.paperCard(padding: 13)`(`:891-892`) = 좌우 각 26pt.
`concernCard`도 각 24pt(`:629-631`). `PaperCard`(`DesignSystem.swift:56-67`)는
이미 패딩을 적용합니다. 해석 화면은 하나만 씁니다
(`InterpretationPanel.swift:348`). **상담 화면만 이중 적용이며, 이것만
고쳐도 본문 폭 26pt를 회수합니다.**

## 11. 측정한 성능 `[실측]`

`SajuKit` 단독 벤치, Apple Silicon.

| 항목 | Release | Debug |
|---|---|---|
| `SolarTerms.instant(of: .ipchun,…)` | 0.045 ms | 0.411 ms |
| `SolarTerms.governingJeol(at:)` | 2.381 ms | 13.594 ms |
| `TimeFortune.month(containing:)` | 2.442 ms | 13.615 ms |
| `PillarsEngine.chart` | 4.061 ms | 24.470 ms |
| `ConsultationRouter.availableTopics` (명식만) | 0.082 ms | 0.223 ms |

`governingJeol`은 3년 × 절기 12개 = 36회 `instant()`를 캐시 없이 계산합니다.

`NewConsultationPane.timeFacts`(`:154-156`)는 캐시 없는 계산 프로퍼티이고
`availableTopics`가 이를 부르며, `topicOverview`(`:266`)에서 body마다 평가됩니다.
`concern`이 `@State`이므로 **한 글자 입력마다 `SajuService.fortune`이 최소
1회** 돕니다 — 구성 요소 합으로 Release ≥2.5 ms, Debug ≥14 ms
(`fortune` 자체는 직접 재지 않았습니다 `[미확인]`). `TodayView.fortune`
(`TodayView.swift:13-15`)도 같은 패턴입니다.

## 12. 웹 AI 채팅 UI가 실제로 하는 것

### 12.1 말풍선 연혁 — 초기 전제가 뒤집혔습니다

**ChatGPT는 말풍선을 없앤 적이 없습니다. 사용자 쪽에 추가했습니다.**

- `[실측-웹]` **2023년 중반 ChatGPT에는 양쪽 다 말풍선이 없었습니다.**
  아카이브된 공유 페이지: 사용자 턴 `group w-full … border-b
  border-black/10`, 어시스턴트 턴 `… bg-gray-50 dark:bg-[#444654]`.
  전폭 교차 음영 + 좌측 아바타 열(`w-[30px]`).
- `[티어다운]` **사용자 말풍선은 2024년 5월 개편에서 도입됐습니다.**
  2024-05-16 포럼 항의 스레드가 "모든 대화가 문자 메시지처럼 보인다"고 적고,
  롤아웃을 끄는 유저스크립트가 Statsig 게이트 `chatgpt_fruit_juice`를
  `false`로 강제합니다.
- `[티어다운]` 2024-07 CSS 티어다운: "In the original interface, **only the
  user's messages would have chat bubble styling**."
- `[실측-웹]` 현재 ChatGPT DOM에 `user-message-bubble-color` 클래스가 있습니다.
- `[3자주장]` 재구현 사양 기준 Claude.ai: 사용자 = `rounded-2xl`,
  `max-w-[80%]`, 우측 정렬 / 어시스턴트 = "**full-width plain serif, no
  bubble, no avatar**".
- `[티어다운]` Gemini는 답변을 전폭 인스레드 콘텐츠로, Perplexity는
  "**a small report, not a chat bubble**"로 렌더합니다.

**어긋나는 출처를 정리하지 않습니다.** 스크린샷 기반 티어다운들은 어시스턴트
답변도 여전히 "bubble"이라 부릅니다("Per-message actions stay below the
bubble"). 느슨한 동의어로 읽지만 **라이브 DOM을 직접 재지 않았으므로 해소하지
않습니다** `[미확인]`.

**벤더 근거는 없습니다** `[미확인]`. OpenAI도 Anthropic도 이 비대칭에 대한
공개 설명을 낸 적이 없습니다. 가장 가까운 것은 Anthropic 디자인 책임자의
팟캐스트 발언("chatbots as a series of bubbles back and forth between two
entities"에서 벗어나려 한다)뿐입니다 `[3자주장 — 벤더 직원, 문서 아님]`.

**함정 둘.** (1) 널리 인덱싱된 "Claude가 말풍선을 넘어 adaptive message
containers로"라는 페이지는 **Anthropic이 아니라 외부 디자이너의 비공식
컨셉**입니다. (2) ChatGPT·Claude가 "타임스탬프"를 보여준다는 비교 문서는
두 제품 어느 쪽도 하지 않는 일입니다.

### 12.2 재생성 — 두 벤더가 정반대로 갈렸습니다

"retry 버튼이 제거됐다"가 아닙니다. **"Try again"은 남았고, 제거된 것은
버전 선택기(좌우 화살표와 `1/2` 카운터)입니다.**

- `[티어다운]` 2026-02-19 최초 보고. 소급 적용되어 몇 년 전 대화의 화살표까지
  사라졌고, 내보내기에는 현재 보이는 버전만 담깁니다.
- `[3자주장 — OpenAI 지원팀 회신을 수신자가 인용]` "the version selector or
  arrow controls […] are **not available in the current ChatGPT web
  experience** for affected accounts. **This is expected behavior at this
  time.**"
- `[3자주장 — 포럼 모더레이터]` "it generates a new response but **replaces
  the previous one**."
- `[티어다운]` **대비: Claude의 "Try again"은 비파괴적이고 `1/N` 버전 표시가
  있습니다.**
- `[티어다운]` Gemini는 Regenerate가 있으나 **버전 내비게이션이 없습니다.**
- `[3자주장]` 디자인 문헌은 반대 방향을 권합니다 — 재생성된 응답은 "kept in a
  navigable carousel, **not overwritten silently**".

### 12.3 빈 상태

- `[벤더 — OpenAI 자체 문구]` 2023-08: "**Prompt examples**: A blank page can
  be intimidating. At the beginning of a new chat, you'll now see examples to
  help you get started."
- `[실측-웹]` **2026년 chatgpt.com SSR 문서에는 프롬프트 카드 마크업이
  없습니다.** 남은 것은 도구 칩(`Search`, `Study`, `Create image`)과
  플레이스홀더 `Ask anything`뿐입니다. **즉 예시 프롬프트는 사라졌고, 남은
  것은 프롬프트 제안이 아니라 도구 칩입니다.**
- `[실측-웹]` **Claude.ai는 문자열이 페이지에 실려 있어 가장 잘 문서화된
  사례입니다.** 회전 인사말(`Good morning`, `What are we working on today?` …),
  제안 범주 **`Write`, `Learn`, `Code`, `Life stuff`**, `Show more`,
  `Close suggestions`, 그리고 **사용자용 토글** `Chat suggestions enabled` /
  `Chat suggestions disabled`.
- `[3자주장 — 벤더 직원]` 그 칩은 **모델이 생성합니다** — Anthropic 디자인
  책임자가 "75 or 100" 프롬프트 반복 끝에 도달했다고 말합니다.
- `[벤더 — NN/g]` 10원칙 #4: "**Offer relevant suggested questions as
  buttons, not text.**"
- `[벤더 — NN/g, Response Outlining]` 사용자는 나쁜 답을 받은 **뒤에야** 형식을
  지정해야 함을 깨닫고, 게다가 "**some users may be unable to add specificity
  even if they wanted to, because they don't know the jargon needed.**"
  권고는 **GUI가 구조를 제안**하라는 것입니다.

### 12.4 인용을 실제로 누르는가

- `[벤더 — Pew, 1차]` AI 요약 **내부** 링크 클릭은 "**just 1% of all
  visits**". 요약을 본 방문에서 전통적 결과 클릭 8%, 안 본 경우 15%.
  미국 성인 900명, 2025-03, 검색 68,879건 중 요약 발생 12,593건.
- `[벤더 — NN/g, 다이어리 18명 425대화]` "**Only 22.43% of the conversations
  were followed up by a verification.**"
- `[벤더 — NN/g, 2026-02, 9명]` 참가자들은 "**which claims were supported by a
  named source**"를 구분하지 못했습니다. 권고: "**granular, per-claim source
  attribution rather than aggregate citations.**"
- `[벤더 — Tow Center, 1차]` 8엔진 × 200발췌. "incorrect answers to **more
  than 60 percent** of queries." Perplexity 37%, Grok-3 94%. "More than half
  of responses from Gemini and Grok 3 cited **fabricated or broken URLs**."
- `[3자주장 — Shape of AI]` "**Inline cues work for sentence-level claims.
  Panels or drawers work better for long-form exploration.**"

### 12.5 채팅 형식 자체에 대한 문헌 — 사용자 요청과 정면으로 관련

`[벤더 — NN/g, "Less Chat, More Answer", 9명 × 8개 챗봇]`

- "**users who land on your site with a question aren't looking for a
  conversation — they're looking for an answer.**"
- **아무도 "hello"라고 말하지 않았습니다.** 챗봇을 검색창처럼 다뤘습니다.
- 아첨을 싫어했습니다: "I view these as tools. **I don't need to be pandered
  to**".
- **불릿을 선호했습니다**: "**I love that they're bulleted, and it's not just
  like one big paragraph**"; 형식 없는 긴 문단에는 "overwhelmed"를 느꼈습니다.
- **스트리밍이 정보 과부하를 악화시켰습니다.**
- 권고는 역피라미드 대신 **절단 피라미드** — 본질만 먼저, 더 필요한 것은
  클릭 가능한 후속으로.

Smashing Magazine 3편은 **채팅 UI를 다듬는 글이 아니라 채팅에 반대하는
글입니다** `[벤더 급 매체, 필자 의견]`. Interaction Design Foundation은 이
주제에 가장 약합니다 — 챗봇 항목에 메시지 표시·컴포저 지침이 없습니다.

## 13. macOS 네이티브 규범 (HIG 원문 확인)

전부 `[벤더]`이며 JSON 엔드포인트에서 문구를 직접 대조했습니다.
`docs/research/consultation-references.md:64,75`에 "Apple HIG — Generative AI
/ Machine Learning: 본문 미확인"으로 남아 있던 구멍이 이걸로 메워집니다.

**Sidebars** — "**Avoid putting critical information or actions at the bottom
of a sidebar.** People often relocate a window in a way that hides its bottom
edge." → `Sidebar.swift:38-50`의 `새 인물`이 `safeAreaInset(edge: .bottom)`에
있습니다. / "In general, show no more than two levels of hierarchy […]
**consider using a split view interface that includes a content list**." /
"**Avoid hiding the sidebar by default.**" / **HIG에 macOS 사이드바 폭 수치는
없습니다.**

**Split views** — "**Provide multiple ways to reveal hidden panes** […]
**including a keyboard shortcut**." / "**Prefer the thin divider style.**" /
"**To support navigation, persistently highlight the current selection.**"

**Toolbars** — "**Make every toolbar item available as a command in the menu
bar.**" / "**Only specify one primary action, and put it on the trailing
side.**" / "**Minimize the number of groups** […] aim for a maximum of
three." / "**Don't title windows with your app name.**" →
`FourEightApp.swift:23`의 `Window("FourEight", id: "main")`.

**Layout** — "**Avoid placing controls or critical information at the bottom
of a window.**" 하단 고정 컴포저와 **진짜 긴장 관계**입니다. Messages와
Xcode는 그럼에도 하단에 둡니다. 실무 해석: 컴포저는 하단에 둘 수 있으나
**전송·중단은 메뉴 명령과 단축키로도 반드시 존재해야 합니다.** /
"**Make essential information easy to find by giving it sufficient space.**"
/ **HIG에 읽기 폭 수치는 없습니다.** `readableContentGuide`의 플랫폼 목록에
**macOS가 없습니다** — 직접 정해야 합니다.

**Machine learning — Apple이 "근거 칩"을 부르는 이름** — "**An attribution
expresses the underlying basis or rationale for a result, without explaining
exactly how a model works.**" / "**Keep attributions factual and based on
objective analysis.**" / "**If you're not sure how your confidence values
correlate with the quality of your results, it's not a good idea to convey
confidence to people.**" → **ADR 0007에 대한 HIG 수준의 지지입니다.**

**Generative AI — 이 화면에 가장 직접적** — "**Make it easy for people to
refine or revert generated results** […] **surfacing controls like Edit,
Undo, Retry, or Adjust near generated content** preserves people's agency." /
"**Consider giving specific, reassuring feedback during generation.** […]
instead of 'Processing…', say 'Finding substitutions for ingredients.'" /
"**Ensure a great experience even when generative features aren't available**
[…] **consider offering a non-AI fallback.**" → **CLAUDE.md §4와 ADR 0009를
Apple이 같은 말로 적습니다.** / "**consider offering curated suggestions that
make it easy to get started.**"

**출처끼리 어긋나는 지점** — Progress indicators는 "**Avoid labeling a
spinning progress indicator**"라고 하고, Generative AI는 구체적 진행 문구를
권합니다. 생성 화면에서는 후자가 우선이라고 읽었고, 앱의 "근거를 읽고
쓰는 중…"(`:869-871`)은 이미 후자를 만족합니다. **어긋남을 지우지 않고
적어 둡니다.**

**Inspectors** — **HIG에 `inspectors` 페이지가 없습니다**(JSON 404). 지침은
**Panels**에 있습니다.

**Keyboards** — **Return / ⌘Return 제출 규범이 없습니다.** 유일한 Return
언급은 문단 종결자로서입니다. **이 영역의 네이티브 규범은 HIG가 아니라
Messages·Xcode의 실제 동작뿐입니다.**

### 13.1 SwiftUI 제약 (배포 대상 macOS 15.0 — `project.yml:89`) `[벤더]`

| API | 도입 | 확인된 문구 |
|---|---|---|
| `TextEditor` | macOS 11 | 플레이스홀더 API 없음 |
| `onSubmit(of:_:)` | macOS 12.0 | "A `TextField`, or `SecureField` will trigger this action" — **`TextEditor`는 목록에 없음** |
| `defaultScrollAnchor(_:)` | macOS 14.0 | "**When the content size changes, it may consult the anchor** to know how to reposition" |
| `defaultScrollAnchor(_:for:)` | macOS 15.0 | 정렬 역할 분리 가능 |
| `inspector(isPresented:)` | macOS 14.0 | trailing 열 |
| `readableContentGuide` | — | **macOS 미지원** |

**Return 키의 실제 동작** `[3자주장, 2023-09-15]`: "This will however **not
work with a multiline text field**, since the primary return key will
**insert a new line** instead of submitting." **2023년 관찰이므로 macOS 26에서
재확인할 가치는 있으나, 이를 전제로 계획을 세우면 안 됩니다.**

### 13.2 Xcode 코딩 어시스턴트 — Apple 자신의 1차 사례 `[벤더]`

- "To submit a prompt that you type, **press Return** […] To stop Xcode from
  responding to a prompt, click the **Stop button the lower-right corner**."
  (원문 오타 포함)
- "**The placeholder text shows the current agent or model that Xcode is
  using.**"
- "**You can watch the progress in the transcript or do other tasks in the
  project window while you wait.**"
- "To undo changes […] click the **Undo Changes button**."
- "Enter your prompts in the message text field at the bottom of the
  transcript or **click one of the suggested prompts.**"

### 13.3 네이티브 Mac 앱이 웹 채팅과 다른 점

- `[3자주장]` Brent Simmons의 "**Mac-assed Mac apps**" — "not trying to wow us
  with all their custom not-Mac-like UI (**which often isn't very
  accessible**)".
- `[3자주장 — 실무 문서]` "**Menu and table items don't have a hover
  effect**", "app menus and lists **highlight the selected item**", 포인터
  커서는 "native desktop apps use it for one particular purpose: **links
  opening a page in a browser**".
- `[벤더]` Messages.app: 전송 **Return**, 줄바꿈 **Option-Return 또는
  Shift-Return**.
- **웹을 베끼면 손해나는 지점**: 사이드바 하단 액션 레일, 손으로 만든
  오버플로 메뉴, 커스텀 스크롤바, 창 제목에 앱 이름, 모든 것에 호버 하이라이트.
- `[미확인]` "네이티브 macOS AI 채팅 클라이언트 설계"에 관한 신뢰할 만한
  설계 문서를 찾지 못했습니다. Xcode 문서가 유일한 1차 대체물입니다.

## 14. 저장소에 이미 있는 조사와의 관계

`consultation-references.md`가 Pew 1%, Tow Center 60%, NN/g 3편, Google PAIR,
Microsoft HAX, Shape of AI를 담고 있습니다. 이 노트가 새로 추가하는 것:
NN/g 3편의 **본문 내용**(기존 노트는 한 건이 "—"), **Apple HIG Generative
AI / Machine Learning 본문**(기존 노트가 "미확인"으로 명시한 구멍),
**WCAG 1.4.8의 CJK 40 글리프**, **Xcode 코딩 어시스턴트라는 1차 Apple
사례**, **ChatGPT 말풍선 연혁의 실측 근거**.

---

# 2부 — 제안 (아직 결정이 아님)

## 15. 입장

### 15.1 가져올 것 (명료성의 문제 — 열린 채팅과 분리 가능)

입력창 자동 포커스 · 단축키를 화면에 표시 · 주 행동 하나 · 어시스턴트 전폭
평문 / 사용자 말풍선 · 조용한 스트리밍 · 생성 중에도 다음 입력 가능 · 답변
근처의 복사와 비파괴 다시 쓰기 · 목록 검색·날짜 묶음·접기.

### 15.2 버릴 것 (열린 채팅 또는 참여 최적화와 분리 불가)

모델이 짓는 스레드 제목(§11) · 관련 질문 캐러셀(Perplexity 티어다운 자신이
"composer를 아래로 밀어낸다"고 적습니다) · 메시지 편집 후 분기 · 무한 스레드
· 아첨·작별 인사·스트릭·알림(§6-3) · 길흉·점수·확신도(ADR 0007 + HIG) ·
**파괴적 재생성**(§11·§12-1).

분기에 대해 정확히 적습니다. **두 벤더 다 갖고 있습니다**(Claude 암묵,
ChatGPT 명시). 따라서 이 거부는 "아무도 안 한다"가 아니라 **이 앱의 기록
모델과 충돌한다는 제품 판단**입니다. 상담은 고쳐 쓰는 것이 아니라 남는
것입니다.

### 15.3 원칙이 실패를 변명하고 있는 네 지점

**(1) §6이 죽은 칩의 변명으로 쓰이고 있습니다.**

§6("모른다는 품질 기준")과 ADR 0010 §3은 **답할 수 없는 것을 권하지 말라**는
규칙입니다. "답할 수 있는 것도 누르지 못하게 하라"가 아닙니다.

앱은 이미 정직한 부분집합을 결정론적으로 계산합니다
(`ConsultationRouter.swift:76-84`). 그리고 그 결과를 **화면에서 가장 버튼처럼
그린 뒤 누를 수 없게** 만들었습니다. NN/g는 정반대를 말합니다 — "buttons,
**not text**". 지금은 **텍스트를 버튼처럼 그린** 최악의 조합입니다.

그리고 §5-1이 이미 답을 갖고 있습니다: "라우팅이 실패하면 **사용자가 직접
고릅니다.**" 그 컨트롤(`topicChooser`, `:229-256`)이 구현돼 있고 **실패한
뒤에만** 나타납니다. 실패를 기다릴 이유가 없습니다.

부가: Claude의 스타터 필은 **모델이 만듭니다.** 이 앱의 축 칩은 결정론적
라우터가 만들므로 §4·§6-1의 기준으로 **더 정직합니다.**

**(2) §7이 이 화면에는 적용되지 않았습니다.**

§7은 캘린더에서 실제로 적용됐습니다 — 28일의 점을 13일로 줄였습니다. 상담
화면에서는 한 번도 적용되지 않았습니다. **커밋이 하나입니다**(`4986dad`).
렌더된 결과를 보고 고친 적이 없습니다. 원칙의 부재가 아니라 원칙의 미적용입니다.

**(3) §6-2는 "스크롤 맨 위"로 구현되어 있고, 그건 6-2가 반대하는 것입니다.**

§6-2의 근거는 Pew의 1% — **눈앞에 없는 것은 읽히지 않는다**는 값입니다. 지금
근거 머리는 두 번째 턴부터 눈앞에 없습니다. 근거를 **고정**하는 것은 6-2를
약화시키는 것이 아니라 6-2의 첫 정직한 구현입니다.

여기에 §10(b)가 겹칩니다. ADR 0010이 자랑하는 "인용과 답이 어긋날 구조가
없다"는 현재 **사실이 아닙니다.**

**(4) §8이 잔글씨 세 겹의 변명으로 쓰이고 있습니다.**

같은 내용을 11pt 회색으로 세 군데 적는 것은 보여주는 것이 아니라 채우는
것입니다. 그리고 **가장 정체성에 가까운 표시(답변별 근거 칩)는 배선만 되고
렌더되지 않습니다.** 화면은 자기 정직성에 대해 장황하고 자기 인용에 대해
침묵합니다.

**(5) 구분해야 할 것 — §6-3은 이 목록에 없습니다.**

§6-3(이탈 방지 장치를 만들지 않는다)은 옳고 건드리지 않습니다. 다만
**"복귀를 유도하지 않는다"와 "첫 방문을 어렵게 한다"는 다릅니다.** 자동
포커스 부재, 보이지 않는 단축키, 동등한 무게의 버튼 둘은 반참여 설계가
아니라 그냥 마찰입니다.

### 15.4 사용자 요청에 대한 답

"ChatGPT처럼"에 대한 답은 **"ChatGPT의 기계는 가져오되 형태는 가져오지
않는다"**입니다. 근거는 취향이 아니라 NN/g의 조사입니다 — 채팅 형태 자체가
문제이고 권고는 "본질만 먼저, 나머지는 클릭 가능한 후속"입니다. 이 앱은 이미
그 형태에 가깝습니다. 부족한 것은 그 형태를 **읽을 수 있게 그린 것**입니다.

## 16. 제안 목록

### P1. 포커스 · 키보드 · 주 행동 하나 — 약 60줄

1. `@FocusState` + `.defaultFocus(_:true)`를 `NewConsultationPane`의
   `TextEditor`(`:196`)와 후속 `TextField`(`:685-690`) 양쪽에.
2. `풀이 받기`(`:736-753`)를 유일한 주 버튼으로 `.borderedProminent`.
   `적어만 두기`(`:728-735`)는 `⋯` 메뉴로 내려 **타이핑 중 버튼이 늘어나는
   현상을 없앱니다.**
3. **단축키를 라벨에 표시합니다** — `풀이 받기 ⌘↩`. **순정 Return 전송은
   시도하지 마십시오**: `onSubmit`은 `TextField`/`SecureField`만 발화하고
   멀티라인에서는 Return이 줄바꿈으로 소비됩니다(§13.1). `NSTextView` 래퍼는
   약 200줄 + 한글 IME 조합 확정과 Return이 충돌할 위험이 있어 **값이
   없다고 봅니다.** 실제 실패는 단축키가 없는 것이 아니라 **숨어 있는
   것**입니다.
4. `wand.and.stars`(`:745`) 제거 — NN/g가 예시로 지목한 아이콘입니다.
5. 메뉴 명령 추가: `새 상담 ⇧⌘N`, `풀이 받기 ⌘↩`, `생성 중단 ⌘.`,
   `상담 내보내기…`, `상담 목록 보기/숨기기`.

**§12-3에 저촉되지 않습니다.** `Button` 액션에서만 생성이 시작되는 구조가
유지되고 `scripts/check_generation_policy.sh`가 검사하는 경로를 건드리지
않습니다.

### P2. 스트리밍 스크롤과 하단 군더더기 — 약 20줄, 순감

1. `ScrollViewReader` + `scrollTo` + 센티넬을 모두 제거하고
   `.defaultScrollAnchor(.bottom)`(macOS 14+). 필요하면
   `.defaultScrollAnchor(.topLeading, for: .alignment)`(macOS 15+)를 함께.
2. `contextNote`(`:634-647`)를 **스크롤 밖으로** 내려 컴포저 위 한 줄로.
   기록의 마지막 요소가 항상 답변이 됩니다.
3. 애니메이션 제거.

### P3. 축 칩을 살아 있는 컨트롤로 — 약 50줄

1. `topicOverview`(`:258-285`)와 `topicChooser`(`:229-256`)를 하나로 합치고
   칩을 **항상 `Button`**으로. 누르면 `chosenTopic`이 정해지고 편집기로
   포커스가 갑니다. **상담을 바로 열지는 않습니다** — 고민 원문은 여전히
   사용자의 말이어야 합니다(`Consultation.swift:29`).
2. 칩 라벨은 제목만, 축 문자열은 `.help`로.
3. "권하지 않습니다"(`:278-283`)를 접힌 `DisclosureGroup`으로 내리고 문구를
   사실에 맞게 — "이 명식에는" → "지금 이 명식과 오늘의 기운으로는"(§10-d).
4. **캡슐 문법 세 개를 분리합니다**: 축 칩 = 채워진 캡슐 + 선택 상태 /
   근거 칩 = `text.magnifyingglass` + 외곽선 / 비활성 라벨 = 캡슐 없음.
5. 가용 축이 0개면 `ContentUnavailableView`
   (`InterpretationPanel.swift:82-86`의 선례).

### P4. 폭 토큰 하나 + 수직 중앙 + 이중 패딩 제거 — 약 40줄

1. `DesignSystem.swift`에 토큰:
   ```swift
   /// 읽기 열의 최대 폭. 좌우 패딩 18을 포함한다.
   /// 본문 524pt ≈ 한글 40 글리프 = WCAG 1.4.8의 CJK 상한.
   /// ChatGPT의 실측 40rem을 이 앱의 본문 13pt로 환산한 값과 같다.
   enum Measure { static let reading: CGFloat = 560 }
   ```
2. 상세(`:543`)를 `Measure.reading` + 중앙 정렬로. **컴포저도 같은 폭.**
3. **이중 패딩 제거**(`:891-892`, `:629-631`). 해석 화면은 이미 하나만 씁니다.
4. 새 상담(`:165`)을 `VStack` + `Spacer()`로 수직 중앙 정렬.
5. **덤**: `TodayView.swift:22-30`에도 적용 — CJK 상한을 가장 크게 넘는 화면입니다.
6. 확정 전에 `scripts/shots.sh`로 렌더해 **한 행의 글자수를 실제로
   세십시오** — 자폭은 폰트 의존입니다(§18).

### P5. 답변 렌더링 · 죽은 근거 칩 살리기 · 비파괴 재생성 — 약 130줄

1. counselor 턴의 `paperCard`와 `.padding(.trailing, 40)`(`:891-893`)을
   제거하고 **전폭 평문 + `SectionCard` 문법**
   (`InterpretationPanel.swift:283-371`)으로. 왼쪽 주사 세로선 + `풀이` 제목
   + 본문 + **하단 근거 칩**.
2. **`TurnBubble`의 죽은 배선을 살립니다.** `evidence`/`onRule`(`:831-832`)을
   렌더하고 **턴의 `evidenceIDs`를 씁니다** — 상담 수준(`:478-481`)이
   아니라. 이것으로 §10(b)가 **구조 수준에서** 닫힙니다.
   - **한계를 정직하게 적습니다**: 이 앱은 문장 단위 귀속을 할 수 없습니다 —
     모델이 규칙 N개를 받아 산문을 씁니다. **답변 단위가 정직하게 도달할 수
     있는 최소 입자**이고, 그것이 지금 렌더되지 않습니다.
3. `concernCard`(`:619-632`)를 사용자 발언과 같은 문법으로. 사용자의 말은
   한 모습이어야 합니다.
4. app 턴(`:836-849`)은 채워진 카드 대신 아이콘 + 평문 + 왼쪽 얇은 선.
5. 답변 하단에 **복사**와 **다시 쓰기**. HIG Generative AI가 요구하고
   Xcode에도 Undo Changes가 있습니다.
   - **`다시 쓰기`는 덮어쓰지 않아야 합니다.** ChatGPT는 대체하고 Claude는
     `1/N`로 보존합니다. **이 앱은 Claude 쪽이어야 합니다** — §11과 §12-1이
     그렇게 요구합니다. `ConsultationStore.regenerateLast(id:supplier:)`가
     **새 턴을 append**하고 이전 턴을 남깁니다.
6. `markdown()`(`:806-809`)도 턴별 `evidenceIDs`를 쓰도록.

**ADR 0010 §9를 처음으로 실제 구현합니다.**

### P6. 근거 머리를 고정 — 약 70줄

1. `axisHeader`(`:553-617`)를 `ScrollView` 밖으로 빼서
   `.safeAreaInset(edge: .top)`, 배경 `.bar`.
2. 두 줄로 압축. 칩이 넘치면 **`+N`**으로 접습니다.
3. **인스펙터(4열)는 쓰지 않습니다.** HIG에 `inspectors` 페이지가 없고,
   창은 이미 3열이며 최소 폭이 1000pt(`FourEightApp.swift:29`)입니다.
   §6-2는 근거가 **답 앞**에 있으라고 요구하므로 상단 고정이 더 문자
   그대로입니다.

### P7. 컴포저 정리와 고지 한 줄 — 약 90줄, 상당 순감

1. 알림 블록 둘(`:654-682`)을 한 줄 배너로 통합, 우선순위는 모델 없음 > 긴 상담.
2. **스트리밍 중 `.disabled`(`:700`)를 제거합니다.** Xcode: "do other tasks
   […] while you wait." Nielsen: 10초를 넘으면 사용자는 다른 일을 하려 합니다.
3. `중단`에 `⌘.` + 메뉴 명령.
4. **`contextNote` + `AIDisclosure`를 컴포저 아래 한 줄로.** 항상 보이므로
   ADR 0010 §7(EU AI Act Art 50(1), Utah 13-72a-203)을 그대로 만족합니다.
   `CounselBrief.recentTurnWindow`를 계속 참조해 숫자가 코드와 어긋나지
   않게 둡니다.
5. **플레이스홀더에 모델 이름을 넣습니다** — Xcode의 방식.

### P8. 축 메뉴와 정합성 버그 — 약 70줄 + 테스트

1. 메뉴를 테두리 있는 `Menu` + `.small`로. 토글도 `.mini` → `.small`.
2. **`axisHeader`의 메뉴와 `retopic`에 `timeFacts`를 넘깁니다**(§10-c).
   `includesToday`를 반영합니다.
3. 답변이 있는 상담에서 축을 바꿀 때 "이후 풀이에만 적용됩니다"를 표시.
4. **테스트를 함께 넣습니다** — "retopic 후 이전 턴의 `evidenceIDs`가
   보존된다", "메뉴의 `availableTopics`가 현재 `topic`을 포함한다",
   "`includesToday`를 켜면 evidence가 시간 근거를 포함한다".
   §12-3에 따라 **먼저 깨지는 것을 확인한 뒤** 커밋하십시오.

### P9. 목록 — 약 130줄

1. `List(selection:)`으로 전환, `.onTapGesture`·`.listRowBackground` 제거.
2. `.searchable`로 고민 원문 검색.
3. **날짜 묶음은 얕게** — `오늘 / 어제 / 이전` 3단. **ChatGPT의
   "Previous 7 Days"는 벤더 문서로 확인되지 않았고, Claude의 문자열
   번들에는 `Today`·`Yesterday`뿐입니다.** 더 만드는 것은 근거 없는
   모방입니다.
4. 행을 한 줄로. `풀이 전`과 서명 불일치 경고는 유지합니다 — §8.
5. **목록 접기**: 툴바 버튼 + 메뉴 명령 + 단축키.
6. **`HSplitView`를 3열 `NavigationSplitView`로 바꾸지 마십시오.** 열 구성이
   인스턴스마다 고정이므로 오늘·캘린더·명식에서 빈 중간 열이 생기고,
   목적지마다 다른 인스턴스를 쓰면 뷰 식별자가 바뀌어 사이드바가
   재생성됩니다. HIG가 요구하는 것은 "content list를 둔 split view"이고
   `HSplitView`가 이미 그것입니다 — 빠진 것은 접기·선택·얇은 구분선뿐입니다.

### P10. 첫 상담 직후의 레이아웃 점프 — 비용 없음

`hasHistory`(`:21-23`)가 false → true로 넘어가는 순간 260pt 열이 생겨 상세가
줄어듭니다. **P4·P9를 하면 추가 비용 없이 해결됩니다** — 본문 폭이
`Measure.reading`으로 고정되므로 열이 나타나도 읽는 열의 폭이 변하지 않습니다.

### P11. `DayFortune` 메모이즈 — 약 25줄

`AppState`에 `readingCache`(`AppState.swift:76-85`)와 같은 방식의 캐시를 두고
`NewConsultationPane.timeFacts`, `TodayView.fortune`,
`ConsultationDetail`이 그것을 씁니다. 키는 `personID | options | 날짜(일)`.

§11의 정신 — 계산은 공짜지만 **VSOP87 급수를 키 입력마다 40회 도는 것은
공짜가 아닙니다.**

## 17. 순위 — (사용자 체감 개선 / 구현 비용)

| 순위 | 제안 | 체감 | 비용 | 위험 |
|---|---|---|---|---|
| **1** | P1 포커스·단축키·주 행동 하나 | 큼 | 아주 작음 (60줄) | 낮음 |
| **2** | P2 스트리밍 스크롤·하단 정리 | 큼 | 아주 작음 (20줄, 순감) | 낮음 |
| **3** | P4 폭 560pt·수직 중앙·이중 패딩 | 큼 | 작음 (40줄) | 낮음 |
| **4** | P3 축 칩을 버튼으로 | 큼 | 작음 (50줄) | 낮음 |
| **5** | P5 답변 렌더링·근거 칩·비파괴 재생성 | 큼 | 중간 (130줄) | 낮음 |
| **6** | P6 근거 머리 고정 | 중간~큼 | 중간 (70줄) | 중간 |
| **7** | P7 컴포저·고지 정리 | 중간 | 중간 (90줄, 순감) | 중간 |
| **8** | P8 축 메뉴 + 정합성 버그 | 중간 (정확성) | 중간 (70줄+테스트) | 낮음 |
| **9** | P9 목록 | 중간 | 중간~큼 (130줄) | 중간 |
| **10** | P11 메모이즈 | 작음 | 아주 작음 (25줄) | 낮음 |
| **11** | P10 첫 전환 | 작음 | 없음 (흡수) | 낮음 |

**1~4번만 해도 사용자 불만의 대부분이 해소된다고 봅니다.** 합계 약 170줄이고
상당 부분이 코드 삭제·이동입니다.

## 18. 열린 결정 — 소유자의 판단이 필요합니다

**불릿이냐 산문이냐. 해소하지 않고 넘깁니다.**

- `[벤더 — NN/g, 9명 × 8개 챗봇]` 참가자들은 불릿을 선호했고, 형식 없는 긴
  문단에 "overwhelmed"를 느꼈으며, **스트리밍이 그 과부하를 악화시켰습니다.**
- **현재 앱은 정반대를 지시합니다.** `CounselBrief.instructions`:
  "2~3문단, 각 문단 2~4문장. **제목이나 목록 없이 본문만 씁니다.**"

**ADR 0007과의 트레이드오프.** 불릿으로 쪼개면 **항목 하나가 판정처럼
읽힙니다.** "관성이 강하다 / 식상이 약하다 / 신강하다"가 목록이 되면 각 줄이
점수표의 행처럼 보이고, 사용자는 근거가 아니라 항목 수를 셉니다. §2와 ADR
0007이 막으려는 실패 양식과 같은 종류입니다. 또한 지시문의 다른 조항들
("미래를 단정하지 않습니다", "~한 편입니다")은 산문에서 훨씬 자연스럽고,
불릿은 단정형으로 수렴하는 압력을 만듭니다.

**권고 — 권고로서만.** 지시문을 바꾸지 말고 P5의 `SectionCard` 문법으로
**시각적 구조**를 주는 것. 문장은 산문으로 두고 그릇에서 스캔 가능성을
얻습니다. Perplexity가 답변을 "a small report"로 다루면서도 산문을 유지하는
것과 같은 층위입니다.

**다만 이 권고에는 검증되지 않은 가정이 있습니다** — "그릇의 구조가 문장의
구조를 대체할 수 있다"는 것이 NN/g의 발견으로 뒷받침되지는 않습니다. NN/g가
잰 것은 텍스트 형식입니다.

**불릿을 도입한다면** `CONTRIBUTING.md`의 톤 규약 테스트가 무엇을 잡는지
먼저 보십시오. §24의 교훈이 반대 방향으로도 성립합니다 — 목록을 허용하면
판정 표현 검사가 놓치는 구멍이 생길 수 있습니다.

## 19. 확정 전에 실기로 확인할 것

1. `Measure.reading = 560` 적용 후 `scripts/shots.sh`로 렌더해 **한 행의
   한글 글자수를 실제로 세십시오.**
2. `:178-179`의 이중 `frame`이 왜 선언값 720에 도달하지 않는지.
3. `.defaultScrollAnchor(.bottom)`이 `safeAreaInset` 컴포저와 함께 동작하는지.
4. `onSubmit`이 macOS 15/26의 멀티라인 필드에서도 발화하지 않는지.
5. **답변이 있는 상태의 상담 스크린샷을 만드십시오.** 지금 배포용 이미지는
   빈 폼뿐입니다 — 이 기능의 대표 이미지에 답이 없다는 사실 자체가
   신호입니다(§18).

---

## 미확인 — 정리하지 말고 그대로 둘 것

1. **OpenAI도 Anthropic도 말풍선 비대칭에 대한 공개 설명을 낸 적이 없습니다.**
2. **2024년 5월 ChatGPT 사용자 말풍선 도입은 티어다운 등급입니다**(2023년
   무말풍선은 실측). 아카이브가 2022-11~2024-02 구간을 못 줍니다.
3. **티어다운들은 어시스턴트 답변도 "bubble"이라 부릅니다.** 라이브 DOM을
   직접 재지 않았으므로 해소하지 않습니다.
4. **두 벤더 모두 웹 앱 키보드 단축키 문서가 없습니다.** Claude의 단축키는
   출처마다 세 갈래로 어긋납니다.
5. **Claude.ai의 메시지 열 폭은 유저스크립트 선택자에서 추정한 768px일 뿐
   실측이 아닙니다.** Perplexity·Gemini·Poe는 실측값이 전혀 없습니다.
6. **Claude.ai가 인라인 인용을 첨자 숫자로 그리는지 파비콘 필로 그리는지
   미확인.** 벤더 스크린샷도 없습니다.
7. **ChatGPT의 날짜 묶음과 자동 제목 생성은 벤더 문서 근거가 없습니다.**
8. **Baymard의 "80자 초과 시 41% 더 자주 건너뛴다"는 Baymard 원문에
   없습니다.** 확인되지 않은 2차 부풀림입니다.
9. **NN/g의 대표 읽기 논문에는 행장 지침이 없습니다.**
10. **한글 행장의 수치 규범은 KRDS에 없습니다.** 유일한 1차 규범은 WCAG의
    CJK 40 글리프입니다.
11. **HIG에는 macOS 사이드바 폭, 읽기 폭, 텍스트 입력 맥락의 Return 규범이
    없습니다.** `readableContentGuide`에 macOS가 없습니다.
12. **HIG에 `inspectors` 페이지가 없습니다**(지침은 Panels).
13. **HIG Progress indicators와 HIG Generative AI가 스피너 라벨에 대해 서로
    어긋납니다.** 후자를 택했고 어긋남을 남겨 둡니다.
14. **`ConsultationView.swift:178-179`가 선언값 720에 도달하지 않는 원인**을
    규명하지 못했습니다.
15. **`SajuService.fortune` 자체를 직접 재지 않았습니다** — 구성 요소
    측정에서 추정한 값입니다.
16. **Poe는 조사가 얇습니다.** 검증된 티어다운이 없고 인용 UI 근거가
    전무합니다.
17. **Claude가 중단 시 부분 출력을 보존하는지** 미확인.
18. **네이티브 macOS AI 채팅 클라이언트 설계에 관한 신뢰할 만한 문서를 찾지
    못했습니다.** Xcode 문서가 유일한 1차 대체물입니다.
19. **macOS/HIG 리서치 에이전트는 보고하지 않았습니다.** 해당 영역은 직접
    확인했고 등급 표기가 그 결과를 반영합니다.

## 출처

**UX 연구 (벤더 급)** — NN/g: [Less Chat, More
Answer](https://www.nngroup.com/articles/less-chat-more-answer/) ·
[10 Guidelines for AI
Chatbots](https://www.nngroup.com/articles/ai-chatbots-design-guidelines/) ·
[Prompt Controls](https://www.nngroup.com/articles/prompt-controls-genai/) ·
[Accordion Editing and Apple
Picking](https://www.nngroup.com/articles/accordion-editing-apple-picking/) ·
[Response Outlining](https://www.nngroup.com/articles/response-outlining/) ·
[AI Search and
Info-Seeking](https://www.nngroup.com/articles/ai-search-infoseeking/) ·
[Generative-AI Diary
Study](https://www.nngroup.com/articles/generative-ai-diary/) ·
[Response Times](https://www.nngroup.com/articles/response-times-3-important-limits/)
· [Progress Indicators](https://www.nngroup.com/articles/progress-indicators/)
· [How People Read Online](https://www.nngroup.com/articles/how-people-read-online/)

**1차 조사** —
[Pew (2025-07-22)](https://www.pewresearch.org/short-reads/2025/07/22/google-users-are-less-likely-to-click-on-links-when-an-ai-summary-appears-in-the-results/)
·
[Tow Center / CJR (2025-03-06)](https://www.cjr.org/tow_center/we-compared-eight-ai-search-engines-theyre-all-bad-at-citing-news.php)

**접근성·타이포그래피** —
[WCAG 2.2 SC 1.4.8 (CJK 40 글리프)](https://www.w3.org/WAI/WCAG22/Understanding/visual-presentation.html)
· [Baymard, Line Length](https://baymard.com/blog/line-length-readability) ·
[Butterick, Line length](https://practicaltypography.com/line-length.html) ·
[KRDS 타이포그래피](https://www.krds.go.kr/html/site/style/style_03.html) ·
[W3C, Requirements for Hangul Text Layout](https://www.w3.org/TR/klreq/)

**Apple** — HIG(Sidebars · Split views · Toolbars · Layout · Panels ·
Machine learning · Generative AI · Keyboards · Progress indicators)는
`https://developer.apple.com/design/human-interface-guidelines/<slug>`,
본문은 `tutorials/data/design/...json`에서 대조 ·
[Writing code with intelligence in
Xcode](https://developer.apple.com/documentation/xcode/writing-code-with-intelligence-in-xcode)
·
[Messages Mac 단축키](https://support.apple.com/guide/messages/keyboard-shortcuts-ichtc78b3bff/mac)

**제품 벤더** —
[OpenAI release notes](https://help.openai.com/en/articles/6825453-chatgpt-release-notes)
·
[ChatGPT search 인용 UI](https://help.openai.com/en/articles/9237897-chatgpt-search)
· [Anthropic Web search](https://www.anthropic.com/news/web-search) ·
[Artifacts / 편집 시 분기](https://support.claude.com/en/articles/9487310-what-are-artifacts-and-how-do-i-use-them)
· [Gemini 출처](https://support.google.com/gemini/answer/14143489?hl=en)

**실측-웹** —
[chatgpt.com SSR 2026-01-01](https://web.archive.org/web/20260101031839id_/https://chatgpt.com/)
·
[claude.ai 문자열 번들](https://web.archive.org/web/20260101023256id_/https://claude.ai/)
·
[ChatGPT 공유 페이지 2023-06-11](https://web.archive.org/web/20230611174728id_/https://chat.openai.com/share/00194a37-f44e-4bcb-9d0c-96bd659d2e0e)

**티어다운·의견** — [AI UX Playground](https://aiuxplayground.com/teardowns/)
·
[ChatGPT 2024 개편 항의](https://community.openai.com/t/openais-chatgpt-design-changes-are-infuriating/758560)
·
[버전 선택기 제거 2026-02](https://community.openai.com/t/chatgpt-web-update-removed-message-version-arrows-cannot-access-edited-message-history/1374666)
· [Shape of AI, Citations](https://www.shapeof.ai/patterns/citations) ·
[Setproduct](https://www.setproduct.com/blog/ai-chat-interface-ui-design) ·
[inessential, Mac-assed Mac apps](https://inessential.com/2020/03/19/proxyman.html)
·
[Daniel Saidi, 멀티라인 필드와 Return](https://danielsaidi.com/blog/2023/09/15/dismissing-a-multiline-textfield-with-the-return-key-in-swiftui)

---

# 3부 — 2026-07-29 보강

1·2부는 첫 개선(`8bc2c09`)의 근거였습니다. 여기부터는 **"ChatGPT·Claude
웹처럼 간단하고 깔끔하게, 그리고 계속 대화하고 싶게"**라는 두 번째 요청을
받고 다시 조사한 것입니다. 앞의 판단 하나를 뒤집으므로 지우지 않고 덧붙입니다.

## 20. 뒤집은 판단 — P1.3 "Return 전송은 시도하지 마십시오"

1부 §16 P1.3은 순정 Return 전송을 권하지 않았습니다. 근거는 둘이었습니다.
`onSubmit`이 멀티라인에서 발화하지 않는다(**여전히 사실입니다**), 그리고
`NSTextView` 래퍼는 "약 200줄 + 한글 IME 조합 확정과 Return이 충돌할 위험"이
있어 값이 없다.

두 번째가 틀렸습니다. 조사와 실측은 [chat-composer.md](./chat-composer.md)에
있고 요지는 이렇습니다.

- **가로채는 자리가 입력기 뒤입니다.** Apple의 Cocoa Text Architecture Guide가
  `keyDown:` → 입력 컨텍스트 → `insertText:`/`doCommandBySelector:` 순서를
  명시합니다. "마지막 글자가 사라지는" 사고는 `keyDown` 시점에 값을 읽는
  코드에서 납니다.
- **`hasMarkedText()`라는 표준 가드가 있습니다.**
- **실기로 9건을 확인했습니다.** 조합 중 Return이 전송으로 해석되지 않는 것을
  포함합니다.
- **실기로 확인하지 못한 것도 남았습니다** — 실제 한글 입력기가 조합 중
  Return을 삼키는지. 세 가능성 중 최악이 "Return을 한 번 더 눌러야 한다"이고,
  어느 경우에도 글자를 잃지 않습니다.

그리고 **부수 소득이 하나 있었습니다.** `insertLineBreak:`의 기본 구현은
U+2028을 넣습니다. 이 저장소가 SSE 층에서 이미 다친 바로 그 코드포인트입니다.
`TextEditor`를 쓰는 동안에는 이것을 알 방법이 없었습니다.

## 21. 웹 채팅 UI 실측 보강 `[티어다운]`

1부가 인용한 `--thread-content-max-width: 40rem`을 다시 확인했고, **같은
변수가 `#thread-bottom-container`(컴포저)에도 걸립니다.** ChatGPT에서 메시지
열과 입력창은 구조적으로 같은 폭입니다.
([유저스크립트](https://gist.github.com/alexchexes/d2ff0b9137aa3ac9de8b0448138125ce))

**폭에 대한 자료는 여전히 갈립니다.** 위 실측은 640px이고, 디자인 블로그들은
같은 제품에 대해 720~768px이라고 적습니다. 해소하지 않습니다. 이 앱의
`Measure.reading = 560`은 WCAG CJK 40 글리프에서 나온 값이므로 어느 쪽과도
독립적입니다.

Claude.ai의 실측 토큰: 어시스턴트 발언은 **말풍선 없는 전폭 평문**,
사용자 발언은 `rounded-2xl` `max-w-[80%]` 말풍선, 컴포저는 `rounded-2xl` +
1px 테두리 + **그림자 없음**, 아바타·타임스탬프 없음.
([assistant-ui Claude 클론](https://www.assistant-ui.com/examples/claude))

컴포저 컨트롤:
- ChatGPT는 모드에 따라 **플레이스홀더 문구가 바뀝니다.**
- Claude는 **입력이 비면 보내기 버튼이 아예 없습니다**(비활성이 아니라 부재).
- Gemini는 반대로 자리를 지키고 색만 바뀝니다 — "no layout shift when send
  activates". **둘이 어긋나며 이 앱은 Gemini 쪽입니다** — 데스크톱에서 컨트롤이
  나타났다 사라지면 레이아웃이 흔들리고, 그것이 1부 §16 P1.2가 이미 고친 문제입니다.
- ChatGPT 3개 / Claude 5개의 시작 필. 이 앱의 축 칩이 같은 자리입니다.
- 답변 아래 조작은 **데스크톱에서 hover로 드러납니다.**
  ([AI UX Playground](https://aiuxplayground.com/teardowns/))

## 22. 스크롤 — 3자 불일치. 해소하지 않습니다

- **A**: 뷰포트 하단 100px 안이면 따라가고, 사용자가 올리면 잠그고 "맨 아래로"
  버튼을 띄운다. Setproduct와 The Prompt Bench가 ChatGPT·Claude·Slack·Discord가
  전부 이렇게 한다고 적습니다.
- **B**: NN/g의 챗봇 지침 7번은 **"Avoid Autoscrolling Long Responses —
  keep users at the top of new messages"**라고 적습니다. 정반대 기준점입니다.
  ([NN/g](https://www.nngroup.com/articles/ai-chatbots-design-guidelines/))
- **C**: ChatGPT가 실제로는 A를 하지 않고 그냥 맨 아래로 끌어당긴다는 보고가
  다수 있고, 스크롤 잠금만을 위한 확장이 존재합니다.

이 앱은 현행(`.defaultScrollAnchor(.top, for: .alignment)` +
`.bottom, for: .sizeChanges)`)을 유지합니다. 근거는 이 앱의 답변이 2~3문단으로
짧다는 것이고, **B가 겨냥하는 "긴 응답"이 아니라는 가정에 기대고 있습니다.**
답변이 길어지는 변경을 하면 이 항목을 다시 보십시오.

## 23. NN/g — *Less Chat, More Answer* (2026-04-17) `[1차]`

9명, 각자 8개 사이트 챗봇 중 2~3개.

- 아무도 봇에게 "안녕하세요"라고 하지 않았고, 입력은 짧고 키워드에 가까웠으며,
  **후속 발언은 갈수록 더 짧아졌습니다.**
- 긴 문단 덩어리가 과부하를 일으켰고 **스트리밍이 그 과부하를 악화시켰습니다.**
- 선호된 구조는 짧은 문장, **문단당 2~3문장**, 목록, 굵게, 여백.
- "truncated pyramid" — 핵심만 먼저, 나머지는 **누를 수 있는 후속**으로.
- **되묻기는 드물어야 합니다.** 답을 늦추기 때문입니다.

앞의 두 가지는 이 앱의 지시문과 맞습니다(`2~3문단, 각 문단 2~4문장`).
마지막 하나는 **이 앱의 설계와 정면으로 어긋납니다** — ADR 0010 §4는 축마다
되묻기를 고정 콘텐츠로 두었습니다.

해소하지 않습니다. NN/g가 잰 것은 **사이트 안내 챗봇**이고 사용자가 원한 것은
"배송 언제 오나요"의 답입니다. 명리 상담에서 사정을 먼저 듣는 것은 지연이
아니라 형식 자체입니다. 다만 **되묻기가 답을 늦춘다는 사실 자체는 참이며**,
그래서 되묻기 단계에서도 근거 칩이 이미 보이도록 두었습니다 — 기다리는 동안
아무것도 없는 것이 아니라 무엇으로 답할지가 보입니다.

## 24. 후속 질문 칩 — 1부 §15.2에서 "버릴 것"이었던 항목

1부는 "관련 질문 캐러셀"을 버릴 목록에 넣었습니다. 근거는 Perplexity의
티어다운이 **자기 화면에 대해** "composer를 아래로 밀어낸다"고 적은 것이었습니다.

그 근거는 **위치에 대한 것이지 존재에 대한 것이 아닙니다.** 실제로:

- NN/g 지침 4번: 제안 질문은 **"clickable buttons, not text"**로 제시해
  타이핑 부담을 줄인다. `[1차]`
- Setproduct: 칩은 **마지막 답변 아래에**, 선택적이고 닫을 수 있게. "제안은
  탐색 중일 때 유용하고 사용자가 원하는 것을 알 때 해롭다." `[2차]`
- Claude 사용자들은 시작 제안을 **끄고 싶다**는 요청을 냅니다.
  ([claude-code #66117](https://github.com/anthropics/claude-code/issues/66117))

그리고 CLAUDE.md §6이 이미 이렇게 적고 있습니다 — "추천 질문도 **실제로 근거가
있는 주제로만** 만듭니다." 즉 이 저장소의 원칙은 제안 자체를 금하지 않고
**근거 없는 제안**을 금합니다.

이 앱의 구현이 §6-3(이탈 방지 장치 금지)에 걸리지 않는 이유를 적어 둡니다.

| 붙잡는 장치 | 이 앱의 후속 칩 |
|---|---|
| 모델이 만든다 | `ConsultationTopic.followUps` 고정 콘텐츠, 톤 규약 테스트 |
| 떠나려는 사람에게 나온다 | 답이 끝났을 때만, 기록 안에 |
| 누르면 곧바로 보낸다 | 입력창에 넣기만 한다. 보내는 것은 사용자 |
| 컴포저를 밀어낸다 | 기록의 마지막 요소이므로 스크롤과 함께 지나간다 |
| 감정을 건다 | 물음만 있고 권유가 없다(테스트가 물음표를 강제) |

## 25. 확인하지 못한 것 (3부)

1. **ChatGPT·Claude의 공식 단축키 문서를 1차로 확인하지 못했습니다.**
   OpenAI 헬프센터는 403이고 나머지는 3자 정리 사이트입니다.
2. **실제 한글 입력기의 Return 처리.** [chat-composer.md](./chat-composer.md) §6.
3. **말풍선 폭 640 대 768의 불일치**는 1부에 이어 여전히 미해소입니다.
4. **스트리밍 중 스크롤 3자 불일치**(§22)를 실측으로 가르지 못했습니다.
5. **후속 칩이 실제로 대화를 이어가게 하는지** 재지 못했습니다. 이 앱에는
   계측이 없고, 넣지 않을 것입니다(§6-3).
