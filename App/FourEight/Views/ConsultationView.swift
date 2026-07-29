import SwiftUI
import RemoteLLM
import UniformTypeIdentifiers
import SajuKit

/// 상담 화면.
///
/// 예전 판은 화면이 둘이었다. 고민을 받는 **폼**(제목 + 큰 편집기 + "상담
/// 열기" 버튼 + 잔글씨 네 줄)과, 열린 뒤의 **기록 화면**(고정 머리 + 기록 +
/// 컴포저). 같은 기능인데 적는 자리가 화면 가운데에서 화면 바닥으로
/// 옮겨 갔고, 버튼 이름도 바뀌었다. 사용자는 그것을 "다른 화면으로
/// 넘어갔다"고 읽는다.
///
/// 이 판은 화면이 하나다. **컴포저는 항상 같은 자리에 있고 움직이지
/// 않는다.** 처음 적은 글은 상담을 열고, 그다음 글은 풀이를 부른다.
/// 무엇이 일어나는지는 컴포저 위아래의 한 줄이 말한다.
///
/// 상담이라는 단위는 그대로다(ADR 0010). 바뀐 것은 그 단위를 사용자에게
/// 보여주는 방식이지 단위 자체가 아니다 — 축은 여전히 결정론적으로 정해지고,
/// 근거는 여전히 답 앞에 있고, 위기 선별은 여전히 모델 앞에 있다.
struct ConsultationView: View {
    let reading: Reading
    @Environment(AppState.self) private var appState
    @Environment(ConsultationStore.self) private var store

    private var history: [Consultation] {
        store.consultations(for: reading.person.id)
    }

    private var current: Consultation? {
        guard let id = appState.selectedConsultationID,
              let found = store.consultation(id: id),
              found.personID == reading.person.id
        else { return nil }
        return found
    }

    private var showsList: Bool {
        !history.isEmpty && appState.showsConsultationList
    }

    var body: some View {
        Group {
            // 지난 상담이 없으면 목록 칸도 없다. 빈 칸이 한 열을 차지하면
            // 정작 고민을 적을 자리가 좁아진다.
            if showsList {
                HSplitView {
                    ConsultationListPane(reading: reading)
                        .frame(minWidth: 200, idealWidth: 244, maxWidth: 320)
                    thread
                        .frame(minWidth: 440, idealWidth: 640)
                }
            } else {
                thread
            }
        }
        .navigationTitle("상담")
        .navigationSubtitle(reading.person.name)
        .toolbar { toolbar }
        // 읽기만 한다. 생성은 사용자의 조작에서만 시작된다.
        .onAppear { store.restore(personID: reading.person.id) }
        .onChange(of: reading.person.id) { store.restore(personID: reading.person.id) }
    }

    /// 상담이 바뀌면 화면을 새로 만든다. 초안과 편집기 높이가 앞 상담에서
    /// 따라오면 사용자는 자기가 적지 않은 글을 보게 된다.
    private var thread: some View {
        ConsultationThread(reading: reading, consultation: current)
            .id(current?.id)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if !history.isEmpty {
            ToolbarItem {
                Button {
                    appState.showsConsultationList.toggle()
                } label: {
                    Label("상담 목록", systemImage: "sidebar.squares.left")
                }
                .help("지난 상담 목록을 보이거나 숨깁니다. (⌥⌘S)")
            }
        }
        ToolbarItem {
            Button {
                appState.selectedConsultationID = nil
                appState.focusConsultationComposer()
            } label: {
                Label("새 상담", systemImage: "square.and.pencil")
            }
            .help("새 상담을 시작합니다. (⇧⌘N)")
        }
    }
}

// MARK: - 지난 상담

/// 지난 상담 목록.
///
/// 검색과 날짜 묶음이 있다. 묶음은 **오늘 · 어제 · 이전** 셋뿐이다.
/// 더 잘게 나누는 것은 근거 없는 모방이다 — Claude의 문자열 번들에도
/// `Today`·`Yesterday`뿐이고, ChatGPT의 "Previous 7 Days"는 벤더 문서로
/// 확인되지 않는다.
struct ConsultationListPane: View {
    let reading: Reading
    @Environment(AppState.self) private var appState
    @Environment(ConsultationStore.self) private var store
    @FocusState private var searchFocused: Bool

    private var items: [Consultation] {
        let all = store.consultations(for: reading.person.id)
        let query = appState.consultationQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.concern.localizedCaseInsensitiveContains(query)
                || $0.topic.title.localizedCaseInsensitiveContains(query)
                || $0.turns.contains { $0.text.localizedCaseInsensitiveContains(query) }
        }
    }

    /// 오늘 · 어제 · 이전. 빈 묶음은 만들지 않는다.
    private var groups: [(title: String, items: [Consultation])] {
        let calendar = Calendar.current
        var today: [Consultation] = []
        var yesterday: [Consultation] = []
        var older: [Consultation] = []
        for item in items {
            if calendar.isDateInToday(item.openedAt) {
                today.append(item)
            } else if calendar.isDateInYesterday(item.openedAt) {
                yesterday.append(item)
            } else {
                older.append(item)
            }
        }
        return [("오늘", today), ("어제", yesterday), ("이전", older)]
            .filter { !$0.1.isEmpty }
    }

    var body: some View {
        @Bindable var state = appState
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                TextField("상담 검색", text: $state.consultationQuery)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .focused($searchFocused)
                if !appState.consultationQuery.isEmpty {
                    Button {
                        appState.consultationQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            // 선택은 List가 관리한다. 예전에는 `.onTapGesture`와
            // `.listRowBackground`로 선택을 흉내 냈고, 그래서 키보드로
            // 목록을 오르내릴 수 없었다.
            List(selection: $state.selectedConsultationID) {
                ForEach(groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.items) { item in
                            row(item)
                                .tag(item.id)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView.search(text: appState.consultationQuery)
                }
            }
        }
        .onChange(of: appState.searchFocusToken) { searchFocused = true }
    }

    /// 한 줄이 원칙이다. 두 번째 줄은 **사실이 어긋났을 때만** 나온다.
    private func row(_ item: Consultation) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.headline)
                .font(.callout)
                .lineLimit(1)
            HStack(spacing: 5) {
                Text(item.topic.title)
                    .foregroundStyle(Ink.cinnabar)
                Text(item.openedAt.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(.tertiary)
                if item.awaitsFirstAnswer {
                    Text("풀이 전")
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.caption2)
            // 명식 서명이 다르면 그때와 지금의 근거가 다르다. 숨기지 않는다.
            if item.signature != reading.chart.signature {
                Text("유파 설정이 달라진 뒤의 명식입니다")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
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

// MARK: - 한 상담

/// 상담 하나를 이어가는 화면. **컴포저를 소유한다.**
///
/// 상담이 열리기 전(`consultation == nil`)과 열린 뒤가 같은 뷰다. 그래서
/// 처음 적은 글이 말풍선이 되는 순간에도 입력창은 제자리에 있고 포커스를
/// 잃지 않는다. 채팅처럼 느껴지는지는 대부분 이 한 가지에서 갈린다.
struct ConsultationThread: View {
    let reading: Reading
    let consultation: Consultation?

    @Environment(AppState.self) private var appState
    @Environment(ConsultationStore.self) private var store
    @Environment(Writers.self) private var writers

    @State private var draft = ""
    @State private var chosenTopic: ConsultationTopic?
    @State private var needsTopicChoice = false
    /// 안전 선별에 걸렸다. 모델은 부르지 않았고 기록도 만들지 않았다.
    @State private var crisis: [String]?
    @State private var selectedRule: Rule?
    @State private var isExporting = false
    @State private var pendingSend: PendingSend?

    private var phase: ConsultationStore.Phase {
        consultation.map { store.phase(of: $0.id) } ?? .idle
    }
    private var isWriting: Bool { phase == .writing }
    private var isPreparing: Bool { phase == .preparingModel }
    private var aiOffered: Bool { appState.useLLM && writers.isAvailable }

    private var timeFacts: FactSet {
        SajuService.fortune(on: Date(), reading: reading).facts
    }

    private var availableTopics: [ConsultationTopic] {
        ConsultationRouter.availableTopics(
            facts: reading.facts,
            timeFacts: consultation.map { $0.includesToday ? timeFacts : nil } ?? timeFacts,
            ruleSet: SajuService.ruleSet
        )
    }

    private var evidence: [Rule] {
        guard let consultation else { return [] }
        return rules(for: consultation.evidenceIDs)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let consultation {
                transcript(consultation)
                    // 근거 머리를 스크롤 밖에 고정한다. 스크롤 컨테이너 맨
                    // 위에 두면 두 번째 답변부터 화면에서 사라지고, 사용자는
                    // 근거를 보려고 계속 위로 스크롤한다(NN/g "apple picking").
                    .safeAreaInset(edge: .top, spacing: 0) { pinnedHeader(consultation) }
            } else {
                opening
            }
            bottomBar
        }
        .background(.background)
        .toolbar {
            if consultation != nil {
                ToolbarItem {
                    Button { isExporting = true } label: {
                        Label("내보내기", systemImage: "square.and.arrow.up")
                    }
                    .help("이 상담을 마크다운으로 저장합니다. 근거 ID까지 함께 나갑니다. (⇧⌘E)")
                }
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            // 내보낼 때만 만든다. 그냥 두면 스트리밍 중 청크마다 상담
            // 전체를 마크다운으로 다시 조립한다.
            document: MarkdownDocument(text: isExporting ? markdown() : ""),
            contentType: .plainText,
            defaultFilename: consultation.map {
                "상담-\($0.openedAt.formatted(.iso8601.year().month().day()))"
            } ?? "상담"
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
        .sheet(item: $pendingSend) { send in
            OutboundDisclosure(
                destination: send.destination,
                model: send.model,
                system: send.system,
                user: send.user,
                summary: send.summary,
                onConfirm: {
                    if let host = send.destination.host {
                        writers.remote.acknowledge(host: host)
                    }
                    pendingSend = nil
                    send.run()
                },
                onCancel: { pendingSend = nil }
            )
        }
        .onChange(of: appState.exportRequestToken) {
            if consultation != nil { isExporting = true }
        }
    }

    // MARK: 시작 화면

    /// 아직 상담이 열리지 않았을 때. **가운데에 짧게.**
    ///
    /// 예전에는 여기에 제목 + 편집기 + 버튼 + 축 목록 + 접힌 목록 + 잔글씨
    /// 네 줄이 있었다. 지금 남은 것은 제목 한 줄, 설명 한 줄, 축 칩이다.
    /// 나머지는 아래 컴포저와 그 밑 한 줄이 맡는다.
    private var opening: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 14) {
                if let crisis {
                    // 안전 안내가 뜬 자리에 "무엇이 마음에 걸리십니까"와 축
                    // 칩을 함께 두지 않는다. 지금 이 화면이 할 일은 하나다.
                    CrisisCard(matched: crisis) { self.crisis = nil }
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("무엇이 마음에 걸리십니까")
                            .font(.title2.weight(.semibold))
                        Text("있는 그대로 적어 주세요. 어떤 명리 축의 이야기인지 앱이 먼저 정하고, 그 축의 근거만 가지고 풀이합니다.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if needsTopicChoice { routingFailed }
                    axisPicker
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: Measure.reading, alignment: .leading)
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        // 캡처 경로에서 높이가 0이 되는 `containerRelativeFrame`을 쓰지
        // 않는다. 스크롤 컨테이너가 아닌 곳의 `Spacer`는 정상적으로 늘어난다.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var routingFailed: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("어떤 축으로 읽을지 정하지 못했습니다", systemImage: "questionmark.circle")
                .font(.callout)
            Text("적어 주신 글에서 명리 축을 찾지 못했습니다. 짐작으로 고르면 엉뚱한 근거로 답하게 되므로, 아래에서 직접 골라 주시면 그 축으로 읽겠습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.cinnabar.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    }

    /// 이 명식에서 이야기할 수 있는 축. **누를 수 있다.**
    ///
    /// 누르면 축만 정하고 상담을 열지는 않는다. 고민 원문은 사용자의 말이어야
    /// 한다. 빈 화면에 커서만 있는 것("blinking cursor problem")을 피하면서도
    /// 사용자의 첫 문장을 대신 써 주지는 않는 자리다.
    private var axisPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("축을 먼저 골라 두셔도 됩니다")
                .font(.caption)
                .foregroundStyle(.secondary)
            FlowChips {
                ForEach(availableTopics) { topic in
                    let picked = chosenTopic == topic
                    Button {
                        // 다시 누르면 해제. 라우팅에 맡기겠다는 뜻이다.
                        chosenTopic = picked ? nil : topic
                        needsTopicChoice = false
                        appState.focusConsultationComposer()
                    } label: {
                        Text(topic.title)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                picked ? AnyShapeStyle(Ink.cinnabar.opacity(0.16))
                                       : AnyShapeStyle(.quaternary.opacity(0.4)),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    picked ? Ink.cinnabar.opacity(0.55) : .clear, lineWidth: 1
                                )
                            )
                            .foregroundStyle(picked ? Ink.cinnabar : .primary)
                    }
                    .buttonStyle(.plain)
                    .help("\(topic.title) — \(topic.axis)로 읽습니다")
                }
            }
        }
    }

    // MARK: 기록

    private func transcript(_ consultation: Consultation) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 처음 적은 고민도 사용자의 말이다. 예전에는 이것만 전폭
                // 카드였고 이후 발언은 말풍선이라, 같은 사람의 말이 두
                // 모습이었다.
                PersonBubble(text: consultation.concern)
                ForEach(consultation.turns) { turn in
                    TurnBubble(
                        turn: turn,
                        // 발언 자신의 기록을 먼저 본다. 상담 단위 값만 보면
                        // 마지막 값이 모든 답변에 붙어, 이 Mac에서 쓴 답변이
                        // 원격에서 쓴 것으로 표시된다.
                        provenance: turn.speaker == .counselor
                            ? (turn.provenance ?? consultation.provenance) : nil,
                        // **그 발언이 실제로 쓴** 근거다. 상담 수준 값을
                        // 넘기면 축을 바꾼 뒤 이전 답변이 쓰지 않은 규칙을
                        // 인용하게 된다.
                        evidence: turn.speaker == .counselor ? rules(for: turn.evidenceIDs) : [],
                        isLast: turn.id == consultation.turns.last?.id,
                        canRegenerate: aiOffered && !isWriting && !isPreparing,
                        onRule: { selectedRule = $0 },
                        onRegenerate: { requestAnswer(regenerating: true) }
                    )
                    .id(turn.id)
                }
                if case .failed(let message) = phase {
                    FailureNote(message: message) { requestAnswer(regenerating: true) }
                }
                if let crisis {
                    CrisisCard(matched: crisis) { self.crisis = nil }
                }
                followUps(consultation)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .frame(maxWidth: Measure.reading, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        // 정렬은 위, 크기 변화는 아래. `.bottom` 하나만 주면 기록이 뷰포트보다
        // 짧을 때 내용이 아래로 붙고 고정 머리 밑에 빈 구멍이 생긴다.
        .defaultScrollAnchor(.top, for: .alignment)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
    }

    /// 이어 물을 거리. **답이 끝났을 때만, 기록 안에.**
    ///
    /// 컴포저 위에 두면 입력창을 아래로 밀어낸다(Perplexity의 티어다운이
    /// 자기 화면에 대해 그렇게 적는다). 기록의 마지막 요소로 두면 스크롤과
    /// 함께 지나가고 입력창은 제자리에 있다.
    ///
    /// 이것은 붙잡는 장치가 아니다(§6-3). 문구는 고정되어 있고, 이 축에
    /// 근거가 성립할 때만 나오며, 눌러도 보내지 않고 입력창에 넣기만 한다.
    @ViewBuilder
    private func followUps(_ consultation: Consultation) -> some View {
        let ready = !isWriting && !isPreparing && crisis == nil
            && draft.isEmpty && consultation.counselorTurnCount > 0
            && consultation.turns.last?.speaker == .counselor
            && consultation.turns.last?.isComplete == true
        if ready {
            VStack(alignment: .leading, spacing: 6) {
                Text("이 근거로 더 물을 수 있는 것")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                FlowChips {
                    ForEach(consultation.topic.followUps, id: \.self) { question in
                        Button {
                            draft = question
                            appState.focusConsultationComposer()
                        } label: {
                            Text(question)
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .overlay(Capsule().strokeBorder(.separator, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("입력창에 넣습니다. 고쳐 적으셔도 됩니다.")
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    /// 이 상담이 쓰는 축과 근거. 스크롤과 무관하게 항상 보인다.
    private func pinnedHeader(_ consultation: Consultation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // 이 화면에서 결과를 가장 크게 바꾸는 조작이다 — 축을 바꾸면
                // 근거 전체가 바뀐다. "오늘 기운"도 같은 성격이므로 같은
                // 메뉴에 둔다. 머리에 컨트롤이 둘이면 어느 쪽이 주인지 모른다.
                Menu {
                    Section("축") {
                        ForEach(menuTopics(consultation)) { topic in
                            Button {
                                retopic(consultation, to: topic)
                            } label: {
                                if topic == consultation.topic {
                                    Label(topic.title, systemImage: "checkmark")
                                } else {
                                    Text(topic.title)
                                }
                            }
                        }
                    }
                    Divider()
                    Toggle("오늘의 기운 함께 보기", isOn: Binding(
                        get: { consultation.includesToday },
                        set: { store.setIncludesToday($0, for: consultation.id) }
                    ))
                } label: {
                    Text("축: \(consultation.topic.title)")
                        .font(.caption.weight(.medium))
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
                .help("\(consultation.topic.axis)로 읽습니다. 축을 바꾸면 이후 풀이의 근거가 바뀝니다 — 이미 받은 답변은 자기 근거를 그대로 유지합니다.")

                Text(consultation.topic.axis)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if consultation.includesToday {
                    Text("오늘의 기운 포함")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                // 무엇을 보고 무엇을 기억하지 않는지. 근거 옆이 제자리다.
                Text("근거 \(String(evidence.count))개 · 최근 발언 \(String(CounselBrief.recentTurnWindow))개")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .help("이 상담은 위 근거와 처음 적으신 고민, 그리고 최근 발언 \(String(CounselBrief.recentTurnWindow))개만 봅니다. 그 밖의 것은 기억하지 않습니다.")
            }
            EvidenceChips(rules: evidence, onRule: { selectedRule = $0 })
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .frame(maxWidth: Measure.reading, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    /// 축 메뉴에 실제로 고를 수 있는 축. 지금 축은 근거가 비어도 남긴다 —
    /// 고른 축이 메뉴에서 사라지면 사용자는 무엇을 보고 있는지 알 수 없다.
    private func menuTopics(_ consultation: Consultation) -> [ConsultationTopic] {
        let available = ConsultationRouter.availableTopics(
            facts: reading.facts,
            timeFacts: consultation.includesToday ? timeFacts : nil,
            ruleSet: SajuService.ruleSet
        )
        return available.contains(consultation.topic)
            ? available
            : ([consultation.topic] + available)
    }

    // MARK: 아래 칸

    /// 알림 한 줄 + 컴포저 + 고지 한 줄. **이 세 줄이 전부다.**
    ///
    /// 예전에는 여기에 알림 블록 둘, 컴포저, 잔글씨 세 줄, 그리고 별도의
    /// 컨트롤 묶음이 있었다. 같은 내용을 여러 겹으로 적는 것은 보여주는
    /// 것이 아니라 채우는 것이다.
    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 7) {
            banner
            ChatComposer(
                text: $draft,
                placeholder: placeholder,
                isWriting: isWriting,
                isPreparing: isPreparing,
                sendHelp: sendHelp,
                // 상담을 여는 첫 글은 축을 정할 만큼은 되어야 한다.
                minimumLength: consultation == nil ? 4 : 1,
                focusToken: appState.composerFocusToken,
                onSubmit: submit,
                onStop: { if let consultation { store.stop(id: consultation.id) } }
            )
            disclosure
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: Measure.reading, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background(.background)
    }

    private var placeholder: String {
        guard let consultation else {
            return "예: 지금 회사를 계속 다녀야 할지 몇 달째 마음이 왔다 갔다 합니다."
        }
        if consultation.awaitsFirstAnswer {
            return "되물음에 답하거나 사정을 덧붙여 주세요"
        }
        return "이어서 물으실 것을 적어 주세요"
    }

    private var sendHelp: String {
        guard consultation != nil else {
            return "상담을 엽니다. 축과 근거를 정하는 것까지가 여기서 끝나고 모델은 부르지 않습니다. (↩ 또는 ⌘↩)"
        }
        guard aiOffered else {
            return "적어 주신 말을 기록합니다. 풀이는 쓸 곳을 고르신 뒤에 받으실 수 있습니다. (↩)"
        }
        if writers.needsLoadBeforeUse {
            return "모델을 불러온 뒤 이 근거로 풀이를 씁니다. 처음 한 번은 몇 초 더 걸립니다. (↩ 또는 ⌘↩)"
        }
        if writers.plannedToLeaveMachine, let host = writers.plannedDestination.host {
            return "이 근거와 적어 주신 글을 \(host)로 보내 풀이를 씁니다. (↩ 또는 ⌘↩)"
        }
        return "이 근거로 풀이를 씁니다. (↩ 또는 ⌘↩)"
    }

    /// 알림은 한 줄, 하나만. 우선순위는 "쓸 곳이 없다" > "길어졌다".
    @ViewBuilder
    private var banner: some View {
        if !aiOffered {
            HStack(spacing: 7) {
                Image(systemName: "wand.and.stars")
                Text(writers.problem ?? "풀이를 받으려면 설정에서 쓸 곳을 고르세요. 적어 주신 말은 그대로 기록됩니다.")
                    .lineLimit(2)
                Spacer(minLength: 0)
                SettingsLink { Text("설정") }
                    .controlSize(.small)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if let consultation, consultation.counselorTurnCount >= 4 {
            HStack(spacing: 7) {
                Image(systemName: "info.circle")
                Text("이 상담이 길어졌습니다. 새 고민은 새 상담으로 여시면 근거가 더 정확합니다.")
                Spacer(minLength: 0)
                Button("새 상담") {
                    appState.selectedConsultationID = nil
                    appState.focusConsultationComposer()
                }
                .controlSize(.small)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// AI 고지와 목적지. **한 줄이다.**
    ///
    /// 규제가 요구하는 것은 "알 수 있게" 하는 것이지 여러 번 적는 것이
    /// 아니다(EU AI Act Art 50(1), Utah 13-72a-203). 항상 보이므로 요건은
    /// 그대로 만족한다. Nevada AB 406 §7 때문에 "상담사"·"치료" 계열 말을
    /// 쓰지 않는다.
    ///
    /// 목적지 문장은 **상태에서 나온다.** 고정 문자열로 두면 원격 제공자를
    /// 지정한 순간 거짓말이 되고, 거짓일 때가 하필 사용자가 알아야 하는
    /// 경우다.
    private var disclosure: some View {
        HStack(spacing: 5) {
            Image(systemName: writers.plannedToLeaveMachine ? "arrow.up.forward.square" : "cpu")
            Text(disclosureLine)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(writers.plannedToLeaveMachine ? AnyShapeStyle(Ink.cinnabar) : AnyShapeStyle(.tertiary))
        .help("이 앱은 계산된 명식과 근거 규칙만 봅니다. 근거에 없는 것은 지어내지 않고 모른다고 답하며, 답변마다 어떤 규칙에서 나왔는지 표시됩니다.")
    }

    private var disclosureLine: String {
        var parts: [String] = []
        if aiOffered, let label = writers.label {
            // 조사를 붙이지 않는다. 모델 이름에 양자화 표기가 들어 있어서
            // "Gemma 4 E2B · 4-bit이 씁니다"처럼 읽힌다.
            parts.append("풀이 작성: \(label)")
        } else {
            parts.append("풀이는 AI 모델이 씁니다")
        }
        parts.append("사람도 치료도 아닙니다")
        switch writers.plannedDestination {
        case .inProcess:
            parts.append(aiOffered ? "글은 이 Mac을 벗어나지 않습니다" : "적으신 글은 이 Mac을 벗어나지 않습니다")
        case .onMachine(let host):
            parts.append("이 Mac의 \(host)가 씁니다")
        case .offMachine(let host):
            parts.append("풀이를 받으시면 \(host)로 전송됩니다")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: 사용자의 조작

    /// 컴포저의 Return과 보내기 버튼이 부르는 유일한 자리.
    private func submit() {
        if consultation == nil {
            open()
        } else {
            requestAnswer()
        }
    }

    /// 상담을 연다. **모델을 부르지 않는다.**
    private func open() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 4 else { return }

        // 안전 선별이 모델보다 먼저다.
        switch SafetyScreen.evaluate(text) {
        case .crisis(let matched):
            // 기록을 만들지 않는다. 위기의 순간이 목록에 남아 있는 것은
            // 도움이 되지 않고 사용자가 저장을 요청한 것도 아니다.
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
        let picked = ConsultationRouter.evidence(
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

        let opened = store.open(
            personID: reading.person.id,
            signature: reading.chart.signature,
            concern: text,
            topic: topic,
            matchedTerms: matches.first(where: { $0.topic == topic })?.matchedTerms ?? [],
            evidenceIDs: picked.map(\.id),
            includesToday: topic == .timing || topic == .wellbeing,
            opening: opening
        )
        draft = ""
        chosenTopic = nil
        needsTopicChoice = false
        appState.selectedConsultationID = opened.id
    }

    /// 풀이를 요청한다.
    ///
    /// 두 관문을 지난다. **안전 선별이 먼저이고, 그다음이 전송 확인이다.**
    /// 순서가 중요하다 — 위기 표현이 담긴 글을 확인 화면에 띄워 "보냅니다"를
    /// 누를 기회를 주는 것 자체가 잘못이다.
    private func requestAnswer(regenerating: Bool = false) {
        guard let consultation else { return }
        let text = regenerating ? "" : draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard regenerating || !text.isEmpty else { return }

        // 처음 적은 고민만 검사하고 덧붙인 말은 검사하지 않던 시절이 있었다.
        // 원격이 붙은 뒤에는 그것이 위기 표현이 남의 서버로 나가는 경로다.
        // 적으신 글은 지우지 않는다. 안내를 닫고 다시 쓰실 수 있어야 한다.
        if !text.isEmpty, case .crisis(let matched) = SafetyScreen.evaluate(text) {
            crisis = matched
            return
        }

        // 쓸 곳이 없으면 막다른 골목을 만들지 않는다. 적어 주신 말은
        // 기록하고, 풀이는 나중에 받을 수 있다고 말해 준다.
        guard aiOffered else {
            store.addPersonTurn(text, to: consultation.id)
            draft = ""
            return
        }

        let start = {
            // 다시 쓰기는 **덮어쓰지 않는다.** 같은 근거로 새 답변을 아래에
            // 붙이고 이전 답변은 그대로 남긴다. 사용자가 시간과 배터리를
            // 들여 얻은 문장을 버튼 한 번으로 지우지 않는다.
            let outgoing = regenerating ? "" : draft
            draft = ""
            store.answer(id: consultation.id, followUp: outgoing, supplier: supplier)
        }
        guard writers.needsAcknowledgement, let config = writers.remote.config
        else { start(); return }

        let brief = brief
        pendingSend = PendingSend(
            destination: config.destination,
            model: config.model,
            system: CounselBrief.instructions,
            user: brief.promptText(for: consultation, followUp: text.isEmpty ? nil : text),
            summary: [
                "계산이 끝난 명식 사실 \(brief.facts.count)줄",
                "이 주제의 근거 원문 \(evidence.count)개",
                "적어 주신 고민 원문과 최근 발언 최대 \(CounselBrief.recentTurnWindow)개",
            ],
            run: start
        )
    }

    /// 축을 바꾼다. **시간 근거를 함께 넘긴다.** 명식 사실만 넘기면
    /// 시간 근거로만 성립하던 축은 근거가 빈다.
    private func retopic(_ consultation: Consultation, to topic: ConsultationTopic) {
        let picked = ConsultationRouter.evidence(
            for: topic,
            facts: reading.facts,
            timeFacts: consultation.includesToday ? timeFacts : nil,
            ruleSet: SajuService.ruleSet
        )
        store.retopic(consultation.id, topic: topic, evidenceIDs: picked.map(\.id))
    }

    /// 이 턴에 쓸 재료. 결정론적으로 이미 다 정해져 있다.
    private var brief: CounselBrief {
        CounselBrief(
            facts: reading.facts.summaryLines,
            todayFacts: consultation?.includesToday == true ? timeFacts.summaryLines : nil,
            topic: consultation?.topic ?? .identity,
            evidence: evidence
        )
    }

    /// 답변 재료를 준비하는 쪽. 모델 적재나 키체인 읽기가 여기서 일어난다.
    /// 출처는 여기서 만들지 않는다 — `Writers`가 한 곳에서 만든다.
    private var supplier: ConsultationStore.Supplier {
        let writers = writers
        let brief = brief
        return { await writers.prepareCounselor(brief: brief) }
    }

    /// 근거 ID를 규칙으로. 없는 ID는 조용히 빠진다 — 근거 판이 올라가
    /// 규칙이 사라졌을 수 있고, 그때 화면이 비는 것이 맞다.
    private func rules(for ids: [String]) -> [Rule] {
        let wanted = Set(ids)
        return SajuService.ruleSet.rules.filter { wanted.contains($0.id) }
    }

    /// 내보내기 — 근거 ID까지 함께 나간다. 나중에 이 문장이 어디서 나왔는지
    /// 앱 없이도 추적할 수 있어야 한다.
    private func markdown() -> String {
        guard let consultation else { return "" }
        var out = "# 상담 기록 — \(consultation.topic.title)\n\n"
        out += "- 인물: \(reading.person.name)\n"
        out += "- 명식: \(reading.chart.compactHanja)\n"
        out += "- 축: \(consultation.topic.axis)\n"
        out += "- 연 날짜: \(consultation.openedAt.formatted(date: .long, time: .shortened))\n"
        if let p = consultation.provenance {
            out += "- 풀이: \(p.modelName) (\(p.resolvedDestination.label)), 근거 \(String(p.ruleSetVersion))판, 앱 \(p.appVersion)\n"
        }
        out += "\n## 고민\n\n\(consultation.concern)\n"
        out += "\n## 근거\n\n"
        for rule in evidence {
            out += "- **\(rule.title)** (`\(rule.id)`) — \(rule.text)\n"
        }
        out += "\n## 주고받은 말\n\n"
        for turn in consultation.turns {
            // 답변마다 자기 근거를 적는다. 상담 수준 값을 쓰면 축을 바꾼 뒤
            // 내보낸 기록이 그 답변이 쓰지 않은 규칙에 귀속시킨다.
            // 호칭에 "상담사"·"치료" 계열 말을 쓰지 않는다.
            let who = switch turn.speaker {
            case .person: "적은 말"
            case .counselor: "명리 풀이 (AI 모델)"
            case .app: "앱이 확정한 말"
            }
            out += "**\(who)** — \(turn.text)\n\n"
            if turn.speaker == .counselor, !turn.evidenceIDs.isEmpty {
                out += "  근거: " + turn.evidenceIDs.map { "`\($0)`" }.joined(separator: ", ") + "\n\n"
            }
            if turn.speaker == .counselor, let p = turn.provenance {
                out += "  작성: \(p.modelName) (\(p.resolvedDestination.label))\n\n"
            }
        }
        out += "---\n\n이 기록은 참고용이며 의료·투자·법률 판단의 근거가 될 수 없습니다.\n"
        return out
    }
}

// MARK: - 말과 말풍선

/// 사용자의 말. 처음 적은 고민도 이후 발언도 같은 모습이다.
struct PersonBubble: View {
    let text: String

    var body: some View {
        HStack {
            Spacer(minLength: 48)
            Text(text)
                .font(.body)
                .lineSpacing(3)
                .textSelection(.enabled)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(
                    Ink.cinnabar.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
        }
    }
}

/// 실패했을 때. **막다른 골목을 만들지 않는다.**
///
/// 예전에는 붉은 글씨 한 줄이 전부였고 사용자가 할 수 있는 일이 없었다.
/// 무엇이 일어났는지 적고, 다시 해 볼 수 있는 버튼을 그 자리에 둔다.
struct FailureNote: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "exclamationmark.triangle")
            VStack(alignment: .leading, spacing: 5) {
                Text(message)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Button("다시 시도", action: onRetry)
                    .controlSize(.small)
            }
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(Ink.cinnabar)
    }
}

struct TurnBubble: View {
    let turn: Consultation.Turn
    let provenance: InterpretationStore.Provenance?
    let evidence: [Rule]
    var isLast: Bool = false
    var canRegenerate: Bool = false
    let onRule: (Rule) -> Void
    var onRegenerate: () -> Void = {}

    /// 답변 아래 조작은 **가리키면 나온다.** 데스크톱의 관례이고, 항상
    /// 보이면 답변마다 회색 줄이 하나씩 붙어 기록이 잡음으로 찬다.
    @State private var hovering = false

    var body: some View {
        switch turn.speaker {
        case .app:
            // 앱이 결정론적으로 말한 것. 채워진 카드 대신 왼쪽 얇은 선으로
            // 구분한다 — 그릇을 하나 줄이면 경쟁하는 문법이 줄어든다.
            HStack(alignment: .top, spacing: 9) {
                Rectangle()
                    .fill(.tertiary)
                    .frame(width: 2)
                Image(systemName: "text.book.closed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(turn.text)
                    .font(.callout)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .person:
            PersonBubble(text: turn.text)

        case .counselor:
            // 가장 길고 가장 많이 읽는 글이다. 말풍선에 가두지 않고 전폭
            // 평문으로 둔다 — Claude가 어시스턴트 발언에 하는 것과 같다.
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Ink.cinnabar)
                        .frame(width: 3, height: 13)
                    Text("풀이")
                        .font(.subheadline.weight(.semibold))
                    if !turn.isComplete {
                        ProgressView().controlSize(.small).scaleEffect(0.7)
                        // 스피너에 라벨을 붙이지 말라는 지침과, 생성 중에는
                        // 무슨 일이 일어나는지 알리라는 지침이 어긋난다.
                        // 생성 화면에서는 후자를 택한다.
                        Text("근거를 읽고 쓰는 중")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }

                if !turn.text.isEmpty {
                    Text(turn.text)
                        .font(.body)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(turn.isComplete ? [] : .updatesFrequently)
                }

                if turn.isComplete {
                    EvidenceChips(rules: evidence, onRule: onRule)
                    footer
                }
            }
            .onHover { hovering = $0 }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let provenance {
                HStack(spacing: 4) {
                    Image(systemName: provenance.resolvedDestination.leavesMachine
                        ? "arrow.up.forward.square" : "cpu")
                    Text("\(provenance.modelName) · \(provenance.resolvedDestination.label)")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if hovering || isLast {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(turn.text, forType: .string)
                } label: {
                    Label("복사", systemImage: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .help("이 풀이를 클립보드로 복사합니다.")

                if isLast, canRegenerate {
                    Button(action: onRegenerate) {
                        Label("다시 쓰기", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    // 덮어쓰지 않는다. 이전 답변은 그대로 남고 새 답변이
                    // 아래에 붙는다 — 비용을 치른 것은 남긴다.
                    .help("같은 근거로 다시 씁니다. 지금 답변은 지우지 않고 그 아래에 새로 붙입니다.")
                }
            }
        }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// 위기 표현이 걸렸을 때.
///
/// 모델을 부르지 않는다. 이 화면의 문장은 전부 고정되어 있고 생성되지
/// 않는다. 명리 해석으로 답할 자리가 아니다.
///
/// 이 화면이 존재하는 이유는 규제 요건(캘리포니아 SB 243 §22602(b))만이
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
                .fixedSize(horizontal: false, vertical: true)
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

/// 근거 칩. 해석 화면과 같은 문법을 쓴다.
///
/// 캡슐 문법을 셋으로 나눈 결과다 — 축 칩(채워진 캡슐 + 선택 상태, 액션),
/// 근거 칩(돋보기 + 외곽선, 정보 열기), 비활성 라벨(캡슐을 쓰지 않음).
struct EvidenceChips: View {
    let rules: [Rule]
    let onRule: (Rule) -> Void
    /// 이 개수를 넘으면 접는다. 전부 표시하면 아무것도 표시하지 않은 것과 같다.
    var visible: Int = 4
    @State private var expanded = false

    var body: some View {
        if !rules.isEmpty {
            let shown = expanded ? rules : Array(rules.prefix(visible))
            FlowChips {
                ForEach(shown) { rule in
                    Button { onRule(rule) } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "text.magnifyingglass").font(.system(size: 9))
                            Text(rule.title)
                        }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(Capsule().strokeBorder(.separator, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(rule.text)
                }
                if !expanded, rules.count > visible {
                    Button { expanded = true } label: {
                        Text("+\(String(rules.count - visible))")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .overlay(Capsule().strokeBorder(.separator, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("근거 \(String(rules.count))개를 모두 봅니다")
                }
            }
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
