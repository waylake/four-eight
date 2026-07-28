import SwiftUI
import RemoteLLM
import SajuKit

/// 명식 해석 패널.
struct InterpretationPanel: View {
    let reading: Reading

    var body: some View {
        GenerationSurface(
            key: .init(
                subject: reading.person.id.uuidString,
                signature: reading.chart.signature
            ),
            sections: reading.sections,
            facts: reading.facts.summaryLines,
            instructions: InterpretationBrief.natalInstructions,
            title: "해석"
        )
    }
}

/// 시간운 해석 패널. 오늘 화면과 캘린더 상세가 공유한다.
struct TimeInterpretationPanel: View {
    let reading: Reading
    let fortune: DayFortune

    private var dayKey: String {
        fortune.date.formatted(.iso8601.year().month().day())
    }

    var body: some View {
        GenerationSurface(
            key: .init(
                subject: "\(reading.person.id.uuidString)#\(dayKey)",
                signature: reading.chart.signature
            ),
            sections: fortune.sections,
            facts: fortune.facts.summaryLines,
            instructions: InterpretationBrief.timeInstructions,
            title: "풀이"
        )
    }
}

// MARK: - 공통 생성 표면

/// 해석 표면 — 두 층을 함께 보여준다.
///
/// **기준선**: 규칙 엔진이 근거 원문을 조립한 문장. 계산과 함께 나오므로
/// 항상 있고, 공짜이고, 사용자가 아무것도 하지 않아도 완결돼 있다.
///
/// **AI 문장**: 사용자가 버튼을 눌러 주문한 산출물. 있으면 기준선 위에
/// 올라가고, 기준선은 접힌 채로 그 아래 남는다. 없으면 그냥 없다 —
/// 그것이 정상 상태이며, 앱이 알아서 채우지 않는다.
///
/// 이 뷰에는 생성을 시작하는 경로가 `Button` 안에만 있다. `onAppear`와
/// `onChange`는 디스크에서 읽어 오는 `restore`만 부른다.
/// **읽기는 앱이 알아서, 쓰기는 사용자만.**
struct GenerationSurface: View {
    let key: InterpretationStore.Key
    let sections: [InterpretationSection]
    let facts: [String]
    let instructions: String
    let title: String

    @Environment(InterpretationStore.self) private var store
    @Environment(AppState.self) private var appState
    @Environment(Writers.self) private var writers

    /// 이 Mac을 벗어나기 전에 사용자에게 보여줄 전송. 확인 대화상자가
    /// 살아 있는 동안만 존재하므로 뷰의 상태로 두어도 된다.
    @State private var pendingSend: PendingSend?

    private var document: InterpretationStore.Document? { store.document(for: key) }
    private var phase: InterpretationStore.Phase { store.phase(for: key) }
    /// AI 문장을 제시할 수 있는 상태인가. 적재 여부는 묻지 않는다.
    private var aiOffered: Bool { appState.useLLM && writers.isAvailable }

    private var brief: InterpretationBrief {
        InterpretationBrief(facts: facts, instructions: instructions)
    }

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
                            generated: document?.text(for: section.id),
                            isStreaming: isStreaming(section.id)
                        )
                    }
                }
                disclaimer
            }
            .padding(16)
        }
        .navigationTitle(title)
        // 읽기만 한다. 이 경로에서 생성이 시작되는 일은 없다.
        .onAppear { store.restore(key: key) }
        .onChange(of: key) { store.restore(key: key) }
        .sheet(item: $pendingSend) { send in
            OutboundDisclosure(
                destination: send.destination,
                model: send.model,
                system: send.system,
                user: send.user,
                summary: send.summary,
                onConfirm: {
                    // 확인은 이 호스트에 대해 남는다. 매번 물으면 사용자는
                    // 읽지 않고 누르는 법을 배운다.
                    if let host = send.destination.host {
                        writers.remote.acknowledge(host: host)
                    }
                    pendingSend = nil
                    send.run()
                },
                onCancel: { pendingSend = nil }
            )
        }
    }

    /// 생성을 요청한다. 이 Mac을 벗어나는 첫 요청이면 무엇이 나가는지 먼저 보여준다.
    ///
    /// 관문을 여기 두는 것이 중요하다. 설정 화면에 두면 읽히지 않고,
    /// `store` 안에 두면 화면이 없는 곳에서 결정하게 된다.
    private func requestGeneration(resuming: Bool) {
        let start = {
            if resuming {
                store.resume(key: key, sections: sections, supplier: supplier)
            } else {
                store.generate(key: key, sections: sections, supplier: supplier)
            }
        }
        guard writers.needsAcknowledgement,
              let first = sections.first,
              let config = writers.remote.config
        else { start(); return }

        pendingSend = PendingSend(
            destination: config.destination,
            model: config.model,
            system: brief.instructions,
            user: brief.promptText(for: first, includesFacts: true),
            summary: [
                "계산이 끝난 명식 사실 \(facts.count)줄",
                "이 섹션의 근거 원문 \(first.rules.count)개",
                "섹션은 \(sections.count)개이므로 요청도 \(sections.count)번 나갑니다",
            ],
            run: start
        )
    }

    private func isStreaming(_ id: String) -> Bool {
        if case .running(let section, _, _) = phase { return section == id }
        return false
    }

    // MARK: - 상태 표시줄

    @ViewBuilder
    private var statusBar: some View {
        HStack(spacing: 8) {
            provenanceLabel
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

        if let document, document.provenance.ruleSetVersion != SajuService.ruleSet.version {
            // 근거 문장이 그 사이 바뀌었다. 조용히 지우지 않고 사용자에게
            // 판단을 넘긴다 — 이미 읽은 문장이 이유 없이 달라지는 것이
            // 더 나쁘다.
            Label(
                "이 문장은 근거 \(String(document.provenance.ruleSetVersion))판으로 쓰였습니다. 지금 근거는 \(String(SajuService.ruleSet.version))판입니다.",
                systemImage: "clock.arrow.circlepath"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }

        if appState.useLLM, !writers.isAvailable {
            writerHint
        }
    }

    /// 이 화면의 문장이 무엇으로 쓰였는지. **기록에서 읽는다.**
    /// 현재 설정에서 추측하면, 설정을 바꾼 순간 이미 있는 문장의 출처가
    /// 거짓으로 표시된다.
    private var provenanceLabel: some View {
        HStack(spacing: 5) {
            switch phase {
            case .preparingModel:
                ProgressView().controlSize(.small).scaleEffect(0.7)
                Text("모델을 불러오는 중…")
            case .running(_, let index, let total):
                ProgressView().controlSize(.small).scaleEffect(0.7)
                Text("쓰는 중 \(index)/\(total)")
            case .stopped:
                Image(systemName: "pause.circle")
                Text("중단됨 · \(document?.completedCount ?? 0)/\(sections.count) 섹션")
            case .idle, .done, .failed:
                if let document, document.isComplete {
                    // 목적지는 **기록**에서 읽는다. 지금 설정에서 뽑으면
                    // 설정을 바꾼 순간 이미 있는 문장이 다른 곳에서 온 것으로
                    // 표시된다. 그리고 섹션마다 다를 수 있으므로 문서가
                    // 실제로 거쳐 간 곳을 모두 적는다.
                    let places = document.destinations
                    Image(systemName: document.anySectionLeftMachine
                        ? "arrow.up.forward.square" : "cpu")
                    Text("\(document.provenance.modelName) · \(places.map(\.label).joined(separator: ", ")) · \(document.provenance.writtenAt.formatted(date: .abbreviated, time: .shortened))에 씀")
                } else {
                    Image(systemName: "text.book.closed")
                    Text("근거 원문 해설")
                }
            }
        }
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .preparingModel:
            EmptyView()
        case .running:
            Button {
                store.stop(key: key)
            } label: {
                Label("중단", systemImage: "stop.fill")
            }
            .controlSize(.small)
            .help("생성을 멈춥니다. 지금까지 만든 문장은 남습니다.")
        case .stopped, .failed:
            if aiOffered {
                HStack(spacing: 6) {
                    Button {
                        requestGeneration(resuming: true)
                    } label: {
                        Label("이어서", systemImage: "play.fill")
                    }
                    .controlSize(.small)
                    .help("남은 섹션부터 이어서 씁니다.")
                    discardButton
                }
            }
        case .idle, .done:
            if aiOffered {
                HStack(spacing: 6) {
                    Button {
                        requestGeneration(resuming: false)
                    } label: {
                        Label(document == nil ? "AI로 다시 쓰기" : "새로 쓰기", systemImage: "wand.and.stars")
                    }
                    .controlSize(.small)
                    .help(generateHelp)
                    if document != nil { discardButton }
                }
            }
        }
    }

    private var discardButton: some View {
        Button {
            store.discardDocument(key: key)
        } label: {
            Label("AI 문장 버리기", systemImage: "trash")
        }
        .controlSize(.small)
        .help("AI가 쓴 문장을 지웁니다. 근거 원문 해설은 그대로 남습니다.")
    }

    /// 버튼 설명. "모델을 불러온다"는 말은 원격에서는 사실이 아니다.
    private var generateHelp: String {
        if writers.needsLoadBeforeUse {
            return "모델을 불러온 뒤 근거를 문장으로 엮습니다. 처음 한 번은 몇 초 더 걸립니다."
        }
        if writers.plannedToLeaveMachine, let host = writers.plannedDestination.host {
            return "근거를 \(host)로 보내 문장으로 엮습니다."
        }
        return "근거를 문장으로 엮습니다."
    }

    private var writerHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
            VStack(alignment: .leading, spacing: 2) {
                Text("AI로 다시 쓰려면 쓸 곳을 고르세요")
                    .font(.callout)
                Text(writers.problem ?? "설정 → 해석에서 이 Mac의 Gemma를 내려받거나 OpenAI 호환 제공자를 지정하면, 같은 근거를 매끄러운 문장으로 엮습니다. 지금 보이는 해설도 그대로 완전합니다.")
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

    /// 생성 재료를 준비하는 쪽. 모델 적재나 키체인 읽기가 여기서
    /// 일어나므로, 사용자가 설정 화면에 다시 갈 이유가 없다.
    ///
    /// 출처를 여기서 만들지 않는다. `Writers`가 한 곳에서 만든다 —
    /// 화면마다 손으로 만들면 항목이 하나 늘 때 어딘가에서 빠지고,
    /// 목적지는 빠뜨리면 사용자가 글이 나간 것을 모르게 되는 항목이다.
    private var supplier: InterpretationStore.Supplier {
        let writers = writers
        let brief = brief
        return { await writers.prepareInterpreter(brief: brief) }
    }
}

/// 섹션 카드 — 제목, 본문, 근거 칩.
///
/// 본문은 한 자리다. AI 문장이 있으면 그것이 본문이고 기준선은 접혀서
/// 아래 남는다. 두 텍스트가 같은 자리를 다투게 두면 사용자는 지금 무엇을
/// 읽고 있는지 모른다.
struct SectionCard: View {
    let section: InterpretationSection
    let generated: String?
    let isStreaming: Bool
    @State private var selectedRule: Rule?
    @State private var showsBaseline = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(generated == nil ? Color.secondary.opacity(0.4) : Ink.cinnabar)
                    .frame(width: 3, height: 14)
                Text(section.title)
                    .font(.headline)
                if isStreaming {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                }
            }

            Text(generated ?? section.baselineText)
                .font(.body)
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if generated != nil {
                DisclosureGroup(isExpanded: $showsBaseline) {
                    Text(section.baselineText)
                        .font(.callout)
                        .lineSpacing(3)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                } label: {
                    Text("근거 원문 해설")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
