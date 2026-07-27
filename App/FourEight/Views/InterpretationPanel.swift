import SwiftUI
import SajuKit

/// 해석 패널 — 스트리밍 본문 + 근거 칩.
struct InterpretationPanel: View {
    let reading: Reading
    @Environment(AppState.self) private var appState
    @Environment(ModelManager.self) private var modelManager
    @State private var viewModel = InterpretationViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                engineBadge
                ForEach(reading.sections) { section in
                    SectionCard(
                        section: section,
                        text: viewModel.texts[section.id] ?? "",
                        isStreaming: viewModel.streamingSectionID == section.id
                    )
                }
                disclaimer
            }
            .padding(16)
        }
        .navigationTitle("해석")
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.start(reading: reading, modelManager: modelManager, useLLM: appState.useLLM)
                } label: {
                    Label("다시 생성", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isRunning)
                .help("해석을 다시 생성합니다")
            }
        }
        .task(id: taskKey) {
            viewModel.start(reading: reading, modelManager: modelManager, useLLM: appState.useLLM)
        }
    }

    /// 인물·옵션·모델이 바뀌면 재생성.
    private var taskKey: String {
        "\(reading.person.id)-\(reading.chart.compactHanja)-\(modelManager.isReady)-\(appState.useLLM)"
    }

    @ViewBuilder
    private var engineBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: appState.useLLM && modelManager.isReady ? "cpu" : "text.book.closed")
                .font(.caption)
            if appState.useLLM, modelManager.isReady, let model = modelManager.activeModel {
                Text("\(model.displayName) · 온디바이스")
            } else {
                Text("규칙 엔진 해설")
            }
            Spacer()
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(Ink.cinnabar)
                    .lineLimit(1)
                    .help(error)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)

        if appState.useLLM && !modelManager.isReady {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle")
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI 해설을 쓰려면 모델을 설치하세요")
                        .font(.callout)
                    Text("설정 → 모델에서 Gemma 4를 내려받으면 문장이 자연스러워집니다. 지금도 규칙 엔진 해설은 완전하게 동작합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SettingsLink {
                    Text("모델 설정")
                }
                .controlSize(.small)
            }
            .padding(10)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var disclaimer: some View {
        Text("이 해설은 전통 명리 이론에 근거한 참고용 콘텐츠입니다. 의료·투자·법률 판단의 근거가 될 수 없습니다.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.top, 6)
    }
}

/// 섹션 카드 — 제목, 본문, 근거 칩.
struct SectionCard: View {
    let section: InterpretationSection
    let text: String
    let isStreaming: Bool
    @State private var selectedRule: Rule?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Ink.cinnabar)
                    .frame(width: 3, height: 14)
                Text(section.title)
                    .font(.headline)
                if isStreaming {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if text.isEmpty && !isStreaming {
                Text("생성 대기 중…")
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
            .frame(width: 320)
        }
    }
}

/// 해석 스트림 실행기.
@MainActor
@Observable
final class InterpretationViewModel {
    var texts: [String: String] = [:]
    var streamingSectionID: String?
    var isRunning = false
    var errorMessage: String?
    private var task: Task<Void, Never>?

    func start(reading: Reading, modelManager: ModelManager, useLLM: Bool) {
        task?.cancel()
        texts = [:]
        errorMessage = nil
        isRunning = true

        let interpreter: any Interpreter
        if useLLM, let container = modelManager.container {
            interpreter = GemmaInterpreter(container: container)
        } else {
            interpreter = TemplateInterpreter()
        }

        task = Task { [weak self] in
            do {
                for try await chunk in interpreter.stream(reading: reading) {
                    guard let self, !Task.isCancelled else { return }
                    switch chunk {
                    case .sectionStart(let id, _, _):
                        self.streamingSectionID = id
                        self.texts[id] = ""
                    case .text(let id, let delta):
                        self.texts[id, default: ""] += delta
                    case .sectionEnd:
                        self.streamingSectionID = nil
                    case .done:
                        break
                    }
                }
            } catch is CancellationError {
                // 무시 — 새 실행으로 대체됨.
            } catch {
                self?.errorMessage = "생성 실패: \(error.localizedDescription)"
            }
            self?.streamingSectionID = nil
            self?.isRunning = false
        }
    }
}
