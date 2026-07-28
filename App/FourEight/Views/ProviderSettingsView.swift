import SwiftUI
import RemoteLLM

/// 해석을 누가 쓰는지 정하는 화면.
///
/// 한 화면에 둔 이유는 그것이 한 슬롯이기 때문이다. 위에서 어디에 주문할지
/// 고르고, 아래에 고른 쪽의 설정이 나온다. 두 탭으로 나누면 사용자는 둘 다
/// 켜져 있다고 생각하거나 어느 쪽이 쓰이는지 모른다.
///
/// **제공자 목록을 번들하지 않는다.** 이름과 로고를 늘어놓으면 앱이 그
/// 제공자들을 보증하는 셈이 되는데, 이 앱은 그들이 보낸 글을 어떻게
/// 다루는지 확인할 방법이 없고 정책은 시간이 지나면 바뀐다. 주소와 모델
/// 이름은 더 자주 바뀌므로 번들한 목록은 조용히 썩는다. 대신 도움말에
/// 예시를 글로 적는다 — 글은 기계가 읽지 않으므로 틀렸을 때 조용히
/// 실패하지 않고, 사용자가 보고 판단한다.
struct WriterSettingsView: View {
    @Environment(Writers.self) private var writers
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section {
                @Bindable var state = appState
                Toggle("AI 문장 기능 제시", isOn: $state.useLLM)
                Text("해설은 항상 근거 원문으로 조립돼 있습니다. 이 스위치는 그것을 AI 문장으로 다시 쓰는 버튼과 상담 기능을 보이게 할지만 정합니다. 켜 두어도 사용자가 누르지 않으면 생성하지 않습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if appState.useLLM {
                Section("어디에 주문할까요") {
                    Picker("쓰는 곳", selection: writerBinding) {
                        ForEach(Writers.Kind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    destinationNote
                }

                switch writers.preferred {
                case .onDevice:
                    OnDeviceSection()
                case .remote:
                    RemoteProviderSection()
                }
            }
        }
        .formStyle(.grouped)
    }

    private var writerBinding: Binding<Writers.Kind> {
        Binding(get: { writers.preferred }, set: { writers.choose($0) })
    }

    /// 고른 쪽이 무엇을 뜻하는지 한 문장으로. 목적지 세 칸을 그대로 말한다.
    private var destinationNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: writers.plannedToLeaveMachine
                ? "arrow.up.forward.square" : "lock")
                .foregroundStyle(writers.plannedToLeaveMachine ? Ink.cinnabar : .secondary)
            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var explanation: String {
        switch writers.plannedDestination {
        case .inProcess:
            "명식과 근거, 적어 주신 글이 이 앱 안에서만 다뤄집니다. 네트워크는 모델을 내려받을 때만 씁니다."
        case .onMachine(let host):
            "이 Mac에서 도는 \(host)로 보냅니다. 루프백이므로 글이 기기를 벗어나지 않습니다."
        case .offMachine(let host):
            "명식 근거와 적어 주신 글이 \(host)로 전송됩니다. 처음 보내기 전에 무엇이 나가는지 보여 드립니다."
        }
    }
}

// MARK: - 이 Mac

private struct OnDeviceSection: View {
    @Environment(ModelManager.self) private var modelManager

    var body: some View {
        Section {
            ForEach(ModelCatalog.models) { model in
                ModelRow(model: model)
            }
        } header: {
            Text("Gemma 4 (Apache 2.0)")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("모델은 Hugging Face에서 내려받아 이 Mac에만 저장됩니다. 다운로드 후 해석은 네트워크 없이 동작합니다.")
                Text("한 번 고르면 앱을 껐다 켜도 선택이 남습니다. 메모리 적재는 AI 문장을 처음 주문할 때 자동으로 일어나므로, 이 화면에 다시 오실 일은 없습니다.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 원격 제공자

private struct RemoteProviderSection: View {
    @Environment(RemoteProviderStore.self) private var provider

    @State private var rawBase = ""
    @State private var model = ""
    @State private var key = ""
    @State private var maxTokensText = ""
    @State private var saveError: String?
    @State private var showsCompatibility = false

    /// 사용자가 지금 넣은 주소를 정규화한 결과. 입력할 때마다 다시 계산한다.
    private var normalized: Result<Endpoint, Endpoint.Invalid>? {
        guard !rawBase.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        do {
            return .success(try Endpoint.normalize(rawBase))
        } catch {
            return .failure(error)
        }
    }

    private var endpoint: Endpoint? {
        if case .success(let endpoint) = normalized { return endpoint }
        return nil
    }

    var body: some View {
        Section("주소와 모델") {
            TextField("API 뿌리 주소", text: $rawBase, prompt: Text("https://api.example.com/v1"))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: rawBase) { provider.clearVerifyState() }

            resolvedURLRow

            TextField("모델 이름", text: $model, prompt: Text("gpt-4o-mini"))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: model) { provider.clearVerifyState() }
        }

        keySection
        actionSection
        compatibilitySection
        stateSection
        helpSection

        // 저장된 설정을 칸에 되살린다. 읽기뿐이므로 화면이 나타날 때
        // 불러도 안전하다 — 생성이나 전송이 일어나지 않는다.
        //
        // 키는 되살리지 않는다. 값을 읽으면 키체인 승인 대화상자가 뜰 수
        // 있고, 설정 화면을 여는 것만으로 암호를 묻는 앱이 되기 때문이다.
        // 있는지 없는지만 표시한다.
        Color.clear.frame(height: 0)
            .onAppear {
                guard let config = provider.config else { return }
                if rawBase.isEmpty { rawBase = config.base.absoluteString }
                if model.isEmpty { model = config.model }
                if maxTokensText.isEmpty, let cap = config.maxTokens {
                    maxTokensText = String(cap)
                }
            }
    }

    // MARK: 실제로 호출되는 주소

    /// **기계가 한 일을 보여준다.**
    ///
    /// 빈 경로에 `/v1`을 몰래 붙이지 않기로 했으므로, 사용자가 그것을 알
    /// 방법이 있어야 한다. 최종 주소를 그대로 보여주면 `/v1`이 빠진 것도
    /// 경로를 두 번 붙인 것도 눈으로 보인다. 짐작을 잘하는 것보다 낫다.
    @ViewBuilder
    private var resolvedURLRow: some View {
        switch normalized {
        case .success(let endpoint):
            VStack(alignment: .leading, spacing: 3) {
                LabeledContent("실제 호출 주소") {
                    Text(endpoint.chatCompletions.absoluteString)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 5) {
                    Image(systemName: endpoint.destination.leavesMachine
                        ? "arrow.up.forward.square" : "lock")
                    Text(endpoint.destination.leavesMachine
                        ? "이 Mac 밖입니다. 글이 전송됩니다."
                        : "이 Mac 안입니다. 글이 기기를 벗어나지 않습니다.")
                }
                .font(.caption2)
                .foregroundStyle(endpoint.destination.leavesMachine ? Ink.cinnabar : .secondary)
            }
        case .failure(let error):
            Label(error.message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(Ink.cinnabar)
        case nil:
            EmptyView()
        }
    }

    // MARK: 키

    @ViewBuilder
    private var keySection: some View {
        Section {
            SecureField("API 키", text: $key, prompt: Text(provider.hasKey ? "저장돼 있습니다" : "sk-…"))
                .textFieldStyle(.roundedBorder)
            if let problem = provider.keyProblem {
                Label(problem, systemImage: "key.slash")
                    .font(.caption)
                    .foregroundStyle(Ink.cinnabar)
            }
            if let saveError {
                Label(saveError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Ink.cinnabar)
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("키는 이 Mac의 키체인에만 저장됩니다. 저장에 실패하면 다른 곳에 대신 저장하지 않고 실패를 알려 드립니다 — 평문으로 남는 것이 잃는 것보다 나쁩니다.")
                // 마찰을 숨기지 않는다. 사용자가 이 화면을 만났을 때
                // "문서에서 본 그거다"라고 알아볼 수 있어야 한다.
                Text("이 앱은 Apple 개발자 인증서로 서명되지 않았습니다. 그래서 앱을 업데이트하면 키체인이 새 버전을 다른 프로그램으로 보고 저장된 키를 내주지 않을 수 있습니다. 그때는 여기서 키를 한 번 더 넣어 주셔야 합니다.")
                Text("이 Mac에서 도는 Ollama나 LM Studio는 보통 키가 필요 없습니다. 비워 두셔도 됩니다.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: 저장과 확인

    private var canSave: Bool {
        endpoint != nil && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @ViewBuilder
    private var actionSection: some View {
        Section {
            HStack {
                Button("저장") { save() }
                    .disabled(!canSave)
                Button("저장하고 확인") {
                    save()
                    Task { await provider.verify() }
                }
                .disabled(!canSave)
                .buttonStyle(.borderedProminent)
                Spacer()
                if provider.isConfigured {
                    Button("설정 지우기", role: .destructive) { clear() }
                        .controlSize(.small)
                }
            }
            verifyRow
        } footer: {
            Text("확인은 짧은 요청을 실제로 한 번 보냅니다. 모델 목록만 받아 보는 방식은 키를 검사하지 않고 목록을 내주는 곳에서 통과해 버리므로, 진짜로 할 일을 작게 한 번 합니다. 토큰 몇 개어치 요금이 들 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var verifyRow: some View {
        switch provider.verifyState {
        case .idle:
            EmptyView()
        case .running:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("확인하는 중…").font(.caption).foregroundStyle(.secondary)
            }
        case .succeeded(let evidence):
            Label("연결됐습니다 — \(evidence)", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Label("확인 실패", systemImage: "xmark.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Ink.cinnabar)
                // 제공자가 쓴 원문을 그대로 보여준다. 뭉개면 사용자는
                // 주소가 틀린 것인지 키가 틀린 것인지 알 수 없다.
                Text(message)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: 호환

    /// 제공자마다 갈리는 지점.
    ///
    /// 만세력의 유파 차이를 설정으로 드러낸 것과 같은 이유로 여기에 둔다.
    /// 다만 한 가지가 다르다 — 어느 쪽이 맞는지 **서버가 알려 준다.** 그래서
    /// 미리 고르게 하지 않고 접어 두고, 400이 오면 그 원문과 함께 해당
    /// 스위치를 짚어 준다.
    @ViewBuilder
    private var compatibilitySection: some View {
        Section(isExpanded: $showsCompatibility) {
            Toggle("max_tokens 대신 max_completion_tokens", isOn: compat(\.usesMaxCompletionTokens))
            Toggle("온도를 보내지 않기", isOn: compat(\.omitsTemperature))
            Toggle("시스템 지시를 사용자 메시지에 합치기", isOn: compat(\.foldsSystemIntoUser))
            Toggle("토큰 사용량 보고 요청 (stream_options)", isOn: compat(\.requestsUsage))
            Text("OpenAI 호환을 자칭하는 구현은 많지만 규격을 전부 따르는 곳은 드뭅니다. 기본값은 가장 좁은 요청이며, 제공자가 거절하면 위의 확인 결과에 어느 항목이 문제인지 표시됩니다. 그때 해당 스위치만 켜 주세요.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            LabeledContent("출력 토큰 상한") {
                TextField("비움 = 제공자 기본값", text: $maxTokensText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .font(.system(.body, design: .monospaced))
            }
            // 여기가 이 앱을 못 쓰게 만들었던 자리다. 사실을 그대로 적는다.
            Text("비워 두시는 것을 권합니다. 앱이 고를 수 있는 옳은 숫자가 없습니다 — 같은 모델도 제공자 라우트에 따라 출력 상한이 32배까지 갈립니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("추론 모델(DeepSeek·o 계열·Gemini 등)에서는 이 상한을 **생각과 답변에 함께** 씁니다. 낮게 잡으면 모델이 생각만 하다 끝나고 답변이 한 글자도 나오지 않으면서 요금은 나갑니다. OpenAI는 25,000 이상을 권합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("호환 (대개 건드릴 필요가 없습니다)")
        }
    }

    private func compat(
        _ path: WritableKeyPath<ChatRequest.Compatibility, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { provider.config?.compatibility[keyPath: path] ?? false },
            set: { newValue in
                var compatibility = provider.config?.compatibility ?? .init()
                compatibility[keyPath: path] = newValue
                provider.setCompatibility(compatibility)
                provider.clearVerifyState()
            }
        )
    }

    // MARK: 상태

    @ViewBuilder
    private var stateSection: some View {
        if provider.isConfigured {
            Section("지금 상태") {
                LabeledContent("설정됨") {
                    Text(provider.label ?? "—").foregroundStyle(.secondary)
                }
                LabeledContent("키") {
                    Text(provider.hasKey ? "키체인에 있음" : "없음")
                        .foregroundStyle(.secondary)
                }
                if let verification = provider.verification {
                    LabeledContent("마지막 확인") {
                        Text(verification.at.formatted(.relative(presentation: .named)))
                            .foregroundStyle(.secondary)
                    }
                }
                if let usage = provider.lastUsage {
                    LabeledContent("마지막 요청 토큰") {
                        Text(usageLabel(usage)).foregroundStyle(.secondary)
                    }
                }
                if let host = provider.destination?.host,
                   provider.destination?.leavesMachine == true {
                    LabeledContent("전송 확인") {
                        if provider.acknowledgedHosts.contains(host) {
                            HStack(spacing: 6) {
                                Text("\(host)에 대해 확인함").foregroundStyle(.secondary)
                                Button("다시 묻게 하기") {
                                    provider.revokeAcknowledgement(host: host)
                                }
                                .controlSize(.small)
                            }
                        } else {
                            Text("처음 보낼 때 보여 드립니다").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    /// 사용량은 제공자가 보고할 때만 적는다. 보고하지 않으면 0을
    /// 만들어내지 않는다 — 모른다고 말하는 것이 지어내는 것보다 낫다.
    private func usageLabel(_ usage: (prompt: Int?, completion: Int?)) -> String {
        var parts: [String] = []
        if let prompt = usage.prompt { parts.append("프롬프트 \(String(prompt))") }
        if let completion = usage.completion { parts.append("답변 \(String(completion))") }
        return parts.isEmpty ? "보고되지 않음" : parts.joined(separator: " · ")
    }

    // MARK: 도움말

    /// 예시를 **글로** 적는다. 목록으로 번들해 기계가 읽게 하면 주소가
    /// 바뀌었을 때 조용히 실패하고, 이름을 늘어놓으면 보증이 된다.
    private var helpSection: some View {
        Section("주소를 어떻게 넣는가") {
            VStack(alignment: .leading, spacing: 6) {
                Text("`/chat/completions`를 지원하는 OpenAI 호환 엔드포인트면 됩니다. 주소는 그 앞까지 넣으시고, 전체 경로를 붙여넣으셔도 알아서 잘라냅니다.")
                Text("경로를 짐작해 채우지 않습니다. 대부분의 제공자가 `/v1`로 끝나지만 전부는 아니고(예: 뿌리가 `/openai/v1`인 곳도 있습니다), 짐작이 틀리면 404가 나면서 사용자는 자기가 넣은 주소가 쓰였다고 믿게 됩니다. 그래서 위에 실제 호출 주소를 그대로 보여 드립니다.")
                Text("이 Mac에서 도는 서버라면 `http://localhost:포트/v1` 형태입니다. 이 Mac 밖으로는 평문 `http`를 보내지 않습니다 — API 키와 적어 주신 글이 중간에 그대로 읽힙니다.")
                Text("게이트웨이 구독을 쓰시는 경우, 모델에 따라 `/chat/completions`가 아닌 다른 규격으로 라우팅되는 곳이 있습니다. 그런 모델은 이 앱에서 동작하지 않으므로, 위의 확인 버튼으로 실제로 되는지 보시는 편이 빠릅니다.")
                Text("보낸 글을 제공자가 어떻게 다루는지(학습 사용 여부, 보관 기간)는 이 앱이 알 수 없습니다. 그 부분은 제공자의 정책을 직접 확인하셔야 합니다.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: 동작

    private func save() {
        guard let endpoint else { return }
        saveError = nil
        // 숫자로 읽히지 않으면 상한 없음으로 둔다. 0이나 음수도 그렇게
        // 다룬다 — Roo Code가 `max_completion_tokens: -1`을 와이어에 실어
        // 보내는 버그가 실제로 있다.
        let cap = Int(maxTokensText.trimmingCharacters(in: .whitespaces))
        provider.configure(
            base: endpoint.base,
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            compatibility: provider.config?.compatibility ?? .init(),
            maxTokens: (cap ?? 0) > 0 ? cap : nil
        )
        let typed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return }
        do {
            try provider.storeKey(typed)
            // 화면에서 지운다. 저장한 뒤에도 칸에 남겨 두면 스크린샷과
            // 화면 공유에 키가 남는다.
            key = ""
        } catch let failure as Secrets.Failure {
            saveError = failure.message
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func clear() {
        do {
            try provider.clear()
            rawBase = ""
            model = ""
            key = ""
            maxTokensText = ""
            saveError = nil
        } catch let failure as Secrets.Failure {
            saveError = failure.message
        } catch {
            saveError = error.localizedDescription
        }
    }
}
