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

---

# 4부 — 2026-07-29 재조사 (SwiftUI 스크롤·마크다운·성능)

3부까지가 **무엇을 그릴 것인가**를 다뤘다면, 이 부는 **그것이 macOS에서
실제로 되는가**를 다룹니다. 3부 §22가 미해소로 남긴 스크롤 불일치를 여기서
해소하지는 못했지만, **왜 갈리는지**는 문서 원문으로 확인했습니다.

## 26. 스트리밍 스크롤 — 3자 불일치의 근원을 찾았습니다 `[벤더]`

**Apple 문서가 보장하지 않습니다.** `defaultScrollAnchor(_:)` 원문:

> "The user may scroll away from the initial defined scroll position. When the
> content size of the scroll view changes, it **may** consult the anchor to
> know how to reposition the content."

"may consult"입니다. 3부 §22가 잰 3자 불일치는 구현 차이가 아니라 **계약이
느슨한 것**이었습니다.

`ScrollAnchorRole` 세 역할의 정의(원문):

- `.initialOffset` — 최초 스크롤 위치에 영향
- `.sizeChanges` — "how a scroll view should adjust its **content offset**
  when the scroll view's **content or container size changes**"
- `.alignment` — 콘텐츠가 컨테이너보다 **작을 때**의 정렬

즉 스트리밍 중 바닥 고정에 관여하는 것은 `.sizeChanges`입니다.

출처: <https://developer.apple.com/documentation/swiftui/view/defaultscrollanchor(_:)>,
<https://developer.apple.com/documentation/swiftui/scrollanchorrole>

### 26.1 자료가 정면으로 갈립니다. 정리하지 않고 둡니다

| 입장 | 출처 |
|---|---|
| `defaultScrollAnchor(.bottom)` 단독으로 된다 — "if the user adjusts the scroll position manually, it will scroll freely as normal" | Paul Hudson, 2024-04-11 <https://www.hackingwithswift.com/quick-start/swiftui/how-to-make-a-scrollview-start-at-the-bottom> |
| 안 된다 — **기존 항목의 내용이 늘어날 때** 실패한다고 명시 분류 | Itsuki, 2025-11-16 <https://medium.com/@itsuki.enjoy/swiftui-2-5-reliable-ways-to-automatically-scroll-to-the-bottom-of-scrollview-1581711e957c> |
| macOS 15.7.3의 SwiftUI 채팅 앱에서 실제로 실패 — "Message list scrolls **upward**, hiding incoming reply content" (미해결) | <https://github.com/openclaw/openclaw/issues/1279> |

"기존 항목의 내용이 늘어날 때"가 정확히 이 앱의 경우입니다. Hudson이 기술한
것은 **항목이 추가될 때**로 읽히며, 두 사람이 다른 것을 재고 있을 가능성이
있습니다. 확정하지 못했습니다.

### 26.2 실패 양식에 이름이 붙어 있습니다 `[1차 — 코드 주석]`

macOS 전용 SwiftUI 에이전트 채팅 `rxtech-lab/rxcode`의 `AutoScrollAnchor.swift`
헤더 주석이 순진한 구현이 깨지는 자리를 정확히 적습니다.

> "The previous implementation derived `isNearBottom` directly from
> `distanceFromBottom < threshold` on every geometry update. That fails when a
> tall card appears mid-stream: the content height grows in one frame, the
> visible rect hasn't been re-anchored yet, so `distanceFromBottom` briefly
> exceeds the threshold and `isNearBottom` flips to `false`. Subsequent
> structure-change callbacks then skip the auto-scroll, **stranding the user
> above the bottom even though they never scrolled away.**"

해법은 **콘텐츠 성장과 사용자 스크롤을 서로 다른 두 원인으로 분리**하는
것입니다. 성장했을 때는 바닥 여부를 다시 계산하지 않고, 높이가 안정적일
때만 다시 계산합니다.

같은 파일에서 확인되는 macOS 고유 관찰 하나:

> "Desktop scroll animations can pass through `.decelerating`; treating that as
> a release makes the programmatic pin immediately bounce back to the bottom."

따라서 `.decelerating`을 사용자 조작으로 보면 안 됩니다.

출처: <https://github.com/rxtech-lab/rxcode/blob/main/Packages/Sources/RxCodeChatKit/AutoScrollAnchor.swift>

### 26.3 같은 업데이트 사이클에서는 스크롤할 수 없습니다 `[벤더 포럼]`

> "You cannot scroll to an item **added in the same update cycle**; by the time
> `scrollTo` is called, SwiftUI doesn't know about the new item yet."

이 저장소가 ⌘F 버그에서 이미 배운 것과 같은 형태입니다(§25 지뢰표 —
"뷰를 만드는 것과 그 뷰에 신호를 보내는 것은 한 박자 떼어 놓을 것").

출처: <https://developer.apple.com/forums/thread/814050>

### 26.4 성능 — 기하 변화를 뷰 상태에 쓰면 안 됩니다 `[벤더]`

`onScrollGeometryChange` 문서 원문:

> "The geometry of a scroll view changes frequently while scrolling. You should
> avoid updating large parts of your app whenever the scroll geometry changes."

그래서 transform/action 두 단계이고, transform 결과가 `Equatable`하게 바뀔
때만 action이 뜁니다. 장부를 `@State` 구조체에 두면 이 보호가 무의미해집니다
— 매 프레임 상태가 바뀌어 재구성이 돕니다.

같은 문서의 또 하나: 계층에 스크롤 뷰가 여럿이면 **첫 번째만** 콜백하고
런타임 경고가 남습니다. `onScrollPhaseChange`도 같습니다.

출처: <https://developer.apple.com/documentation/swiftui/view/onscrollgeometrychange(for:of:action:)>

### 26.5 `List`를 고르면 스크롤 API 전부를 포기합니다 `[벤더 DTS]`

Apple DTS 엔지니어 답변(2024-12):

> "`.scrollPosition(_:anchor:)` doesn't currently work with a List. Please file
> an enhancement request via Feedback Assistant."

`defaultScrollAnchor`·`onScrollGeometryChange`·`onScrollPhaseChange`도
`ScrollView` 대상입니다. 이 화면이 `ScrollView` + `VStack`을 쓰는 이유가
여기 있습니다.

덧붙여 macOS의 `List`는 지연 로드를 하지 않는다는 보고가 있고(2022, Apple
답글 없음), `NSTableView` 위의 self-sizing이 "destined to fail on macOS"라는
분석도 있습니다. 반대로 iOS 벤치마크는 `List`가 `LazyVStack`을 압도합니다
(바닥까지 스크롤 5.53초 대 52.3초). **어느 자료도 macOS 15에서의 직접 비교
측정치를 주지 않습니다.** 정리하지 않고 둡니다.

출처: <https://developer.apple.com/forums/thread/770682>,
<https://developer.apple.com/forums/thread/704778>,
<https://kean.blog/post/not-list>,
<https://www.strv.com/blog/swiftui-list-vs-lazyvstack>

## 27. 마크다운 — 파싱은 되지만 렌더링은 안 됩니다 `[벤더]`

이것이 이 절의 핵심 사실입니다.

Foundation의 파서는 `.full`에서 제목·목록·코드블록·인용·표까지
`PresentationIntent`로 **파싱합니다.** 그러나 SwiftUI `Text`는 그것을
**그리지 않습니다.** Apple 포럼(2021-08): `NSPresentationIntent` 속성은
보존되지만 렌더 시 "flattened" — 여러 문단이 문단당 하나가 아니라 **단일
text layout fragment로 합쳐집니다.**

`Text(LocalizedStringKey)`가 지원하는 것은 **인라인뿐**입니다: 굵게·기울임·
취소선·인라인 코드·링크. 제목·목록·인용·표·이미지는 무시됩니다. 파서 자체는
cmark-gfm이며 Apple 엔지니어가 포럼에서 확인했습니다.

`AttributedString.MarkdownParsingOptions.interpretedSyntax`:

- `.inlineOnly` (**기본값**) — 인라인만 해석
- `.inlineOnlyPreservingWhitespace` — 인라인만 해석하되 **공백·개행 보존**
- `.full` — 블록까지 해석(하지만 SwiftUI가 안 그림)

기본값을 쓰면 **문단 안의 줄바꿈이 사라집니다.** 이 화면이
`.inlineOnlyPreservingWhitespace`를 쓰는 이유입니다.

`failurePolicy: .returnPartiallyParsedIfPossible`이 스트리밍 중 반쯤 깨진
마크다운에 직접 관련됩니다.

**함정**: `Text(문자열변수)`는 마크다운을 파싱하지 **않습니다.** 문자열
리터럴만 `LocalizedStringKey`로 취급되기 때문입니다. `Text(.init(변수))`가
필요합니다. 이 화면은 `AttributedString`을 직접 만들므로 해당하지 않습니다.

출처: <https://developer.apple.com/forums/thread/687473>,
<https://developer.apple.com/forums/thread/682711>,
<https://developer.apple.com/documentation/foundation/attributedstring/markdownparsingoptions>,
<https://fatbobman.com/en/posts/attributedstring/>

### 27.1 스트리밍 마크다운 — 증분 파싱 진입점이 없습니다

Foundation에도 SwiftUI에도 없습니다. 둘 다 전체 버퍼를 처음부터 다시
파싱합니다. 그러나 **비용의 위치가 파싱이 아닙니다.** fatbobman 측정:
슬라이드 한 장 분량 파싱이 평균 약 0.04초이고, 비싼 것은 **뷰 트리
재구축**입니다.

공통 완화책이 **블록 단위 청킹**입니다 — 완결된 블록은 캐시하고 진행 중인
마지막 블록만 매 토큰 다시 봅니다.

미완결 마크업 처리에 두 전략이 보고됩니다.

1. **닫힐 때까지 숨기기** — "if you count the markers and find an odd number,
   you know the last one is unclosed... hide everything from the unclosed
   marker onwards until its partner arrives"
2. **사본에서 자동 닫기** — "Auto-close it temporarily **for rendering
   purposes**. The original string is never modified."

이 앱은 (2)를 골랐고 **마지막 블록에만** 적용합니다. (1)은 글자가 나타났다
사라지는 것으로 보입니다.

출처: <https://tigerabrodi.blog/how-to-build-a-performant-ai-markdown-renderer>,
<https://fatbobman.com/en/posts/a-deep-dive-into-swiftui-rich-text-layout/>

### 27.2 대가 — 여러 `Text`에 걸친 선택은 불가능합니다 `[1차]`

> "Each `Text` view will still be **individually selectable**... There is **no
> way to select contents of multiple `Text` views at the same time**."

블록마다 `Text`를 만들면 문단을 넘는 드래그 선택을 잃습니다. 알려진 우회는
`NSTextView`가 레이아웃을 맡고 SwiftUI 뷰를 겹치는 방식뿐입니다.

이 앱은 그 대가를 받아들이고 "복사" 버튼과 마크다운 내보내기로 답변 전체를
가져가는 경로를 유지합니다.

출처: <https://nilcoalescing.com/blog/EnableTextSelectionForNonEditableText/>

## 28. 확인하지 못한 것 (4부)

정리하지 말고 그대로 둘 것.

1. **실제 스트리밍 중의 따라가기 동작을 실기로 확인하지 못했습니다.**
   캡처는 완성된 상담만 그립니다. 26.1의 불일치는 여전히 열려 있습니다.
2. **한글 본문에서 기울임(`*…*`)과 인라인 코드(`` `…` ``)가 시각적으로
   구분되는지 확인하지 못했습니다.** 캡처에서 굵게·제목·목록·인용·코드
   블록은 확인했으나, 한글은 이탤릭 자형이 없어 합성 기울임이 약하고
   모노스페이스 폴백도 라틴만큼 다르지 않아 보입니다.
3. **`.textSelection(.enabled)`와 macOS VoiceOver의 상호작용**에 관한 자료를
   전혀 찾지 못했습니다.
4. **`.textSelection(.enabled)`와 `.contextMenu`를 같은 `Text`에 걸었을 때
   macOS 우클릭이 어느 쪽으로 가는지** 명시된 문서가 없습니다.
5. **iOS 18.0의 `List` textSelection 버그(18.1에서 수정)가 macOS에도
   있었는지** 스레드에 언급이 없습니다.
6. **마크다운 태스크 리스트(`- [ ]`) 전용 `PresentationIntent.Kind` 케이스의
   존재 여부**를 확인하지 못했습니다.
7. **`@State` 구조체 장부가 실제로 얼마나 비싼지 재지 않았습니다.** Apple
   문서의 경고와 구조적 논증으로 클래스로 옮겼을 뿐, 프로파일링하지
   않았습니다.

## 29. 4부 결정에 대한 역검증 `[2026-07-29]`

구현을 마친 뒤 일곱 결정을 따로 검증했습니다. **한 건이 뒤집혔고 두 건에서
기존 전제가 흔들렸습니다.** 정리하지 않고 그대로 적습니다.

### 29.1 뒤집힌 것 — 후속 질문을 평문으로 만들었다가 되돌렸습니다

캡슐 셋이 무거워 보여 평문 목록으로 바꿨습니다. **NN/g 지침의 제목이 그대로
반대입니다** `[연구]`:

> "**Offer Relevant Suggested Questions as Buttons, Not Text.** To make it
> easier for users to choose a suggested prompt, present them as clickable
> buttons, rather than text. This approach avoids unnecessary typing and
> supports offering multiple suggested prompts without creating a wall of text."

실사용자 조사의 실패 사례가 붙어 있습니다. 물음을 **답변 글 안에 텍스트로**
넣은 챗봇에서 참가자가 직접 불평했습니다 — "she complained that the questions
were inserted in the answer text, and she'd have to type them: 'Rather,
instead of … [making] me type … [I'd prefer] … multiple-choice options'".

**1부 §15.3(1)이 이미 같은 함정을 적어 두었습니다** — "지금은 텍스트를
버튼처럼 그린 최악의 조합입니다". 방향만 반대로 다시 밟은 것이었습니다.

되돌리면서 원인을 다시 봤습니다. 무거워 보이던 것은 캡슐이 아니라
**테두리**였습니다. 선을 지우고 옅은 면으로 바꾸면 누를 수 있다는 것은 남고
소음은 줍니다.

출처: <https://www.nngroup.com/articles/ai-chatbots-design-guidelines/> (2026-04-24)

### 29.2 흔들린 전제 1 — ADR 0012 §4의 Perplexity 근거

ADR 0012 §4는 "관련 질문 캐러셀"을 버릴 이유로 **위치**를 들었습니다 —
"Perplexity의 티어다운이 자기 화면에 대해 컴포저를 아래로 밀어낸다고
적는다". 이번 조사는 그 진술을 **확인하지 못했고 반대 증거를 찾았습니다**
`[3자]`:

> "The '**Ask Follow-up' bar is always present at the bottom**, giving the user
> an 'escape hatch' to change the topic."

그리고 "캐러셀"이라는 말은 Perplexity의 후속 질문이 아니라 **재생성 변형**
캐러셀(ChatGPT·Claude 양쪽)과 상품 이미지 캐러셀에서 나옵니다.

**ADR 0012를 고치지 않습니다.** 그 결정(기록의 마지막 요소에 둔다)은
독립적으로 옳고 이 앱에서 그대로 유지됩니다. 다만 **근거로 든 사실 하나가
확인되지 않았다**는 것을 여기 남깁니다. 3부 §24에 적은 Perplexity 관련
진술도 같은 유보를 받습니다.

출처: <https://assets.nextleap.app/submissions/PerplexityUXReview1-f3ba5002-469a-4590-8d33-8365aaab09a8.pdf>

### 29.3 흔들린 전제 2 — 읽기 폭의 근거가 AAA이고 "값"이 아닙니다

WCAG 문구 자체는 정확히 실재합니다 `[표준 원문]`:

> "Width is no more than 80 characters or glyphs (**40 if CJK**)."
> "Studies have shown that Chinese, Japanese and Korean (CJK) characters are
> approximately twice as wide as non-CJK characters…"

**그러나 두 가지를 1부가 적지 않았습니다.**

1. SC 1.4.8은 **Level AAA**입니다.
2. Note 1: "**Content is not required to use these values. The requirement is
   that a mechanism is available** for users to change these presentation
   aspects." 즉 이 기준이 요구하는 것은 고정 폭 값이 아니라 **조정 수단**입니다.
   이 앱에는 읽기 폭 조정 수단이 없습니다.

그리고 비교 대상과 어긋납니다. Claude.ai의 대화 컨테이너는 독립적인
유저스크립트 3건이 모두 `max-w-3xl`로 지목하고, Tailwind 문서상 그것은
**768px**입니다 — CJK 40 글리프(약 520pt ≈ 693px)보다 넓습니다. 3부까지
미해소로 남긴 "640 대 768"은 **768 쪽으로 기울었습니다**(단 여전히 DOM
클래스에서 추론한 값이고 브라우저에서 잰 값이 아닙니다).

`Measure.reading = 560`을 바꾸지 않습니다. 근거는 WCAG의 준수가 아니라 1부
§2의 실측(한 행의 한글 글자수)이고 그것은 그대로입니다. 바뀐 것은 **그
값을 무엇으로 정당화하는가**입니다.

출처: <https://www.w3.org/WAI/WCAG22/Understanding/visual-presentation.html>,
<https://tailwindcss.com/docs/max-width>,
<https://gist.github.com/ycvk/2ab589109ef328ffd77c03751c6773a9>

### 29.4 지지된 것

- **인용 칩 중복 제거** `[연구]`. NN/g: "**Place redundant links far apart from
  each other. If they can be seen together within the same view, then it's an
  indication that you may have too much redundancy.**" 그리고 "Duplicating
  features adds significant overhead to **both the scanning process and the
  comprehension process** … users … have to spend additional time figuring out
  whether the duplicate is a new feature or an old feature." 헤더와 답변 아래
  칩은 정확히 "same view"에 함께 보였습니다.
  <https://www.nngroup.com/articles/duplicate-links/>,
  <https://www.nngroup.com/articles/reduce-redundancydecrease-duplicated-design-decisions/>
- **어시스턴트 전폭 무레이블 / 사용자 버블** — 다수가 지지합니다. Claude.ai의
  사용자 메시지 컨테이너는 `rounded-xl` + 그라디언트 + `max-w-[75ch]`이고
  어시스턴트 쪽에는 대응 컨테이너가 없습니다. 모방 구현 하나는 이 앱이 한
  것과 **똑같은 보완**을 적어 둡니다 — "Labels are kept in the DOM for screen
  readers but **visually hidden**."
  **반대 출처도 있습니다**: aiuxdesign.guide는 "User messages right-aligned,
  **AI messages left-aligned. This is a universal convention — don't break
  it.**" 그리고 "**Full-width messages are hard to read**"라며 양쪽 다 버블에
  60–75% 폭을 권합니다. 해소하지 않습니다.
  <https://gist.github.com/ycvk/2ab589109ef328ffd77c03751c6773a9>,
  <https://www.aiuxdesign.guide/guides/conversational-ui-guide/anatomy-of-a-chat-interface>
- **인사말을 컴포저 옆에 붙이기** `[연구, 간접]`. NN/g 근접성: "**Proximity is
  one of the most important grouping principles and can overpower competing
  visual cues.**" 그리고 "far-away items can be easily overlooked by
  task-focused users … sometimes described as '**tunnel vision**'." ChatGPT는
  빈 상태에서 인사말과 컴포저를 **한 덩어리로** 렌더합니다.
  <https://www.nngroup.com/articles/gestalt-proximity/>
- **Pew 1%는 실재합니다** `[연구]`. 원문: "Google users who encountered an AI
  summary also rarely clicked on a link in the summary itself. This occurred in
  **just 1% of all visits**." 방법론: Ipsos KnowledgePanel 미국 성인 900명,
  2025년 3월 실제 브라우징 추적, 68,879건 검색 중 12,593건이 AI Overview.
  **다만 측정 대상은 검색 AI 요약의 클릭이지 채팅 UI의 인용 배치가
  아닙니다.** §6-2의 근거로 계속 쓰되 이 한계를 함께 적습니다.
  <https://www.pewresearch.org/short-reads/2025/07/22/google-users-are-less-likely-to-click-on-links-when-an-ai-summary-appears-in-the-results/>

### 29.5 혼재 — 호버 노출

데스크톱 호버는 관행으로 확인되지만, ChatGPT의 **어시스턴트** 액션바는
"**Always visible** — Copy, Good response, Bad response, Read aloud, Share,
Regenerate, More"로 기술하는 출처가 있고 사용자 메시지만 호버입니다. 그리고
호버 방식의 실사용 실패가 OpenAI 포럼에 기록되어 있습니다 — 새 구현이 호버가
빠질 때 "**COMPLETELY REMOVES THE HTML**"이라 읽어주기 오디오가 끊기고,
버튼으로 커서를 옮기는 동안 버튼이 사라져 클릭이 안 되는 재현 보고가
있습니다.

이 앱은 호버를 유지하되 **마지막 답변에는 항상 보입니다.** 그리고 버튼이
호버 영역 **안에** 있으므로 커서를 옮기는 동안 사라지는 실패는 나지 않습니다.
확정된 관행이 없다는 것을 기록해 둡니다.

출처: <https://www.assistant-ui.com/examples/chatgpt>,
<https://community.openai.com/t/chatgpt-message-buttons-removed-when-hover-exits-message-breaking-audio-repaired/1141963>

### 29.6 이번에도 증거를 찾지 못한 것

1. **어시스턴트 답변에 상시 역할 레이블이 있었던 시기가 있는지.** 벤더 문서도
   아카이브 스크린샷도 없습니다. 한 3자 출처는 Claude가 "You"/"Claude"로
   레이블한다고 적지만 DOM 증거와 충돌합니다.
2. **인용을 답 앞에 두는 것과 뒤에 두는 것을 비교한 연구.** 없습니다.
3. **ChatGPT 열 폭의 DOM·벤더 확증.** 3자 주장(768px)만 있습니다.
4. **컴포저가 고정된 상태에서 인사말 하단 정렬과 중앙 정렬을 비교한 연구.**
   없습니다. 일반 근접성 원칙만 있습니다.
5. **Raycast AI의 시각적 턴 표현.** 공식 매뉴얼에 레이아웃 기술이 없습니다.

## 30. 배포 자산 실측 `[2026-07-29]`

세 번째 조사가 `chatgpt.com`과 `claude.ai`의 **배포된 CSS 번들을 직접 내려받아**
쟀습니다. 3부까지 티어다운·유저스크립트 추정으로 남아 있던 항목 여럿이
닫혔습니다.

**방법**: 두 사이트 모두 봇 차단이라 직접 조회가 안 됩니다. ChatGPT는 Wayback의
`id_` 원본 스냅숏에서 SSR HTML을 받아 링크된 `root-*.css`(1.69 MB)와
`conversation-small-*.css`(110 KB)를 같은 경로로 취득. Claude는 라이브 번들
`assets-proxy.anthropic.com/claude-ai/v2/assets/v1/c6a992d55-Cb4ksHML.css`
(416 KB)를 직접 취득하고 2026-01-21 스냅숏의 `_next/static/css/*` 9개와 교차
확인. Tailwind는 실제로 쓰인 클래스만 방출하므로 번들에 존재한다는 것은 앱
어딘가가 참조한다는 뜻입니다. **다만 어느 DOM 노드에 붙는지는 CSS만으로
확정되지 않습니다.**

### 30.1 말풍선 비대칭 — 1부 §12.1의 미해소 항목이 닫혔습니다

1부는 "티어다운들이 어시스턴트 답변도 bubble이라 부르지만 라이브 DOM을 직접
재지 않았으므로 해소하지 않는다"고 남겼습니다. **벤더 자산 수준에서 닫힙니다.**

ChatGPT의 디자인 토큰에 사용자 발언용 표면이 **8개 테마 전부에** 있고,
어시스턴트용은 **0건**입니다.

```
--black-theme-user-msg-bg   --blue-theme-user-msg-bg   --default-theme-user-msg-bg
--green-theme-user-msg-bg   --orange-theme-user-msg-bg --pink-theme-user-msg-bg
--purple-theme-user-msg-bg  --yellow-theme-user-msg-bg   (+ 각 -text)
```

`--*(assistant|agent|bot)*msg*` 패턴 검색 결과 두 번들 통틀어 0건.
**어시스턴트 발언에는 "메시지 표면"이라는 개념 자체가 없습니다.**

### 30.2 Claude는 색이 아니라 **서체**로 가릅니다

```css
--font-claude-response: var(--font-anthropic-serif);
--font-user-message: var(--font-ui);   /* = anthropic-sans */
```

답변 전용 타이포 스케일이 통째로 있고, 다크 모드에서 **굵기를 낮춥니다**
(400→360, 600→530) — 어두운 배경에서 굵어 보이는 것을 보정합니다.
`--font-dyslexia`와 문자열 `"Dyslexic friendly"`도 있습니다.

이 앱은 색(주사 워시)으로 가릅니다. 세 번째 축(서체)이 있다는 것만 기록합니다.

### 30.3 640 대 768 — **둘 다 맞습니다. 컨테이너 질의로 갈립니다**

1부·3부가 두 번 미해소로 남긴 충돌입니다. ChatGPT SSR HTML의 스레드 컨테이너
4곳이 전부 같은 조합을 씁니다.

```
[--thread-content-max-width:40rem] @w-lg/main:[--thread-content-max-width:48rem]
mx-auto max-w-(--thread-content-max-width)
```

그리고 CSS에서 `@container main (width>=64rem)`을 확인했습니다. **즉 `main`
컨테이너가 1024px 미만이면 640px, 이상이면 768px입니다.**

Claude는 `.chat-ui-core .max-w-3xl.px-6` — **768px 컨테이너 − 24×2 = 본문
720px**, 브레이크포인트 없이 고정입니다.

em(= CJK 글리프 수)으로 환산하면:

| | 본문 실폭 | 본문 크기 | em |
|---|---|---|---|
| ChatGPT 좁은 폭 | 640px | 16px | **40** |
| ChatGPT 넓은 폭 | 768px | 16px | 48 |
| Claude | 720px | 16px | 45 |
| **이 앱 (560 − 18×2)** | **524pt** | **13pt** | **약 40** |

**`Measure.reading = 560`은 ChatGPT의 좁은 브레이크포인트와 정확히 같습니다.**
1부 §2의 세 계산이 수렴한 값이 실측과 맞았습니다.

**다만 두 대표 제품 모두 넓은 창에서 40em을 넘습니다.** 이 앱은 넓히지
않습니다 — 넓히면 한글 40 글리프(WCAG 1.4.8 CJK 상한)를 넘기 때문이고, 저
제품들은 CJK를 기준으로 정하지 않았습니다. 29.3의 유보(AAA이고 "값"이 아니라
"수단"을 요구)는 그대로 유효합니다.

부수 토큰: `--thread-component-gap: 24px`(턴 간격, 이 앱은 20),
거터 3단 16/24/64px.

### 30.4 컴포저는 본문과 같은 폭이어야 합니다 `[실측]`

폭 상한을 두는 제품 **7 중 5가 컴포저에 정확히 같은 값**을 적용합니다
(ChatGPT는 같은 CSS 변수, Open WebUI는 같은 리터럴을 두 곳, Ollama 공식 앱·
Cherry Studio·AnythingLLM·Jan도 동일). **어긋나는 둘은 LM Studio와
Enchanted이고 둘 다 결함으로 나타납니다** — Enchanted는 메시지 목록에
`frame(maxWidth:)`가 없고 입력 뷰에만 800이 걸려 창을 넓히면 두 폭이
벌어집니다.

이 앱은 기록·머리·컴포저가 모두 `Measure.reading`을 씁니다. 지지됩니다.

### 30.5 역할 라벨 — 5 대 5이고, **갈리는 데 규칙이 있습니다**

| 라벨 없음 | 라벨 있음 |
|---|---|
| ChatGPT, Claude, Jan, Ollama 공식 앱, AnythingLLM | Open WebUI, LM Studio, Msty, Cherry Studio, Enchanted |

**라벨을 다는 다섯은 전부 메시지마다 모델이 달라질 수 있는 앱이고, 라벨이 그
자리에서 모델명을 나릅니다.** 이 앱의 provenance 줄(`Gemma 4 E2B · 이 앱 안`,
상시)이 정확히 그 일을 합니다. 즉 "풀이" 역할 라벨을 빼고 모델 줄을 남긴
것은 이 다섯과 같은 배치입니다.

"어시스턴트 전폭 평문"은 조사한 **11개 제품 전부**에서 참이며 예외가
없습니다.

### 30.6 hover 은닉에는 접근성 예외가 달려 있습니다 `[실측-소스]`

ChatGPT는 hover이고 **300ms 지연**까지 겁니다
(`group-hover/turn-messages:delay-300`).

그런데 Open WebUI는 액션 13곳 전부를 이렇게 씁니다.

```svelte
class="{($settings?.highContrastMode ?? false) ? 'visible' : 'invisible group-hover:visible'}"
```

**대비를 높인 사용자에게는 hover 은닉이 전부 해제됩니다.** 그리고 `opacity-0`이
아니라 `invisible`이라 **자리는 항상 차지합니다** — 나타날 때 줄이 밀리지
않습니다. Enchanted가 `0`이 아니라 `0.0001`을 쓰는 것도 같은 이유입니다.

**이 앱에 그 예외를 가져왔습니다.** `colorSchemeContrast == .increased`면
답변 액션이 항상 보입니다. 관례를 가져오면서 그 관례가 이미 달아 놓은
안전장치도 함께 가져옵니다.

넷(Jan · Cherry Studio · Ollama · Msty)은 **어시스턴트 액션만 상시**로
빼 두었습니다. Cherry Studio의 `isLatestAssistantMessage`는 이 앱의
`isLast`와 같은 발상입니다.

### 30.7 결정 3·4에는 선례가 없습니다 — 없다는 것이 확인된 결과입니다

**조사한 11개 제품 중 근거를 전사 상단에 고정하는 것도, 인용을 층 사이에서
중복 제거하는 것도 없습니다.** ChatGPT에서 `position: sticky`가 걸린 것은
`#thread-bottom-container` 하나뿐이고 상단 고정 요소는 없습니다.

반증은 아닙니다. 다만 "다른 제품이 하니까"로는 지지되지 않으며, 이 두 결정은
**이 앱의 정체성(인용에서 생성한다)에서만 나옵니다.** §5의 "구조적 선택의
부수 효과" 그대로입니다.

가장 가까운 것: Perplexity가 리서치 단계를 산문 **위에** 접어 두고, Jan이
추론 블록을 답변 위에 두며 최신 스텝 하나만 보입니다.

### 30.8 **NN/g 지침 7이 이 앱의 바닥 따라가기와 어긋납니다** — 해소하지 않습니다

NN/g 원문 `[벤더, 2026-04-24]`:

> "Some chatbots autoscroll users at the end of lengthy responses, forcing
> users to then scroll back up to read from the beginning. **If a response is
> longer than the chat viewport, keep the user's scroll position at the top of
> the new message rather than jumping to the bottom.**"

그리고 ChatGPT가 실제로 그렇게 구현되어 있습니다 `[실측-CSS]`.

```css
--thread-stream-context-height: max(22*var(--spacing), var(--thread-show-context-pct,1/3)*var(--scroll-root-safe-area-height));
--thread-response-height: calc(var(--scroll-root-safe-area-height) - var(--thread-stream-context-height));
/* 그 값을 scroll-margin-bottom으로 건다 */
```

**뷰포트의 약 2/3를 새 응답용으로 예약하고 상단 1/3은 맥락으로 남깁니다.**
하단을 쫓는 구조가 아닙니다. Ollama 공식 앱도 전송 시 새 사용자 메시지를
컨테이너 **상단**으로 보내고 리스트 끝에 동적 spacer를 둡니다. LM Studio에는
`Scroll message to top on send` 토글이 있습니다.

**그러나 제품은 갈립니다.** 바닥을 따라가고 "맨 아래로"를 주는 쪽이
Claude · Jan · Open WebUI · AnythingLLM · Cherry Studio로 더 많습니다.
scroll-to-bottom 어포던스는 사실상 표준이며, 없는 것은 Enchanted 하나이고
그것은 자동 추종 해제도 없습니다.

**이 앱은 다수 쪽(바닥 따라가기 + 맨 아래로 + 사용자 스크롤 시 해제)을
유지합니다.** 이유 둘입니다.

1. 이 앱의 답변은 2~3문단으로 짧아 뷰포트를 넘는 일이 드뭅니다. 지침 7의
   전제("longer than the chat viewport")가 자주 성립하지 않습니다.
2. **상단 고정 방식을 실기로 확인할 수단이 없습니다.** 캡처 하네스는 완성된
   상담만 그리므로 스트리밍 동작을 검증할 수 없고, 검증하지 못한 채로 더
   복잡한 스크롤 체계를 넣는 것은 지금 있는 것보다 나쁩니다.

**이것은 열린 결정입니다.** 답변이 길어지는 변경(지시문의 문단 수 상향,
더 큰 모델)이 생기면 지침 7이 실제로 물기 시작합니다. 그때 다시 봐야 합니다.

추종 해제 임계값 참고: Open WebUI 5px(`Chat.svelte`)와 50px
(`Messages.svelte`)이 **같은 저장소 안에서 어긋납니다**. Jan 20px.
AnythingLLM은 40px에 **방향 판정**까지 겹칩니다 — 하단 근처에 있는 것만으로는
재개하지 않고 아래로 스크롤해 들어와야 합니다. 이 앱은 44pt이고 방향 대신
"높이가 변했는가"로 가릅니다.

### 30.9 Raycast — 렌더링 아키텍처를 바꾼 이유가 텍스트입니다 `[벤더, 2026-05-14]`

Raycast v1은 "a native macOS app built with Swift on top of AppKit"이고
"We didn't make a lot of use of SwiftUI either"였습니다. **v2는 React를
WKWebView에 띄우는 하이브리드로 바꿨고, 그 이유로 채팅 텍스트 렌더링을 명시적으로
듭니다.**

> "**Text rendering. AI Chat and any feature involving rich text rendering is
> where WebKit really shines.**" — "scrolling through long conversations,
> rendering markdown, handling code blocks with syntax highlighting."

메모리는 200–300MB → 350–450MB.

**이 앱은 반대로 갑니다** — SwiftUI `Text`로 마크다운을 직접 조립합니다.
그 대가가 27.2(문단을 넘는 선택 불가)이고, Raycast가 지불한 대가는 WebView와
메모리입니다. 어느 쪽도 공짜가 아니라는 것을 기록해 둡니다.

Raycast의 메시지 렌더링·폭·간격·타이포그래피 문서는 **없습니다**. 확인된 것은
`↵` 전송 / `⇧↵` 줄바꿈, `⌘R` 재생성, 그리고 스트리밍 중 입력이 막히지 않는다는
것(`Queue` / `Steer`)입니다.

## 31. 정리하지 않고 남긴 자료 충돌 (4부 누적)

1. `defaultScrollAnchor(.bottom)` 단독 동작 여부 — Hudson(된다) 대
   Itsuki(안 된다) 대 openclaw #1279(실패 관찰). §26.1.
2. macOS 줄바꿈 modifier — Zac White(`⌥↩`) 대 SerialCoder(`⌘↩`), 그리고
   macOS 15.1의 Mail과 Pages가 서로 다름. §2.2(2부 조사).
3. `List` 대 `LazyVStack` — iOS 벤치마크는 List 압승, macOS 보고는 List가
   지연 로드조차 안 함. **macOS 15 직접 비교 측정치는 어느 자료에도 없습니다.**
   §26.5.
4. Perplexity가 컴포저를 밀어내는가 — 3부·ADR 0012 §4의 전제 대 "Ask
   Follow-up bar is always present at the bottom". §29.2.
5. 어시스턴트 전폭 평문 — 11/11 제품 실측 대 aiuxdesign.guide의 "universal
   convention: AI messages left-aligned, 60–75% 폭". §29.4.
6. LM Studio 어시스턴트 말풍선 유무 — 스크린샷 3장 대 이슈 #1456. §30.5 각주.
7. Open WebUI 추종 임계값 — 같은 저장소 안에서 5px 대 50px. §30.8.
8. 스크롤 정책 — NN/g 지침 7 + ChatGPT·Ollama·LM Studio(상단 고정) 대
   Claude·Jan·Open WebUI·AnythingLLM·Cherry Studio(바닥 추종). §30.8.
