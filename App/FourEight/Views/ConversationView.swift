import SwiftUI
import SajuKit

struct ConversationView: View {
    let reading: Reading
    @Environment(AppState.self) private var appState
    @Environment(ModelManager.self) private var modelManager
    @State private var conversation = Conversation()
    @State private var draft = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if modelManager.isReady {
                transcript
                Divider()
                composer
            } else {
                needsModel
            }
        }
        .background(.background)
        .navigationTitle("대화")
        .navigationSubtitle(reading.person.name)
        .toolbar {
            if !conversation.messages.isEmpty {
                ToolbarItem {
                    Button {
                        conversation.clearHistory()
                    } label: {
                        Label("대화 지우기", systemImage: "trash")
                    }
                    .help("대화 내용을 지웁니다. 명식은 그대로입니다.")
                }
            }
        }
        .onAppear(perform: bind)
        .onChange(of: reading.chart.signature) { bind() }
        .onChange(of: modelManager.activeModelID) { bind() }
    }

    private func bind() {
        conversation.bind(
            reading: reading,
            container: modelManager.container,
            engineID: engineID(appState: appState, modelManager: modelManager)
        )
    }

    // MARK: - 대화 내용

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    groundingNote
                    if conversation.messages.isEmpty {
                        suggestionList
                    }
                    ForEach(conversation.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if let error = conversation.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(Ink.cinnabar)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(18)
            }
            .onChange(of: conversation.messages.last?.text) {
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var groundingNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("이 대화는 계산된 명식과 근거 규칙만 참고합니다")
                    .font(.caption)
                Text("근거에 없는 것은 지어내지 않고 모른다고 답합니다. \(reading.sections.flatMap(\.rules).count)개 규칙이 컨텍스트에 들어 있습니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("이런 것을 물어볼 수 있습니다")
                .font(.caption)
                .foregroundStyle(.tertiary)
            ForEach(Conversation.suggestions(for: reading), id: \.self) { suggestion in
                Button {
                    conversation.send(suggestion)
                } label: {
                    HStack {
                        Text(suggestion)
                            .font(.callout)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.circle")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Ink.paper, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(.separator.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 입력

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("명식에 대해 물어보세요", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .onSubmit(submit)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Ink.paper, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(.separator.opacity(0.55), lineWidth: 1)
                )

            if conversation.isResponding {
                Button {
                    conversation.stop()
                } label: {
                    Label("중단", systemImage: "stop.fill")
                }
                .help("답변 생성을 멈춥니다")
            } else {
                Button {
                    submit()
                } label: {
                    Label("보내기", systemImage: "arrow.up")
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
    }

    private func submit() {
        let text = draft
        draft = ""
        conversation.send(text)
    }

    private var needsModel: some View {
        ContentUnavailableView {
            Label("대화에는 모델이 필요합니다", systemImage: "bubble.left.and.text.bubble.right")
        } description: {
            Text("설정 → 모델에서 Gemma 4를 설치하면 명식을 두고 질문할 수 있습니다. 명식과 해석은 모델 없이도 그대로 동작합니다.")
        } actions: {
            SettingsLink { Text("모델 설정 열기") }
        }
    }
}

struct MessageBubble: View {
    let message: Conversation.Message

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.text.isEmpty && !message.isComplete {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small).scaleEffect(0.7)
                        Text("생각하는 중…")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                } else {
                    Text(message.text)
                        .font(.body)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(
                            message.role == .user
                                ? AnyShapeStyle(Ink.cinnabar.opacity(0.11))
                                : AnyShapeStyle(Ink.paper),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(
                                    message.role == .user
                                        ? AnyShapeStyle(.clear)
                                        : AnyShapeStyle(.separator.opacity(0.5)),
                                    lineWidth: 1
                                )
                        )
                }
            }

            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }
}
