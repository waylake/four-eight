import SwiftUI
import RemoteLLM
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
    @Environment(Writers.self) private var writers

    @State private var concern = ""
    @State private var chosenTopic: ConsultationTopic?
    @State private var crisis: [String]?
    @State private var needsTopicChoice = false
    /// 자동 포커스. 없으면 첫 풀이까지 클릭 다섯 번 중 두 번이 포커스에만
    /// 쓰인다. 반참여 설계가 아니라 그냥 마찰이었다.
    @FocusState private var editorFocused: Bool
    @State private var showsUnavailable = false

    private var timeFacts: FactSet {
        SajuService.fortune(on: Date(), reading: reading).facts
    }

    private var availableTopics: [ConsultationTopic] {
        ConsultationRouter.availableTopics(
            facts: reading.facts, timeFacts: timeFacts, ruleSet: SajuService.ruleSet
        )
    }

    var body: some View {
        // 세로 가운데 정렬은 시도했다가 되돌렸다. `Spacer`는 ScrollView 안에서
        // 늘어나지 않고(높이가 무한이라 늘어날 대상이 없다),
        // `containerRelativeFrame(.vertical)`은 캡처 경로에서 높이를 0으로
        // 계산해 **화면이 통째로 비었다.** 스크린샷이 그것을 잡았다.
        //
        // 대신 위 여백을 넉넉히 준다. 내용을 줄인 것(잔글씨 네 줄 → 두 줄,
        // 칩에서 축 문자열 제거)이 이미 위쪽 쏠림을 줄였으므로, 여기서
        // 검증할 수 없는 구조를 쓸 이유가 없다.
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let crisis {
                    CrisisCard(matched: crisis) { self.crisis = nil }
                } else {
                    editor
                    if needsTopicChoice { routingFailed }
                    axisPicker
                }
                groundingNote
            }
            .padding(.horizontal, 20)
            .padding(.top, 44)
            .padding(.bottom, 20)
            .frame(maxWidth: Measure.reading, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .defaultFocus($editorFocused, true)
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
                .focused($editorFocused)
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
                // 단축키를 라벨에 적는다. 예전에는 ⌘Return이 있었지만
                // `.help`에도 없어서 완전히 비가시였다. 실제 실패는 단축키가
                // 없는 것이 아니라 숨어 있는 것이었다.
                Button("상담 열기  ⌘↩") { open() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(concern.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)
            }
        }
    }

    /// 라우팅이 실패했을 때 덧붙이는 말. 축 선택 자체는 항상 아래에 있다.
    private var routingFailed: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("어떤 축으로 읽을지 정하지 못했습니다", systemImage: "questionmark.circle")
                .font(.callout)
            Text("적어 주신 글에서 명리 축을 찾지 못했습니다. 짐작으로 고르면 엉뚱한 근거로 답하게 되므로, 아래에서 직접 골라 주시면 그 축으로 읽겠습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.cinnabar.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    }

    /// 이 명식에서 이야기할 수 있는 축. **누를 수 있다.**
    ///
    /// 예전에는 같은 목록이 두 벌 있었다 — 항상 보이는 비활성 라벨과,
    /// 라우팅이 실패한 뒤에만 나타나는 버튼. 화면에서 가장 버튼처럼 생긴
    /// 여섯 개가 눌리지 않았고, 그것을 §6("모른다는 품질 기준")으로 둘 수는
    /// 없다. §6이 막는 것은 답할 수 없는 것을 권하는 일이고, 답할 수 있는
    /// 것을 누르지 못하게 하는 일이 아니다.
    ///
    /// 누르면 축만 정하고 상담을 열지는 않는다. 고민 원문은 여전히
    /// 사용자의 말이어야 한다.
    private var axisPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
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
                        editorFocused = true
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
                    // 축 문자열은 칩에 넣지 않는다. 정보 둘을 담으면 폭이
                    // 커져 여섯 개가 두 줄로 깨진다.
                    .help("\(topic.title) — \(topic.axis)로 읽습니다")
                }
            }
            unavailableNote
        }
    }

    /// 권하지 않는 축. 접어 둔다 — 첫 화면의 아래 절반을 잔글씨로 채우던 것이다.
    @ViewBuilder
    private var unavailableNote: some View {
        let missing = Set(ConsultationTopic.allCases).subtracting(availableTopics)
        if !missing.isEmpty {
            DisclosureGroup(isExpanded: $showsUnavailable) {
                // "이 명식에는"이라고 적으면 사실이 아니다. availableTopics는
                // 오늘의 일진(timeFacts)까지 보고 계산하므로 이 목록은
                // 날짜에 따라 바뀐다.
                Text("지금 이 명식과 오늘의 기운으로는 \(missing.map(\.title).sorted().joined(separator: ", ")) 쪽 근거가 성립하지 않습니다. 없는 근거로 답하지 않기 때문에 권하지 않습니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } label: {
                Text("권하지 않는 축 \(String(missing.count))개")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// 지금 설정에서 사용자의 글이 어디까지 가는가.
    private var whereTextGoes: String {
        guard appState.useLLM, writers.isAvailable else {
            // 풀이를 주문할 수 없는 상태다. 아무것도 나가지 않는다.
            return "적어 주신 글은 이 Mac을 벗어나지 않습니다."
        }
        switch writers.plannedDestination {
        case .inProcess:
            return "적어 주신 글은 이 Mac을 벗어나지 않습니다. 풀이는 이 Mac의 모델이 씁니다."
        case .onMachine(let host):
            return "풀이는 이 Mac에서 도는 \(host)가 씁니다. 글은 이 Mac을 벗어나지 않습니다."
        case .offMachine(let host):
            return "풀이를 받으시면 명식 근거와 적어 주신 글이 \(host)로 전송됩니다. 처음 보낼 때 무엇이 나가는지 보여 드립니다."
        }
    }

    /// 시작 전에 알아야 하는 것. **두 줄이다.**
    ///
    /// 예전에는 카드 안에 카드가 들어 있고 잔글씨가 네 줄이어서, 첫 화면의
    /// 아래 절반이 회색 글씨였다. 같은 내용을 여러 겹으로 적는 것은
    /// 보여주는 것이 아니라 채우는 것이다.
    private var groundingNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("계산된 명식과 근거 규칙만 봅니다. 근거에 없는 것은 지어내지 않고 모른다고 답하며, 답변마다 어떤 규칙에서 나왔는지 표시됩니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    // 이 문장은 **상태에서 나온다.**
                    //
                    // 예전에는 "적어 주신 글은 이 Mac을 벗어나지 않습니다"가
                    // 그냥 박혀 있었다. 원격 제공자를 붙일 수 있게 된 뒤로
                    // 그 문장은 설정에 따라 참이거나 거짓이고, 거짓일 때가
                    // 하필 사용자가 알아야 하는 경우다. 프라이버시 주장을
                    // 고정 문자열로 두면 언젠가 거짓말이 된다.
                    Text(whereTextGoes)
                        .font(.caption2)
                        .foregroundStyle(writers.plannedToLeaveMachine ? Ink.cinnabar : .secondary)
                }
            }
            AIDisclosure()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    @Environment(Writers.self) private var writers

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: writers.plannedToLeaveMachine ? "arrow.up.forward.square" : "cpu")
                .foregroundStyle(.secondary)
            // "이 Mac에서 돌아가는"이 고정 문자열이었다. 원격 제공자를
            // 지정하면 거짓이 되고, 거짓일 때가 하필 사용자가 알아야 하는
            // 경우다. 어디서 쓰는지는 설정에서 읽는다.
            Text("\(writerPhrase) 사람이 아니고, 심리 상담이나 치료가 아니며, 면허 있는 전문가의 도움을 대체하지 않습니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private var writerPhrase: String {
        switch writers.plannedDestination {
        case .inProcess: "풀이는 이 Mac에서 돌아가는 AI 모델이 씁니다."
        case .onMachine(let host): "풀이는 이 Mac에서 도는 \(host)의 AI 모델이 씁니다."
        case .offMachine(let host): "풀이는 \(host)의 AI 모델이 씁니다."
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
    @Environment(Writers.self) private var writers

    @State private var followUp = ""
    @State private var selectedRule: Rule?
    @State private var isExporting = false
    @State private var pendingSend: PendingSend?
    /// 덧붙인 말이 안전 선별에 걸렸다. 모델을 부르지 않았다.
    @State private var followUpCrisis: [String]?

    private var phase: ConsultationStore.Phase { store.phase(of: consultation.id) }
    private var aiOffered: Bool { appState.useLLM && writers.isAvailable }
    private var evidence: [Rule] {
        let ids = Set(consultation.evidenceIDs)
        return SajuService.ruleSet.rules.filter { ids.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            transcript
                // 근거 머리를 스크롤 밖에 고정한다.
                //
                // §6-2("근거는 답 뒤가 아니라 답 앞에")를 스크롤 컨테이너
                // 맨 위에 두는 것으로 구현해 두었는데, 그러면 턴이 뷰포트를
                // 넘어가는 순간(사실상 두 번째 답변부터) 근거가 화면에서
                // 사라진다. NN/g가 그 행동을 "apple picking"으로 측정했다 —
                // 사용자는 앞선 답변을 보려고 계속 위로 스크롤한다.
                // 고정하는 것이 6-2를 약화시키는 게 아니라 첫 정직한 구현이다.
                .safeAreaInset(edge: .top, spacing: 0) { pinnedHeader }
            Divider()
            contextNote
            if let followUpCrisis {
                // 기록을 남기지 않는다. 위기의 순간이 목록에 남아 있는 것은
                // 도움이 되지 않고, 사용자가 저장을 요청한 것도 아니다.
                // 모델은 부르지 않았고, 원격이라면 아무것도 나가지 않았다.
                CrisisCard(matched: followUpCrisis) { self.followUpCrisis = nil }
                    .padding(14)
            }
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
    }

    /// 버튼 설명. "모델을 불러온다"는 말은 원격에서는 사실이 아니다.
    private var answerHelp: String {
        if writers.needsLoadBeforeUse {
            return "모델을 불러온 뒤 이 근거로 풀이를 씁니다. 처음 한 번은 몇 초 더 걸립니다."
        }
        if writers.plannedToLeaveMachine, let host = writers.plannedDestination.host {
            return "이 근거와 적어 주신 글을 \(host)로 보내 풀이를 씁니다."
        }
        return "이 근거로 풀이를 씁니다."
    }

    // MARK: 기록

    private var transcript: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                concernCard
                ForEach(consultation.turns) { turn in
                    TurnBubble(
                        turn: turn,
                        // 발언 자신의 기록을 먼저 본다. 상담 단위 값만
                        // 보면 마지막 값이 모든 답변에 붙어, 이 Mac에서
                        // 쓴 답변이 원격에서 쓴 것으로 표시된다.
                        provenance: turn.speaker == .counselor
                            ? (turn.provenance ?? consultation.provenance) : nil,
                        // **그 발언이 실제로 쓴** 근거다. 상담 수준 값을
                        // 넘기면 축을 바꾼 뒤 이전 답변이 쓰지 않은 규칙을
                        // 인용하게 된다.
                        evidence: turn.speaker == .counselor ? rules(for: turn.evidenceIDs) : [],
                        isLast: turn.id == consultation.turns.last?.id,
                        canRegenerate: aiOffered && phase != .writing,
                        onRule: { selectedRule = $0 },
                        onRegenerate: { requestAnswer(regenerating: true) }
                    )
                    .id(turn.id)
                }
                if case .failed(let message) = phase {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Ink.cinnabar)
                        .textSelection(.enabled)
                }
            }
            .padding(18)
            .frame(maxWidth: Measure.reading, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        // 청크마다 애니메이션 스크롤을 새로 시작하면 화면이 흔들린다.
        // 그리고 예전 센티넬은 고지문 아래에 있어서, 30초 동안 뷰포트
        // 하단에 고정되는 것이 자라는 문장이 아니라 잔글씨였다.
        //
        // 역할을 나눠 준다. `.bottom` 하나만 주면 기록이 뷰포트보다 짧을 때
        // 내용이 아래로 붙고 고정 머리 밑에 빈 구멍이 생긴다.
        // 정렬은 위, 크기 변화는 아래 — 짧으면 위에서 시작하고 자라면 따라간다.
        .defaultScrollAnchor(.top, for: .alignment)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
    }

    /// 근거 ID를 규칙으로. 없는 ID는 조용히 빠진다 — 근거 판이 올라가
    /// 규칙이 사라졌을 수 있고, 그때 화면이 비는 것이 맞다.
    private func rules(for ids: [String]) -> [Rule] {
        let wanted = Set(ids)
        return SajuService.ruleSet.rules.filter { wanted.contains($0.id) }
    }

    /// 이 상담이 쓰는 축과 근거. 스크롤과 무관하게 항상 보인다.
    private var pinnedHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                // 이 화면에서 결과를 가장 크게 바꾸는 조작이다(축을 바꾸면
                // 근거 전체가 바뀐다). 예전에는 11pt 텍스트 + 8pt 시브론의
                // 테두리 없는 메뉴였다.
                Menu {
                    ForEach(menuTopics) { topic in
                        Button(topic.title) { retopic(to: topic) }
                    }
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
                Spacer(minLength: 0)
                Toggle(isOn: Binding(
                    get: { consultation.includesToday },
                    set: { store.setIncludesToday($0, for: consultation.id) }
                )) {
                    Text("오늘 기운 함께")
                        .font(.caption2)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            // 이 상담이 쓰는 근거. 답을 받기 전에 미리 볼 수 있다.
            EvidenceChips(rules: evidence, onRule: { selectedRule = $0 })
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .frame(maxWidth: Measure.reading, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    /// 축 메뉴에 실제로 고를 수 있는 축.
    ///
    /// `timeFacts`를 넘긴다. 예전에는 명식 사실만 넘겼고, 그래서 시간
    /// 근거로 성립하는 축(`.timing`, `.movement`)이 메뉴에서 사라지거나
    /// 골랐을 때 근거가 비었다. 오늘 기운을 켜 둔 상담이면 그 근거까지 본다.
    private var menuTopics: [ConsultationTopic] {
        ConsultationRouter.availableTopics(
            facts: reading.facts,
            timeFacts: consultation.includesToday ? todayFacts : nil,
            ruleSet: SajuService.ruleSet
        )
    }

    private var todayFacts: FactSet {
        SajuService.fortune(on: Date(), reading: reading).facts
    }

    /// 사용자가 처음 적은 고민. **사용자의 말은 한 모습이어야 한다.**
    /// 예전에는 최초 고민만 전폭 종이 카드였고 이후 발언은 우측 말풍선이라,
    /// 같은 사람의 말이 두 모습이었다.
    private var concernCard: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text("적어 주신 고민")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(consultation.concern)
                .font(.body)
                .lineSpacing(3)
                .textSelection(.enabled)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(Ink.cinnabar.opacity(0.09), in: RoundedRectangle(cornerRadius: 13))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 44)
    }

    /// 무엇을 보고 있고 무엇을 기억하지 않는지. **한 줄이다.**
    ///
    /// 예전에는 이 고지가 읽는 열 안에 잔글씨 세 줄로 상주했고, 스크롤
    /// 센티넬이 그 아래에 있어서 스트리밍 중 뷰포트 하단에 고정되는 것이
    /// 자라는 문장이 아니라 이 글이었다. 항상 보이므로 규제 요구(EU AI Act
    /// Art 50(1), Utah 13-72a-203)는 그대로 만족한다 — 위치만 바뀌었다.
    ///
    /// 숫자는 계속 코드에서 읽는다. 손으로 적으면 창 값이 바뀔 때 어긋난다.
    private var contextNote: some View {
        Text(contextLine)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .lineLimit(2)
            .padding(.horizontal, 18)
            .padding(.top, 7)
            .frame(maxWidth: Measure.reading, alignment: .leading)
            .frame(maxWidth: .infinity)
    }

    private var contextLine: String {
        var parts = [
            "근거 \(String(evidence.count))개와 최근 발언 \(String(CounselBrief.recentTurnWindow))개만 봅니다",
        ]
        if let label = writers.label, aiOffered {
            // 조사를 붙이지 않는다. 모델 이름에 양자화 표기가 들어 있어서
            // "Gemma 4 E2B · 4-bit이 씁니다"처럼 읽힌다.
            parts.append("작성: \(label)")
        }
        parts.append("사람도 치료도 아닙니다")
        return parts.joined(separator: " · ")
    }

    // MARK: 입력

    @ViewBuilder
    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 알림은 한 줄, 하나만. 우선순위는 "쓸 곳이 없다" > "길어졌다".
            // 예전에는 두 블록이 세로로 쌓여 컴포저를 밀어 올렸다.
            if !aiOffered {
                HStack(spacing: 7) {
                    Image(systemName: "wand.and.stars")
                    Text(writers.problem ?? "풀이를 받으려면 설정에서 쓸 곳을 고르세요. 축과 근거는 이미 정해져 있어 그대로 남습니다.")
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    SettingsLink { Text("설정") }
                        .controlSize(.small)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if consultation.counselorTurnCount >= 4 {
                HStack(spacing: 7) {
                    Image(systemName: "info.circle")
                    Text("이 상담이 길어졌습니다. 새 고민은 새 상담으로 여시면 근거가 더 정확합니다.")
                    Spacer(minLength: 0)
                    Button("새 상담") { appState.selectedConsultationID = nil }
                        .controlSize(.small)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
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
                Label("중단  ⌘.", systemImage: "stop.fill")
            }
            .keyboardShortcut(".", modifiers: .command)
            .help("쓰던 문장은 남습니다.")
        case .idle, .stopped, .failed:
            HStack(spacing: 6) {
                // "적어만 두기"를 메뉴로 내렸다. 예전에는 입력이 비면
                // 사라지는 버튼이어서, 타이핑을 시작하면 버튼이 늘어나
                // 레이아웃이 움직였다. 그리고 주 버튼이 둘이면 주 버튼이 없다.
                Menu {
                    Button("적어만 두기") {
                        store.addPersonTurn(followUp, to: consultation.id)
                        followUp = ""
                    }
                    .disabled(followUp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("모델을 부르지 않고 사정만 기록합니다.")
                    Divider()
                    Button("이 상담 내보내기…") { isExporting = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .controlSize(.small)
                .fixedSize()

                if aiOffered {
                    Button {
                        requestAnswer()
                    } label: {
                        // 매직 완드를 뺐다. NN/g의 프롬프트 컨트롤 지침이
                        // "labeled, standard icons (not enigmatic symbols
                        // like magic wands)"라며 정확히 이 아이콘을 예시로
                        // 지목한다.
                        Text((consultation.awaitsFirstAnswer ? "풀이 받기" : "이어 묻기") + "  ⌘↩")
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .help(answerHelp)
                }
            }
        }
    }

    /// 축을 바꾼다. **시간 근거를 함께 넘긴다.**
    ///
    /// 예전에는 명식 사실만 넘겨서, `.timing`을 고르면 근거가 대운 하나로
    /// 줄고 시간 근거로만 성립하던 축은 근거가 비었다.
    private func retopic(to topic: ConsultationTopic) {
        let picked = ConsultationRouter.evidence(
            for: topic,
            facts: reading.facts,
            timeFacts: consultation.includesToday ? todayFacts : nil,
            ruleSet: SajuService.ruleSet
        )
        store.retopic(consultation.id, topic: topic, evidenceIDs: picked.map(\.id))
    }

    /// 이 턴에 쓸 재료. 결정론적으로 이미 다 정해져 있다.
    private var brief: CounselBrief {
        CounselBrief(
            facts: reading.facts.summaryLines,
            todayFacts: consultation.includesToday ? todayFacts.summaryLines : nil,
            topic: consultation.topic,
            evidence: evidence
        )
    }

    /// 답변 재료를 준비하는 쪽. 모델 적재나 키체인 읽기가 여기서 일어난다.
    ///
    /// 출처는 여기서 만들지 않는다. `Writers`가 한 곳에서 만든다.
    private var supplier: ConsultationStore.Supplier {
        let writers = writers
        let brief = brief
        return { await writers.prepareCounselor(brief: brief) }
    }

    /// 풀이를 요청한다.
    ///
    /// 두 관문을 지난다. **안전 선별이 먼저이고, 그다음이 전송 확인이다.**
    /// 순서가 중요하다 — 위기 표현이 담긴 글은 확인 화면에 띄워 보여줄
    /// 것도 아니고, 그 화면에서 사용자가 "보냅니다"를 누를 기회를 주는
    /// 것 자체가 잘못이다.
    private func requestAnswer(regenerating: Bool = false) {
        let text = regenerating ? "" : followUp.trimmingCharacters(in: .whitespacesAndNewlines)

        // 안전 선별은 모델보다 먼저다. 처음 적은 고민만 검사하고 덧붙인
        // 말은 검사하지 않던 시절이 있었다. 로컬에서도 잘못이었지만,
        // 원격이 붙은 뒤에는 위기 표현이 남의 서버로 나가는 경로가 된다.
        if !text.isEmpty, case .crisis(let matched) = SafetyScreen.evaluate(text) {
            followUpCrisis = matched
            return
        }

        let start = {
            // 다시 쓰기는 **덮어쓰지 않는다.** 같은 근거로 새 답변을 아래에
            // 붙이고 이전 답변은 그대로 남긴다. 사용자가 시간과 배터리를
            // 들여 얻은 문장을 버튼 한 번으로 지우는 것은 이 저장소의
            // 원칙에 어긋난다.
            let outgoing = regenerating ? "" : followUp
            followUp = ""
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

    /// 내보내기 — 근거 ID까지 함께 나간다. 나중에 이 문장이 어디서
    /// 나왔는지 앱 없이도 추적할 수 있어야 한다.
    private func markdown() -> String {
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
            // 호칭에 "상담사"·"치료" 계열 말을 쓰지 않는다. 모델이 전문
            // 상담을 제공한다는 표현은 규제상으로도 사실로도 옳지 않다.
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

// MARK: - 말풍선

struct TurnBubble: View {
    let turn: Consultation.Turn
    let provenance: InterpretationStore.Provenance?
    let evidence: [Rule]
    var isLast: Bool = false
    var canRegenerate: Bool = false
    let onRule: (Rule) -> Void
    var onRegenerate: () -> Void = {}

    var body: some View {
        switch turn.speaker {
        case .app:
            // 앱이 결정론적으로 말한 것. 채워진 카드 대신 왼쪽 얇은 선으로
            // 구분한다 — 그릇을 하나 줄이면 화면에서 경쟁하는 문법이 줄어든다.
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
            HStack {
                Spacer(minLength: 44)
                Text(turn.text)
                    .font(.body)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(
                        Ink.cinnabar.opacity(0.09),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
            }

        case .counselor:
            // 가장 길고 가장 많이 읽는 글이다. 예전에는 가장 갇힌 그릇에
            // 있었다 — 테두리 카드 + 우측 40pt 들여쓰기 + 제목 없음 +
            // 근거 칩 없음. 해석 화면의 `SectionCard`가 이미 "근거 있는
            // 산문"을 그리는 문법을 갖고 있으므로 그것을 쓴다.
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Ink.cinnabar)
                        .frame(width: 3, height: 13)
                    Text("풀이")
                        .font(.subheadline.weight(.semibold))
                    if !turn.isComplete {
                        ProgressView().controlSize(.small).scaleEffect(0.7)
                        // 스피너에 라벨을 붙이지 말라는 지침과, 생성 중에는
                        // 무슨 일이 일어나는지 구체적으로 알리라는 지침이
                        // 어긋난다. 생성 화면에서는 후자를 택한다.
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
                }

                if turn.isComplete {
                    // 배선만 되어 있고 렌더되지 않던 것. ADR 0010 §9의
                    // 제목이 "답변에 근거 칩이 붙는다"인데 붙지 않았다.
                    EvidenceChips(rules: evidence, onRule: onRule)
                    footer
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let provenance {
                HStack(spacing: 4) {
                    Image(systemName: provenance.resolvedDestination.leavesMachine
                        ? "arrow.up.forward.square" : "cpu")
                    Text("\(provenance.modelName) · \(provenance.resolvedDestination.label) · \(provenance.writtenAt.formatted(date: .abbreviated, time: .shortened))")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
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
                // 아래에 붙는다. 사용자가 배터리와 시간을 들여 얻은 문장을
                // 버튼 한 번으로 조용히 지우는 것은 이 저장소의 원칙에
                // 어긋난다 — 비용을 치른 것은 남긴다.
                .help("같은 근거로 다시 씁니다. 지금 답변은 지우지 않고 그 아래에 새로 붙입니다.")
            }
        }
    }
}

/// 근거 칩. 해석 화면과 같은 문법을 쓴다.
///
/// 캡슐 문법을 셋으로 나눈 결과다 — 축 칩(채워진 캡슐 + 선택 상태, 액션),
/// 근거 칩(돋보기 + 외곽선, 정보 열기), 비활성 라벨(캡슐을 쓰지 않음).
/// 예전에는 셋이 거의 같은 모양이어서 무엇이 눌리는지 알 수 없었다.
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
