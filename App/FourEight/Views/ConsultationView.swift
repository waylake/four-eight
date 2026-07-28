import SwiftUI
import UniformTypeIdentifiers
import SajuKit

/// 상담 화면.
///
/// 예전 화면은 빈 채팅창이었다. 추천 질문 몇 개와 입력창을 주고 사용자가
/// 무엇을 물을지 알아내게 했다. 명리 상담의 실제 형식은 그렇지 않다 —
/// 먼저 사정을 듣고, 무엇에 대한 이야기인지 정하고, 그 축의 근거로
/// 되돌려준다.
///
/// 그래서 화면의 단위를 메시지에서 **상담 한 건**으로 바꿨다. 왼쪽에
/// 지난 상담이 쌓이고, 오른쪽에서 한 건을 이어간다. 상담을 여는 것과
/// 풀이를 받는 것은 다른 행위다 — 여는 것은 0초에 끝나고 모델이 필요
/// 없으며, 풀이는 사용자가 버튼을 눌러야 시작된다.
struct ConsultationView: View {
    let reading: Reading
    @Environment(AppState.self) private var appState
    @Environment(ConsultationStore.self) private var store

    private var hasHistory: Bool {
        !store.consultations(for: reading.person.id).isEmpty
    }

    var body: some View {
        Group {
            // 지난 상담이 없으면 목록 칸도 없다. 빈 칸이 한 열을 차지하면
            // 정작 고민을 적을 자리가 좁아진다.
            if hasHistory {
                HSplitView {
                    ConsultationListPane(reading: reading)
                        .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)
                    detail
                        .frame(minWidth: 420, idealWidth: 620)
                }
            } else {
                detail
            }
        }
        .navigationTitle("상담")
        .navigationSubtitle(reading.person.name)
        // 읽기만 한다. 생성은 버튼에서만 시작된다.
        .onAppear { store.restore(personID: reading.person.id) }
        .onChange(of: reading.person.id) { store.restore(personID: reading.person.id) }
    }

    @ViewBuilder
    private var detail: some View {
        if let id = appState.selectedConsultationID, let consultation = store.consultation(id: id),
           consultation.personID == reading.person.id {
            ConsultationDetail(reading: reading, consultation: consultation)
        } else {
            NewConsultationPane(reading: reading)
        }
    }
}

// MARK: - 지난 상담

struct ConsultationListPane: View {
    let reading: Reading
    @Environment(AppState.self) private var appState
    @Environment(ConsultationStore.self) private var store

    private var items: [Consultation] { store.consultations(for: reading.person.id) }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    Button {
                        appState.selectedConsultationID = nil
                    } label: {
                        Label("새 상담", systemImage: "plus.bubble")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(appState.selectedConsultationID == nil ? Ink.cinnabar : .primary)
                }
                if !items.isEmpty {
                    Section("지난 상담") {
                        ForEach(items) { item in
                            row(item)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func row(_ item: Consultation) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.headline)
                .font(.callout)
                .lineLimit(2)
            HStack(spacing: 5) {
                Text(item.topic.title)
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Ink.cinnabar.opacity(0.12), in: Capsule())
                    .foregroundStyle(Ink.cinnabar)
                Text(item.openedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if item.awaitsFirstAnswer {
                    Text("풀이 전")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            // 명식 서명이 다르면 그때와 지금의 근거가 다르다. 숨기지 않는다.
            if item.signature != reading.chart.signature {
                Text("유파 설정이 달라진 뒤의 명식입니다")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { appState.selectedConsultationID = item.id }
        .listRowBackground(
            appState.selectedConsultationID == item.id
                ? Ink.cinnabar.opacity(0.08) : Color.clear
        )
        .contextMenu {
            Button("상담 삭제", role: .destructive) {
                if appState.selectedConsultationID == item.id {
                    appState.selectedConsultationID = nil
                }
                store.delete(id: item.id)
            }
        }
    }
}

// MARK: - 새 상담

/// 고민을 받는 화면.
///
/// 여기서 모델은 한 번도 호출되지 않는다. 안전 선별, 축 라우팅, 근거 선별,
/// 되묻기까지 전부 결정론적으로 끝난다. 모델을 내려받지 않은 사용자도
/// 상담을 시작할 수 있고, 되묻기까지 받을 수 있다.
struct NewConsultationPane: View {
    let reading: Reading
    @Environment(AppState.self) private var appState
    @Environment(ConsultationStore.self) private var store

    @State private var concern = ""
    @State private var chosenTopic: ConsultationTopic?
    @State private var crisis: [String]?
    @State private var needsTopicChoice = false

    private var timeFacts: FactSet {
        SajuService.fortune(on: Date(), reading: reading).facts
    }

    private var availableTopics: [ConsultationTopic] {
        ConsultationRouter.availableTopics(
            facts: reading.facts, timeFacts: timeFacts, ruleSet: SajuService.ruleSet
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let crisis {
                    CrisisCard(matched: crisis) { self.crisis = nil }
                } else {
                    editor
                    if needsTopicChoice { topicChooser }
                    topicOverview
                }
                groundingNote
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("무엇이 마음에 걸리십니까")
                .font(.title3.weight(.semibold))
            Text("있는 그대로 적어 주세요. 앱이 어떤 명리 축의 이야기인지 먼저 정하고, 그 축의 근거만 가지고 풀이합니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $concern)
                .font(.body)
                .frame(minHeight: 108)
                .padding(8)
                .background(Ink.paper, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(.separator.opacity(0.55), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if concern.isEmpty {
                        Text("예: 지금 회사를 계속 다녀야 할지 몇 달째 마음이 왔다 갔다 합니다.")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
            HStack {
                if let chosenTopic {
                    Label("\(chosenTopic.title)으로 봅니다", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("상담 열기") { open() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(concern.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)
            }
        }
    }

    /// 라우팅이 실패했을 때. 아무 축이나 골라 답하지 않고 사용자에게 묻는다.
    private var topicChooser: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("어떤 축으로 읽을지 정하지 못했습니다", systemImage: "questionmark.circle")
                .font(.callout)
            Text("적어 주신 글에서 명리 축을 찾지 못했습니다. 짐작으로 고르면 엉뚱한 근거로 답하게 되므로, 직접 골라 주시면 그 축으로 읽겠습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
            FlowChips {
                ForEach(availableTopics) { topic in
                    Button {
                        chosenTopic = topic
                        needsTopicChoice = false
                        open()
                    } label: {
                        Text(topic.title)
                            .font(.caption)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(.quaternary.opacity(0.5), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Ink.cinnabar.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    }

    /// 이 명식에서 실제로 이야기할 수 있는 축.
    /// 답할 수 없는 주제를 권하지 않는 것이 정직하다.
    private var topicOverview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("이 명식에서 이야기할 수 있는 축")
                .font(.caption)
                .foregroundStyle(.tertiary)
            FlowChips {
                ForEach(availableTopics) { topic in
                    HStack(spacing: 4) {
                        Text(topic.title)
                        Text(topic.axis)
                            .foregroundStyle(.tertiary)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.4), in: Capsule())
                }
            }
            let missing = Set(ConsultationTopic.allCases).subtracting(availableTopics)
            if !missing.isEmpty {
                Text("이 명식에는 \(missing.map(\.title).sorted().joined(separator: ", ")) 쪽 근거가 성립하지 않아 권하지 않습니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var groundingNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("이 상담은 계산된 명식과 근거 규칙만 봅니다")
                        .font(.caption)
                    Text("근거에 없는 것은 지어내지 않고 모른다고 답합니다. 답변마다 어떤 규칙에서 나왔는지 표시됩니다. 적어 주신 글은 이 Mac을 벗어나지 않습니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            AIDisclosure()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }

    /// 상담을 연다. 모델은 부르지 않는다.
    private func open() {
        let text = concern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 4 else { return }

        // 안전 선별이 모델보다 먼저다.
        switch SafetyScreen.evaluate(text) {
        case .crisis(let matched):
            // 기록을 만들지 않는다. 위기의 순간이 목록에 남아 있는 것은
            // 도움이 되지 않고, 사용자가 저장을 요청한 것도 아니다.
            crisis = matched
            return
        case .outOfScope(let matched):
            openConsultation(text: text, scopeNote: matched)
        case .clear:
            openConsultation(text: text, scopeNote: nil)
        }
    }

    private func openConsultation(text: String, scopeNote: [String]?) {
        let matches = ConsultationRouter.classify(text)
        let available = availableTopics
        let topic = chosenTopic
            ?? matches.first(where: { available.contains($0.topic) })?.topic
        guard let topic else {
            needsTopicChoice = true
            return
        }
        let evidence = ConsultationRouter.evidence(
            for: topic, facts: reading.facts, timeFacts: timeFacts, ruleSet: SajuService.ruleSet
        )

        var opening: [Consultation.Turn] = []
        if scopeNote != nil {
            opening.append(.init(
                speaker: .app,
                text: "적어 주신 내용에는 진단·법률·투자 판단에 해당하는 부분이 있습니다. 그 부분은 이 앱이 답할 수 없고, 해당 분야의 전문가에게 물으셔야 합니다. 명식으로 읽을 수 있는 부분만 이어서 보겠습니다."
            ))
        }
        opening.append(.init(speaker: .app, text: topic.clarifier))

        let consultation = store.open(
            personID: reading.person.id,
            signature: reading.chart.signature,
            concern: text,
            topic: topic,
            matchedTerms: matches.first(where: { $0.topic == topic })?.matchedTerms ?? [],
            evidenceIDs: evidence.map(\.id),
            includesToday: topic == .timing || topic == .wellbeing,
            opening: opening
        )
        concern = ""
        chosenTopic = nil
        needsTopicChoice = false
        appState.selectedConsultationID = consultation.id
    }
}

/// AI 고지.
///
/// 이 문장은 장식이 아니다. 규제가 요구하는 최소치이고, 이 앱의 정직성
/// 주장과도 맞물린다.
///
/// - EU AI Act Article 50(1): 사람과 상호작용하는 AI 시스템은 사용자가
///   AI와 대화하고 있다는 사실을 알 수 있게 설계돼야 한다(2026-08-02 적용).
/// - Utah Code 13-72a-203: 기능에 접근하기 **전에** 사람이 아니라 AI임을
///   명확히 고지해야 한다.
/// - Nevada AB 406 §7: 전문 정신·행동 건강 치료를 제공할 수 있다고
///   표현하거나 "therapist" 류의 호칭을 쓰지 못한다.
///
/// 그래서 배너를 7일마다 띄우는 방식을 쓰지 않았다. **항상 보이는 한 줄**이
/// 요건보다 강하고 사용자에게도 낫다.
///
/// 출처와 조문은 docs/research/consultation-safety.md에 있다.
struct AIDisclosure: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "cpu")
                .foregroundStyle(.secondary)
            Text("풀이는 이 Mac에서 돌아가는 AI 모델이 씁니다. 사람이 아니고, 심리 상담이나 치료가 아니며, 면허 있는 전문가의 도움을 대체하지 않습니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}

/// 위기 표현이 걸렸을 때.
///
/// 모델을 부르지 않는다. 이 화면의 문장은 전부 고정되어 있고 생성되지
/// 않는다. 명리 해석으로 답할 자리가 아니다.
///
/// 이 화면이 존재하는 이유는 규제 요건(캘리포니아 SB 243 §22602(b)는
/// 자살관념·자해 관련 프로토콜과 위기 서비스 연계 고지를 요구한다)만이
/// 아니다. OpenAI가 직접 밝혔듯 **긴 대화에서는 모델의 안전 학습이 열화된다**
/// — 처음에는 핫라인을 안내하다가 여러 턴 뒤에는 안전장치를 어기는 답을
/// 내놓는다. 그 판단을 모델에 두면 안 되는 이유가 그것이다.
struct CrisisCard: View {
    let matched: [String]
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("지금은 명식보다 사람이 필요한 이야기입니다", systemImage: "heart.circle")
                .font(.headline)
            Text("적어 주신 글에서 많이 힘든 상태가 느껴집니다. 이런 이야기에 사주 풀이로 답하는 것은 도움이 되지 않는다고 생각합니다. 지금 바로 사람과 이야기하실 수 있는 곳을 적어 둡니다.")
                .font(.callout)
                .lineSpacing(3)
            VStack(alignment: .leading, spacing: 6) {
                contact("자살예방 상담전화", "109", "전화·문자, 24시간")
                contact("자살예방 상담전화", "1393", "24시간")
                contact("정신건강 위기상담", "1577-0199", "24시간")
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            // 번호를 하나로 정리하지 않는다. 109가 2024년 통합 번호로
            // 알려져 있으나, 한국생명존중희망재단은 1393과 1577-0199를
            // 함께 안내하고 있다. 어느 쪽이 옳은지 확정하지 못한 상태에서
            // 하나만 적으면 연결되지 않는 번호를 적을 위험이 있다.
            Text("어느 번호로 걸어도 됩니다. 통합 번호(109)와 기존 번호가 함께 안내되고 있습니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("이 글은 저장하지 않았습니다. 이 Mac 밖으로도 나가지 않았습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("돌아가기", action: onDismiss)
            }
        }
        .padding(16)
        .background(Ink.cinnabar.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Ink.cinnabar.opacity(0.25), lineWidth: 1)
        )
    }

    private func contact(_ name: String, _ number: String, _ note: String) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.callout)
            Text(number)
                .font(.callout.monospacedDigit().weight(.semibold))
                .textSelection(.enabled)
            Text(note)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 상담 상세

struct ConsultationDetail: View {
    let reading: Reading
    let consultation: Consultation

    @Environment(AppState.self) private var appState
    @Environment(ConsultationStore.self) private var store
    @Environment(ModelManager.self) private var modelManager

    @State private var followUp = ""
    @State private var selectedRule: Rule?
    @State private var isExporting = false

    private var phase: ConsultationStore.Phase { store.phase(of: consultation.id) }
    private var aiOffered: Bool { appState.useLLM && modelManager.isAvailable }
    private var evidence: [Rule] {
        let ids = Set(consultation.evidenceIDs)
        return SajuService.ruleSet.rules.filter { ids.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            transcript
            Divider()
            composer
        }
        .background(.background)
        .toolbar {
            ToolbarItem {
                Button {
                    isExporting = true
                } label: {
                    Label("내보내기", systemImage: "square.and.arrow.up")
                }
                .help("이 상담을 마크다운 파일로 저장합니다. 근거 ID까지 함께 나갑니다.")
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: MarkdownDocument(text: markdown()),
            contentType: .plainText,
            defaultFilename: "상담-\(consultation.openedAt.formatted(.iso8601.year().month().day()))"
        ) { _ in }
        .popover(item: $selectedRule) { rule in
            VStack(alignment: .leading, spacing: 8) {
                Text(rule.title).font(.headline)
                Text(rule.text).font(.callout).lineSpacing(3)
                Text("근거 ID: \(rule.id)").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(width: 330)
        }
    }

    // MARK: 기록

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    axisHeader
                    concernCard
                    ForEach(consultation.turns) { turn in
                        TurnBubble(
                            turn: turn,
                            provenance: turn.speaker == .counselor ? consultation.provenance : nil,
                            evidence: turn.speaker == .counselor ? evidence : [],
                            onRule: { selectedRule = $0 }
                        )
                        .id(turn.id)
                    }
                    if case .failed(let message) = phase {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(Ink.cinnabar)
                    }
                    contextNote
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(18)
                .frame(maxWidth: 760, alignment: .leading)
            }
            .onChange(of: consultation.turns.last?.text) {
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    /// 무엇을 어떤 축으로 읽고 있는지, 왜 그렇게 읽었는지.
    private var axisHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(
                        ConsultationRouter.availableTopics(
                            facts: reading.facts, ruleSet: SajuService.ruleSet
                        )
                    ) { topic in
                        Button(topic.title) { retopic(to: topic) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(consultation.topic.title)
                        Image(systemName: "chevron.down").font(.system(size: 8))
                    }
                    .font(.caption.weight(.medium))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("축을 바꾸면 근거가 함께 바뀝니다")

                Text(consultation.topic.axis)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Toggle(isOn: Binding(
                    get: { consultation.includesToday },
                    set: { store.setIncludesToday($0, for: consultation.id) }
                )) {
                    Text("오늘 기운 함께")
                        .font(.caption2)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
            }

            if !consultation.matchedTerms.isEmpty {
                Text("‘\(consultation.matchedTerms.joined(separator: "’, ‘"))’를 보고 이 축으로 읽었습니다.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // 이 상담이 쓰는 근거. 답을 받기 전에 미리 볼 수 있다.
            FlowChips {
                ForEach(evidence) { rule in
                    Button { selectedRule = rule } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "text.magnifyingglass").font(.system(size: 9))
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
        .padding(12)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 9))
    }

    private var concernCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("적어 주신 고민")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(consultation.concern)
                .font(.body)
                .lineSpacing(3)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 12)
    }

    /// 무엇을 보고 있고 무엇을 기억하지 않는지.
    /// 기억하는 척하지 않는 것이 4B 모델을 쓰는 앱의 정직함이다.
    private var contextNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("이 상담은 근거 \(evidence.count)개와 최근 발언 \(Counselor.recentTurnWindow)개를 봅니다.")
                Text("그 밖의 것은 기억하지 않습니다. 턴이 길어지면 근거에서 멀어지므로, 다른 고민은 새 상담으로 여는 편이 정확합니다.")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            AIDisclosure()
        }
        .padding(.top, 4)
    }

    // MARK: 입력

    @ViewBuilder
    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if consultation.counselorTurnCount >= 4 {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text("이 상담이 길어졌습니다. 새 고민은 새 상담으로 여시면 근거가 더 정확합니다.")
                    Spacer(minLength: 0)
                    Button("새 상담") { appState.selectedConsultationID = nil }
                        .controlSize(.small)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if !aiOffered {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("풀이를 받으려면 모델을 고르세요")
                            .font(.callout)
                        Text("설정 → 모델에서 Gemma 4를 내려받으면 이 근거로 풀이를 씁니다. 축과 근거는 이미 정해져 있으므로 그대로 남습니다.")
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

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    consultation.awaitsFirstAnswer
                        ? "되물음에 답하거나 사정을 덧붙여 주세요"
                        : "이어서 물으실 것을 적어 주세요",
                    text: $followUp, axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Ink.paper, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(.separator.opacity(0.55), lineWidth: 1)
                )
                .disabled(phase == .writing)

                controls
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .preparingModel:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("모델을 불러오는 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .writing:
            Button {
                store.stop(id: consultation.id)
            } label: {
                Label("중단", systemImage: "stop.fill")
            }
            .help("쓰던 문장은 남습니다.")
        case .idle, .stopped, .failed:
            HStack(spacing: 6) {
                // 덧붙이는 말만 남기는 것도 하나의 행위다. 모델을 부르지 않는다.
                if !followUp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("적어만 두기") {
                        store.addPersonTurn(followUp, to: consultation.id)
                        followUp = ""
                    }
                    .controlSize(.small)
                    .help("모델을 부르지 않고 사정만 기록합니다.")
                }
                if aiOffered {
                    Button {
                        let text = followUp
                        followUp = ""
                        store.answer(id: consultation.id, followUp: text, supplier: supplier)
                    } label: {
                        Label(
                            consultation.awaitsFirstAnswer ? "풀이 받기" : "이어 묻기",
                            systemImage: "wand.and.stars"
                        )
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .help(
                        modelManager.needsLoadBeforeUse
                            ? "모델을 불러온 뒤 이 근거로 풀이를 씁니다. 처음 한 번은 몇 초 더 걸립니다."
                            : "이 근거로 풀이를 씁니다."
                    )
                }
            }
        }
    }

    private func retopic(to topic: ConsultationTopic) {
        let evidence = ConsultationRouter.evidence(
            for: topic, facts: reading.facts, ruleSet: SajuService.ruleSet
        )
        store.retopic(consultation.id, topic: topic, evidenceIDs: evidence.map(\.id))
    }

    /// 답변 재료. 모델 적재가 여기서 일어난다.
    private var supplier: ConsultationStore.Supplier {
        let manager = modelManager
        let facts = reading.facts.summaryLines
        let today = consultation.includesToday
            ? SajuService.fortune(on: Date(), reading: reading).facts.summaryLines
            : nil
        let topic = consultation.topic
        let rules = evidence
        return {
            guard let container = await manager.prepare(),
                  let model = manager.preferredModel
            else { return nil }
            return (
                Counselor(
                    container: container, facts: facts, todayFacts: today,
                    topic: topic, evidence: rules
                ),
                InterpretationStore.Provenance(
                    modelID: model.id,
                    modelName: model.displayName,
                    writtenAt: Date(),
                    appVersion: AppVersion.marketing,
                    ruleSetVersion: SajuService.ruleSet.version
                )
            )
        }
    }

    /// 내보내기 — 근거 ID까지 함께 나간다. 나중에 이 문장이 어디서
    /// 나왔는지 앱 없이도 추적할 수 있어야 한다.
    private func markdown() -> String {
        var out = "# 상담 기록 — \(consultation.topic.title)\n\n"
        out += "- 인물: \(reading.person.name)\n"
        out += "- 명식: \(reading.chart.compactHanja)\n"
        out += "- 축: \(consultation.topic.axis)\n"
        out += "- 연 날짜: \(consultation.openedAt.formatted(date: .long, time: .shortened))\n"
        if let p = consultation.provenance {
            out += "- 풀이: \(p.modelName), 근거 \(String(p.ruleSetVersion))판, 앱 \(p.appVersion)\n"
        }
        out += "\n## 고민\n\n\(consultation.concern)\n"
        out += "\n## 근거\n\n"
        for rule in evidence {
            out += "- **\(rule.title)** (`\(rule.id)`) — \(rule.text)\n"
        }
        out += "\n## 주고받은 말\n\n"
        for turn in consultation.turns {
            // 호칭에 "상담사"·"치료" 계열 말을 쓰지 않는다. 모델이 전문
            // 상담을 제공한다는 표현은 규제상으로도 사실로도 옳지 않다.
            let who = switch turn.speaker {
            case .person: "적은 말"
            case .counselor: "명리 풀이 (AI 모델)"
            case .app: "앱이 확정한 말"
            }
            out += "**\(who)** — \(turn.text)\n\n"
        }
        out += "---\n\n이 기록은 참고용이며 의료·투자·법률 판단의 근거가 될 수 없습니다.\n"
        return out
    }
}

// MARK: - 말풍선

struct TurnBubble: View {
    let turn: Consultation.Turn
    let provenance: InterpretationStore.Provenance?
    let evidence: [Rule]
    let onRule: (Rule) -> Void

    var body: some View {
        switch turn.speaker {
        case .app:
            // 앱이 결정론적으로 말한 것. 모델의 말과 다르게 보여야 한다.
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "text.book.closed")
                    .foregroundStyle(.secondary)
                Text(turn.text)
                    .font(.callout)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 9))
        case .person:
            HStack {
                Spacer(minLength: 56)
                Text(turn.text)
                    .font(.body)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(
                        Ink.cinnabar.opacity(0.11),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
            }
        case .counselor:
            VStack(alignment: .leading, spacing: 6) {
                if turn.text.isEmpty && !turn.isComplete {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small).scaleEffect(0.7)
                        Text("근거를 읽고 쓰는 중…")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text(turn.text)
                        .font(.body)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if turn.isComplete {
                    HStack(spacing: 6) {
                        if let provenance {
                            Text("\(provenance.modelName) · \(provenance.writtenAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(13)
            .paperCard(padding: 13)
            .padding(.trailing, 40)
        }
    }
}

/// 내보내기용 문서. 마크다운을 텍스트로 쓴다.
struct MarkdownDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText]
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
