# 조사: 채팅 입력창 — Return 전송과 한글 입력기

작성 2026-07-29. 대상은 macOS 15+ / SwiftUI / Swift 6.

이 노트는 **사실만** 적습니다. 결정은 [consultation-ux.md](./consultation-ux.md) §20과
`App/FourEight/Views/ChatComposer.swift`의 주석에 있습니다.

근거 등급: `[1차]` 벤더 문서·규격 원문 · `[실측]` 이 저장소에서 직접 돌려 확인 ·
`[2차]` 블로그·포럼 등 확인되지 않은 주장.

---

## 1. SwiftUI가 못 하는 것 `[1차]`

- `onSubmit(of: .text)`은 `TextField`·`SecureField`가 발화시킵니다. 여러 줄
  필드(`TextField(axis: .vertical)`, `TextEditor`)에서 Return은 **줄바꿈으로
  소비**되고 제출로 해석되지 않습니다.
- `TextEditor`에는 스크롤 위치를 지정하는 API가 없습니다. macOS에서 필요하면
  `NSTextView`를 `NSViewRepresentable`로 감싸는 것이 알려진 경로입니다.
  ([Apple Developer Forums 685622](https://developer.apple.com/forums/thread/685622))
- `keyboardShortcut(.defaultAction)`을 버튼에 걸어도 **포커스를 가진
  `TextField`가 Return을 먼저 가져갑니다.**
  ([Apple Developer Forums 701413](https://developer.apple.com/forums/thread/701413))

`.onKeyPress(_:phases:)`는 macOS 14+에서 쓸 수 있지만
([Apple](https://developer.apple.com/documentation/swiftui/view/onkeypress(_:phases:action:))),
**입력기 앞뒤 중 어디에 놓이는지 Apple 문서가 규정하지 않습니다.** 아래 §2의
이유로 이 자리에서는 쓸 수 없다고 판단할 근거가 됩니다 — 확인되지 않은 것은
확인되지 않은 것으로 둡니다.

## 2. Cocoa 텍스트 입력의 순서 `[1차]`

Apple의 *Cocoa Text Architecture Guide*, Text Editing 장:

> The key window sends the text view a `keyDown:` message with the event as its
> argument. The `keyDown:` method passes the event to `handleEvent:`, which
> sends the character input to the input context for key binding and
> interpretation.

> In response, the input context sends either `insertText:replacementRange:`,
> `setMarkedText:selectedRange:replacementRange:`, or `doCommandBySelector:` to
> the text view.

> With standard key bindings, an Enter or Return character causes the text view
> to receive `doCommandBySelector:` with a selector of `insertNewline:`.

([Apple 아카이브](https://developer-mdn.apple.com/library/archive/documentation/TextFonts/Conceptual/CocoaTextArchitecture/TextEditing/TextEditing.html))

읽어야 할 것은 순서입니다. **입력 컨텍스트(=입력기)가 먼저이고
`doCommandBySelector:`가 나중입니다.** 조합 중인 글자를 확정하는 일은 입력기
단계에서 `insertText:`로 일어나고, 명령은 그다음에 옵니다.

**같은 문서가 규정하지 않는 것.** 입력기가 조합 중일 때 Return을 스스로
소비하는지, 아니면 확정한 뒤 `insertNewline:`까지 흘려보내는지는 이 문서에
없습니다. Input Method Kit 쪽 동작이고 입력기 구현에 달려 있습니다.
**확인하지 못했습니다.**

## 3. 조합 상태를 알아내는 방법 `[1차]`

`NSTextInputClient`의 `hasMarkedText()`가 조합 중인지를 알려 줍니다.
`NSTextView`가 이 프로토콜을 구현합니다.

AppKit 포럼에서 같은 용도로 쓰인 사례가 있습니다 — 길이 제한을 걸 때
"`hasMarkedText == NO`일 때만 자르면 조합에서 더 잘 동작한다. 다만 조합 중
일시적으로 한도를 넘는 것은 여전히 가능하다"는 보고입니다.
([Apple Developer Forums 802355](https://developer.apple.com/forums/thread/802355))

## 4. "마지막 글자가 사라진다"는 사고 유형 `[2차]`

한글 입력에서 반복 보고되는 증상이고 macOS 고유가 아닙니다.

- [nhn/tui.editor #3213 — 한글 엔터입력시 마지막 글자 사라짐](https://github.com/nhn/tui.editor/issues/3213)
- [Eclipse: Mac에서 한글 마지막 글자 사라지는 문제](https://blog.wanzargen.me/14)
- [Apple 커뮤니티(한국) — 맥 한글 입력시 글자 누락 또는 자소 분리](https://discussionskorea.apple.com/thread/254509252)
- [Microsoft Q&A — 한글입력시 마지막 글자가 2번 생기는 오류](https://learn.microsoft.com/ko-kr/answers/questions/5021282/2)

공통점은 **조합이 확정되기 전에 값을 읽어 가는 코드**입니다. 확정 전의
버퍼를 읽으면 마지막 음절이 빠지고, 확정 뒤에 한 번 더 읽으면 중복됩니다.

여기서 나오는 사실 하나: 값을 `keyDown` 시점의 캐시에서 읽는지
`doCommandBySelector:` 시점의 텍스트 저장소에서 읽는지가 갈림길입니다. 후자는
§2의 순서상 이미 `insertText:`가 지난 뒤입니다.

## 5. 이 저장소에서 실기로 확인한 것 `[실측]`

실제 `NSTextView` + TextKit 1 스택에 델리게이트를 붙여 확인했습니다
(`doCommand(by:)`를 직접 불러 델리게이트 경로를 통과시킴). 9건 전부 통과:

| 확인한 것 | 결과 |
|---|---|
| Return이 `doCommandBy`를 거쳐 전송으로 해석된다 | ok |
| 전송으로 해석된 Return은 줄바꿈을 넣지 않는다 | ok |
| Shift 경로(=`false` 반환)는 전송하지 않는다 | ok |
| Shift 경로는 줄바꿈을 넣는다 | ok |
| 보낼 수 없는 상태의 Return은 전송도 줄바꿈도 하지 않는다 | ok |
| `insertLineBreak:`를 가로채면 `\n`이 들어간다 | ok |
| 가로챈 `insertLineBreak:`는 U+2028을 넣지 않는다 | ok |
| `setMarkedText:`가 `hasMarkedText()`를 참으로 만든다 | ok |
| 조합 중(`hasMarkedText()`)에는 Return이 전송으로 해석되지 않는다 | ok |

**`insertLineBreak:`의 기본 구현은 U+2028(LINE SEPARATOR)을 넣습니다.** 이
저장소는 SSE 층에서 이미 U+2028 때문에 한 번 다쳤습니다(`AGENTS.md` —
`.lines`가 U+2028에서 줄을 쪼갠다). 프롬프트와 보관 파일에 섞이면 같은 종류의
조용한 어긋남이 생기므로 가로채서 `\n`으로 바꿉니다.

## 6. 확인하지 못한 것 — 정리하지 말고 그대로 둘 것

1. **실제 한글 2벌식 입력기가 조합 중 Return을 어떻게 다루는지.** 자동화된
   IME 입력을 이 환경에서 만들 수 없었습니다. 두 가능성이 있습니다.
   - (a) 입력기가 `insertText:`로 확정한 뒤 Return을 흘려보낸다 →
     `doCommandBy` 시점에 `hasMarkedText()`는 거짓이고 전송이 일어난다.
   - (b) 입력기가 Return을 확정에만 쓰고 삼킨다 → 명령 자체가 오지 않는다.
   - (c) Return이 조합 중인 채로 명령까지 온다 → `hasMarkedText()` 가드가
     걸려 줄바꿈만 일어나고, 사용자는 Return을 한 번 더 눌러야 한다.

   **어느 경우에도 글자는 사라지지 않습니다.** 최악이 (c)의 여분 Return
   한 번입니다. 실기 확인이 되면 이 항목을 갱신하십시오.
2. `.onKeyPress`가 입력기 앞인지 뒤인지. Apple 문서에 없습니다.
3. Shift+Return이 표준 키 바인딩에서 `insertNewline:`으로 오는지
   `insertLineBreak:`으로 오는지. **자료가 갈립니다.** 그래서 둘 다
   처리합니다 — `insertNewline:`은 `NSApp.currentEvent`의 shift로 가르고,
   `insertLineBreak:`은 별도로 받습니다.
4. 일본어·중국어 입력기의 변환 후보 확정. `hasMarkedText()` 가드가 그 경우를
   덮는다고 **가정**했을 뿐 확인하지 않았습니다.

## 7. 벤더의 관례 `[2차]`

Return 전송 / Shift+Return 줄바꿈은 ChatGPT·Claude 웹의 관례로 보고됩니다.
다만 **공식 단축키 문서를 1차로 확인하지 못했습니다** — OpenAI 헬프센터는
403을 돌려주고, 나머지는 3자 정리 사이트입니다.

- [fastshortcuts.com — Claude](https://fastshortcuts.com/shortcuts/claude/)
- [techguruplus — Claude AI Shortcut Keys](https://techguruplus.com/claude-ai-shortcut-keys/)
- [Linuru — Claude Keyboard Shortcuts](https://linuru.com/claude/)

이 자료들이 공통으로 적는 값(교차 확인일 뿐 1차 확인이 아님): Enter 전송 ·
Escape 생성 중단 · `⌘⇧O` 새 대화 · `⌘K` 대화 검색 · `⌘⇧S` 사이드바 토글 ·
`⌘/` 단축키 목록.

한편 Cursor 계열의 관례로 `⌘Return` 전송을 드는 자료도 있습니다
([Setproduct](https://www.setproduct.com/blog/ai-chat-interface-ui-design)).
**둘은 어긋나며 정리하지 않습니다.** 이 앱은 셋을 다 받습니다 —
Return · `⌘Return` · 보내기 버튼.

## 8. macOS 쪽 제약

- `⌃⌘S`는 `NavigationSplitView`의 사이드바 토글로 이미 쓰이고 있습니다.
  상담 목록에는 `⌥⌘S`를 씁니다.
- `⌘.`은 macOS에서 취소의 관례입니다. Escape도 같은 뜻이므로 중단에 둘 다
  받습니다.
- `⌘F`를 어느 화면에서나 잡으면 다른 화면에서 누른 사용자가 상담으로
  끌려갑니다. 상담 화면에 있을 때만 켭니다.
