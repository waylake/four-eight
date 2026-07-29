import SwiftUI
import AppKit

/// 채팅 입력창.
///
/// `TextField(axis: .vertical)`을 쓰지 않는 이유는 하나다. **Return으로
/// 보낼 수 없다.** SwiftUI의 `onSubmit`은 한 줄짜리 `TextField`·`SecureField`
/// 에서만 발화하고, 여러 줄 필드에서 Return은 줄바꿈으로 소비된다. 그래서
/// 이 저장소는 한동안 `⌘↩`만 두었고, 그것이 이 화면이 채팅처럼 느껴지지
/// 않았던 가장 큰 이유였다.
///
/// 예전 조사는 `NSTextView` 래퍼를 "값이 없다"고 판단했다. 근거는 한글 IME
/// 조합 확정과 Return이 충돌할 위험이었다. 그 판단을 뒤집는다. 이유는 둘이다.
///
/// **첫째, 가로채는 자리가 IME 뒤다.** Cocoa 텍스트 입력 흐름은
/// `keyDown:` → 입력 컨텍스트 → (입력기) → `insertText:` 또는
/// `doCommandBySelector:` 순이다. 조합 중인 글자는 입력기가 `insertText:`로
/// 먼저 확정하고, 그다음에야 `insertNewline:` 명령이 온다. 잘린 글자 사고가
/// 나는 코드는 `keyDown`에서 값을 읽어 가는 코드이지 `doCommandBySelector:`
/// 에서 읽는 코드가 아니다.
///
/// **둘째, 그래도 확신하지 않는다.** `hasMarkedText()`가 참이면 이 Return은
/// 조합을 확정하는 키로 보고 가로채지 않는다. 두 가정 중 어느 쪽이 참이든
/// 사용자의 글자는 사라지지 않는다 — 최악의 경우가 "Return을 한 번 더
/// 눌러야 한다"이고, 그것은 글자를 잃는 것과 비교할 대상이 아니다.
/// 조사 노트는 docs/research/chat-composer.md에 있다.
///
/// 보내는 시점에 값을 다시 읽는 것도 같은 이유다. SwiftUI 바인딩이 아니라
/// `textView.string`을 읽는다. 바인딩이 한 박자 늦으면 마지막 음절이 빠진다.
struct MessageEditor: NSViewRepresentable {
    @Binding var text: String
    /// 내용에 따라 자란 높이. 뷰가 이 값으로 `frame`을 준다.
    @Binding var height: CGFloat
    var maxHeight: CGFloat = 168
    var isEditable: Bool = true
    /// 값이 바뀌면 입력창으로 포커스가 간다. 메뉴 명령과 칩에서 쓴다.
    var focusToken: Int = 0
    /// Return을 보내기로 해석해도 되는가. 거짓이면 Return은 아무 일도 하지 않는다.
    var canSubmit: Bool = true
    var onSubmit: () -> Void = {}
    /// Escape. 생성 중이면 중단이고, 아니면 아무 일도 하지 않는다.
    var onCancel: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        // TextKit 1 스택을 직접 만든다. `NSTextView.scrollableTextView()`가
        // 주는 TextKit 2 뷰에서 `layoutManager`를 건드리면 되돌릴 수 없는
        // 폴백이 일어난다. 높이를 재려면 어차피 필요하므로 처음부터 명시한다.
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(
            size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)

        let textView = NSTextView(frame: .zero, textContainer: container)
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.textContainerInset = NSSize(width: 3, height: 7)
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        // 치환은 전부 끈다. 상담 글에 곧은 따옴표가 굽은 따옴표로 바뀌는
        // 것은 이득이 없고, 한글 입력기와 겹치면 조합이 흔들린다.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.verticalScrollElasticity = .none

        context.coordinator.textView = textView
        // 첫 화면에서 곧바로 적을 수 있어야 한다. 포커스가 없으면 첫 풀이까지
        // 누르는 횟수의 절반이 포커스에만 쓰인다.
        //
        // 창에 붙기 전에는 first responder가 될 수 없으므로 한 박자 뒤에
        // 부른다. 명시적 캡처 목록으로 넘기면 non-Sendable인 `NSTextView`가
        // 격리 경계를 넘는 것으로 잡힌다. 암묵 캡처는 이 Task가 @MainActor
        // 격리를 물려받으므로 안전하다.
        Task { @MainActor in textView.window?.makeFirstResponder(textView) }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        if textView.string != text {
            textView.string = text
        }
        textView.isEditable = isEditable
        if context.coordinator.focusToken != focusToken {
            context.coordinator.focusToken = focusToken
            Task { @MainActor in textView.window?.makeFirstResponder(textView) }
        }
        context.coordinator.pushHeight()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MessageEditor
        var textView: NSTextView?
        var focusToken = 0

        init(_ parent: MessageEditor) {
            self.parent = parent
            self.focusToken = parent.focusToken
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            pushHeight()
        }

        /// 자란 높이를 뷰에 알린다. 같은 값이면 쓰지 않는다 — 갱신 순환을 만든다.
        func pushHeight() {
            guard let textView,
                  let layout = textView.layoutManager,
                  let container = textView.textContainer
            else { return }
            layout.ensureLayout(for: container)
            let used = layout.usedRect(for: container).height
            let wanted = min(
                parent.maxHeight,
                ceil(used) + textView.textContainerInset.height * 2
            )
            guard abs(wanted - parent.height) > 0.5 else { return }
            // 갱신 중에 상태를 바꾸면 SwiftUI가 경고한다. 한 박자 뒤에 쓴다.
            // 같은 값이면 위에서 걸러지므로 순환하지 않는다.
            Task { @MainActor in parent.height = wanted }
        }

        /// Return을 어떻게 읽을지 정하는 유일한 자리.
        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                // ⇧Return은 줄바꿈이다. 두 벤더가 같고, 이것이 없으면
                // 여러 줄을 적을 방법이 사라진다.
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                    return false
                }
                // 입력기가 조합 중이면 이 Return은 조합을 확정하는 키다.
                // 가로채면 사용자의 마지막 음절이 사라진다.
                if textView.hasMarkedText() { return false }
                guard parent.canSubmit else { return true }
                // 바인딩이 아니라 텍스트 뷰에서 다시 읽는다.
                parent.text = textView.string
                parent.onSubmit()
                return true

            case #selector(NSResponder.insertLineBreak(_:)):
                // 기본 구현은 U+2028(line separator)을 넣는다. 보관 파일과
                // 프롬프트에 섞이면 줄 경계를 다루는 층에서 조용히 어긋난다.
                textView.insertText("\n", replacementRange: textView.selectedRange())
                return true

            case #selector(NSResponder.cancelOperation(_:)):
                // 텍스트 뷰의 기본 Escape는 자동 완성 목록이다. 상담 입력창에는
                // 완성할 것이 없고, 생성 중이라면 사용자가 원하는 것은 중단이다.
                parent.onCancel()
                return true

            default:
                return false
            }
        }
    }
}

/// 입력창 한 벌 — 자라는 편집기와 보내기·중단 버튼.
///
/// 두 화면(상담을 여는 화면과 이어가는 화면)이 **같은 컴포저를 쓴다.**
/// 위치가 바뀌면 사용자는 다른 화면에 왔다고 읽는다. 채팅처럼 느껴지려면
/// 적는 자리가 움직이지 않아야 한다.
struct ChatComposer: View {
    @Binding var text: String
    var placeholder: String
    /// 생성 중인가. 참이면 주 버튼이 중단으로 바뀐다.
    var isWriting: Bool
    /// 모델을 불러오는 중인가.
    var isPreparing: Bool
    /// 보내기 버튼의 접근성 라벨 겸 도움말.
    var sendHelp: String
    /// 이 글자 수에 못 미치면 보낼 수 없다. 상담을 여는 첫 글에만 쓴다 —
    /// 두 글자로는 축을 정할 수 없고, 그때 아무 일도 일어나지 않으면
    /// 사용자는 앱이 고장 났다고 읽는다. 흐린 화살표가 그 말을 대신한다.
    var minimumLength: Int = 1
    var focusToken: Int
    var onSubmit: () -> Void
    var onStop: () -> Void

    @State private var height: CGFloat = 34

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool { trimmed.count >= minimumLength && !isWriting && !isPreparing }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 7)
                        .allowsHitTesting(false)
                }
                MessageEditor(
                    text: $text,
                    height: $height,
                    focusToken: focusToken,
                    canSubmit: canSubmit,
                    onSubmit: { if canSubmit { onSubmit() } },
                    onCancel: { if isWriting { onStop() } }
                )
                .frame(height: max(30, height))
            }
            trailing
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Ink.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator.opacity(0.6), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var trailing: some View {
        if isPreparing {
            ProgressView()
                .controlSize(.small)
                .padding(.trailing, 3)
                .padding(.bottom, 3)
                .help("모델을 불러오는 중입니다.")
        } else if isWriting {
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 25, height: 25)
                    .background(Circle().fill(.secondary))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(".", modifiers: .command)
            .help("생성을 멈춥니다. 쓰던 문장은 남습니다. (⌘. 또는 esc)")
            .accessibilityLabel("생성 중단")
        } else {
            Button(action: onSubmit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(canSubmit ? .white : Color.secondary)
                    .frame(width: 25, height: 25)
                    .background(
                        Circle().fill(
                            canSubmit
                                ? AnyShapeStyle(Ink.cinnabar)
                                : AnyShapeStyle(.quaternary)
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .keyboardShortcut(.return, modifiers: .command)
            .help(sendHelp)
            .accessibilityLabel("보내기")
        }
    }
}
