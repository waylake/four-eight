import SwiftUI
import SajuKit

/// 명식 해석 패널.
struct InterpretationPanel: View {
    let reading: Reading
    @Environment(AppState.self) private var appState
    @Environment(ModelManager.self) private var modelManager
    @Environment(InterpretationStore.self) private var store

    private var key: InterpretationStore.Key {
        InterpretationStore.Key(
            subject: reading.person.id.uuidString,
            signature: reading.chart.signature,
            engine: engineID(appState: appState, modelManager: modelManager)
        )
    }

    var body: some View {
        GenerationSurface(
            key: key,
            sections: reading.sections,
            interpreter: makeInterpreter(
                appState: appState, modelManager: modelManager, facts: reading.facts.summaryLines,
                instructions: GemmaInterpreter.natalInstructions
            ),
            title: "해석",
            emptyHint: "명식 해석을 생성합니다."
        )
    }
}

/// 시간운 해석 패널. 오늘 화면과 캘린더 상세가 공유한다.
struct TimeInterpretationPanel: View {
    let reading: Reading
    let fortune: DayFortune
    @Environment(AppState.self) private var appState
    @Environment(ModelManager.self) private var modelManager

    private var dayKey: String {
        fortune.date.formatted(.iso8601.year().month().day())
    }

    private var key: InterpretationStore.Key {
        InterpretationStore.Key(
            subject: "\(reading.person.id.uuidString)#\(dayKey)",
            signature: reading.chart.signature,
            engine: engineID(appState: appState, modelManager: modelManager)
        )
    }

    var body: some View {
        GenerationSurface(
            key: key,
            sections: fortune.sections,
            interpreter: makeInterpreter(
                appState: appState, modelManager: modelManager, facts: fortune.facts.summaryLines,
                instructions: GemmaInterpreter.timeInstructions
            ),
            title: "풀이",
            emptyHint: "이 날의 기운을 풀어 씁니다."
        )
    }
}

// MARK: - 공통 생성 표면

/// 생성 상태를 다루는 표면. 시작·중단·재개·재생성이 모두 여기에 모인다.
///
/// 상태는 이 뷰가 아니라 InterpretationStore에 있다. 뷰가 사라졌다
/// 나타나도, 인물을 바꿨다 돌아와도 만든 문장은 남는다.
struct GenerationSurface: View {
    let key: InterpretationStore.Key
    let sections: [InterpretationSection]
    let interpreter: any Interpreter
    let title: String
    let emptyHint: String

    @Environment(InterpretationStore.self) private var store
    @Environment(AppState.self) private var appState
    @Environment(ModelManager.self) private var modelManager

    private var document: InterpretationStore.Document { store.document(for: key) }
    private var phase: InterpretationStore.Phase { store.phase(for: key) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statusBar
                if sections.isEmpty {
                    ContentUnavailableView(
                        "해석 규칙 없음",
                        systemImage: "text.book.closed",
                        description: Text("이 명식에 해당하는 규칙이 아직 없습니다. 계산 결과는 정상입니다.")
                    )
                    .padding(.top, 20)
                } else {
                    ForEach(sections) { section in
                        SectionCard(
                            section: section,
                            text: document.sections[section.id]?.text ?? "",
                            isComplete: document.sections[section.id]?.isComplete ?? false,
                            isStreaming: isStreaming(section.id),
                            emptyHint: emptyHint
                        )
                    }
                }
                disclaimer
            }
            .padding(16)
        }
        .navigationTitle(title)
        .onAppear(perform: startIfNeeded)
        .onChange(of: key) { startIfNeeded() }
    }

    private func isStreaming(_ id: String) -> Bool {
        if case .running(let section, _, _) = phase { return section == id }
        return false
    }

    private func startIfNeeded() {
        guard !sections.isEmpty else { return }
        store.ensure(key: key, sections: sections, interpreter: interpreter)
    }

    // MARK: - 상태 표시줄

    @ViewBuilder
    private var statusBar: some View {
        HStack(spacing: 8) {
            engineLabel
            Spacer(minLength: 8)
            controls
        }
        .font(.caption)

        if case .failed(let message) = phase {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(Ink.cinnabar)
                .lineLimit(2)
        }

        if appState.useLLM && !modelManager.isReady {
            modelHint
        }
    }

    private var engineLabel: some View {
        HStack(spacing: 5) {
            switch phase {
            case .running(_, let index, let total):
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                Text("생성 중 \(index)/\(total)")
            case .stopped:
                Image(systemName: "pause.circle")
                Text("중단됨 · \(document.completedCount)/\(document.order.count) 완료")
            case .done:
                Image(systemName: appState.useLLM && modelManager.isReady ? "cpu" : "text.book.closed")
                Text(engineName)
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                Text("생성 실패")
            case .idle:
                Image(systemName: appState.useLLM && modelManager.isReady ? "cpu" : "text.book.closed")
                Text(engineName)
            }
        }
        .foregroundStyle(.secondary)
    }

    private var engineName: String {
        if appState.useLLM, modelManager.isReady, let model = modelManager.activeModel {
            return "\(model.displayName) · 온디바이스"
        }
        return "규칙 엔진"
    }

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .running:
            Button {
                store.stop(key: key)
            } label: {
                Label("중단", systemImage: "stop.fill")
            }
            .controlSize(.small)
            .help("생성을 멈춥니다. 지금까지 만든 문장은 남습니다.")
        case .stopped:
            HStack(spacing: 6) {
                Button {
                    store.resume(key: key, sections: sections, interpreter: interpreter)
                } label: {
                    Label("이어서", systemImage: "play.fill")
                }
                .controlSize(.small)
                .help("남은 섹션부터 이어서 생성합니다.")
                regenerateButton
            }
        case .failed:
            HStack(spacing: 6) {
                Button {
                    store.resume(key: key, sections: sections, interpreter: interpreter)
                } label: {
                    Label("다시 시도", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                regenerateButton
            }
        case .done, .idle:
            regenerateButton
        }
    }

    private var regenerateButton: some View {
        Button {
            store.regenerate(key: key, sections: sections, interpreter: interpreter)
        } label: {
            Label("새로 생성", systemImage: "arrow.clockwise")
        }
        .controlSize(.small)
        .help("처음부터 다시 씁니다.")
    }

    private var modelHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle")
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 해설을 쓰려면 모델을 설치하세요")
                    .font(.callout)
                Text("설정 → 모델에서 Gemma 4를 내려받으면 문장이 자연스러워집니다. 지금도 규칙 엔진 해설은 완전하게 동작합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            SettingsLink { Text("설정") }
                .controlSize(.small)
        }
        .padding(10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    private var disclaimer: some View {
        Text("이 해설은 전통 명리 이론에 근거한 참고용 콘텐츠입니다. 의료·투자·법률 판단의 근거가 될 수 없습니다.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.top, 4)
    }
}

/// 섹션 카드 — 제목, 본문, 근거 칩.
struct SectionCard: View {
    let section: InterpretationSection
    let text: String
    let isComplete: Bool
    let isStreaming: Bool
    let emptyHint: String
    @State private var selectedRule: Rule?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(isComplete ? Ink.cinnabar : Color.secondary.opacity(0.4))
                    .frame(width: 3, height: 14)
                Text(section.title)
                    .font(.headline)
                if isStreaming {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                }
            }

            if text.isEmpty {
                Text(isStreaming ? "쓰는 중…" : emptyHint)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                Text(text)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 근거 칩 — 이 문단이 어떤 명리 규칙에서 왔는가.
            FlowChips {
                ForEach(section.rules) { rule in
                    Button {
                        selectedRule = rule
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "text.magnifyingglass")
                                .font(.system(size: 9))
                            Text(rule.title)
                        }
                        .font(.caption2)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.5), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .paperCard(padding: 14)
        .popover(item: $selectedRule) { rule in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(rule.title)
                        .font(.headline)
                    if let hanja = rule.hanja {
                        Text(hanja)
                            .font(.hanja(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(rule.text)
                    .font(.callout)
                    .lineSpacing(3)
                Text("근거 ID: \(rule.id)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(width: 330)
        }
    }
}

// MARK: - 해석기 선택

@MainActor
func engineID(appState: AppState, modelManager: ModelManager) -> String {
    if appState.useLLM, modelManager.isReady, let id = modelManager.activeModelID {
        return id
    }
    return "template"
}

@MainActor
func makeInterpreter(
    appState: AppState, modelManager: ModelManager,
    facts: [String], instructions: String
) -> any Interpreter {
    if appState.useLLM, let container = modelManager.container {
        return GemmaInterpreter(container: container, facts: facts, instructions: instructions)
    }
    return TemplateInterpreter()
}
