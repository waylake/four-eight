import SwiftUI
import SajuKit

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("유파", systemImage: "slider.horizontal.3") {
                SchoolSettingsView()
            }
            Tab("모델", systemImage: "cpu") {
                ModelManagerView()
            }
            Tab("업데이트", systemImage: "arrow.triangle.2.circlepath") {
                UpdateSettingsView()
            }
            Tab("정보", systemImage: "info.circle") {
                AboutView()
            }
        }
        .frame(width: 520, height: 430)
    }
}

/// 유파 옵션 — 계산 방식 차이를 숨기지 않고 설정으로 드러낸다.
struct SchoolSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        Form {
            Section("진태양시") {
                Picker("보정 방식", selection: $state.options.solarTimeMode) {
                    Text("출생지 경도 기준 (권장)").tag(SajuOptions.SolarTimeMode.longitude)
                    Text("동경 135도 −30분 고정").tag(SajuOptions.SolarTimeMode.fixedMinus30)
                    Text("보정 없음").tag(SajuOptions.SolarTimeMode.none)
                }
                Toggle("균시차 반영", isOn: $state.options.applyEquationOfTime)
                Text("서울 기준 경도 보정은 약 −32분입니다. 국내 만세력 다수는 −30분 고정 또는 경도 기준을 사용합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("자시 경계") {
                Picker("자시 처리", selection: $state.options.jasiPolicy) {
                    Text("야자시·조자시 구분 (기본)").tag(SajuOptions.JasiPolicy.yajasi)
                    Text("자시일수 — 23시에 일주 교체").tag(SajuOptions.JasiPolicy.rollover)
                }
                Text("밤 11시대 출생의 일주 처리는 유파가 갈립니다. 두 방식 모두 정통 계보가 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("대운수") {
                Picker("끝처리", selection: $state.options.daeunRounding) {
                    Text("반올림 — 1일 버림·2일 올림 (통용)").tag(SajuOptions.DaeunRounding.round)
                    Text("버림").tag(SajuOptions.DaeunRounding.floor)
                }
            }
            Section("해석") {
                Toggle("온디바이스 AI 기능 제시", isOn: $state.useLLM)
                Text("해설은 항상 근거 원문으로 조립돼 있습니다. 이 스위치는 그것을 AI 문장으로 다시 쓰는 버튼과 대화 기능을 보이게 할지만 정합니다. 켜 두어도 사용자가 누르지 않으면 생성하지 않습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// 모델 관리 — 설치·활성·삭제.
struct ModelManagerView: View {
    @Environment(ModelManager.self) private var modelManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
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
    }
}

struct ModelRow: View {
    @Environment(ModelManager.self) private var modelManager
    let model: CatalogModel

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.body)
                    if model.recommended {
                        Text("권장")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Ink.cinnabar.opacity(0.12), in: Capsule())
                            .foregroundStyle(Ink.cinnabar)
                    }
                }
                Text("\(model.sizeLabel) · \(model.hfRepo)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let notes = model.notes {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            stateControl
        }
        .padding(.vertical, 4)
        .contextMenu {
            if modelManager.loadedModelID == model.id {
                Button("메모리에서 내리기") { modelManager.unload() }
                    .help("선택은 그대로 남습니다. 다음에 필요할 때 다시 올립니다.")
            }
            if modelManager.preferredModelID == model.id {
                Button("이 모델 쓰지 않기") { modelManager.stopUsing() }
            }
            if modelManager.isInstalled(model) {
                Button("모델 삭제", role: .destructive) { modelManager.delete(model) }
            }
        }
    }

    private var isPreferred: Bool { modelManager.preferredModelID == model.id }

    /// 상태 표기는 세 층을 그대로 따른다. "사용 중"과 "메모리에 있음"을
    /// 구분해서 말해야, 앱을 껐다 켠 사용자가 설정이 풀렸다고 오해하지 않는다.
    @ViewBuilder
    private var stateControl: some View {
        switch modelManager.states[model.id] ?? .notInstalled {
        case .notInstalled:
            Button("내려받아 사용") {
                Task { await modelManager.choose(model) }
            }
        case .downloading(let progress):
            HStack(spacing: 6) {
                ProgressView(value: progress)
                    .frame(width: 90)
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        case .installed:
            if isPreferred {
                VStack(alignment: .trailing, spacing: 1) {
                    Label("사용할 모델", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Ink.cinnabar)
                        .font(.callout)
                    Text("필요할 때 불러옵니다")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Button("사용") {
                    Task { await modelManager.choose(model) }
                }
            }
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("불러오는 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .loaded:
            VStack(alignment: .trailing, spacing: 1) {
                Label("사용할 모델", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Ink.cinnabar)
                    .font(.callout)
                Text("메모리에 올라 있음")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        case .failed(let message):
            Button("재시도") {
                Task { await modelManager.choose(model) }
            }
            .help(message)
        }
    }
}

/// 업데이트 설정.
///
/// 자동 설치 스위치를 두지 않는다. 확인은 자동으로 하되 설치는 사용자가
/// 승인한다는 정책이 제품 결정이지 사용자 취향이 아니기 때문이다.
struct UpdateSettingsView: View {
    @Environment(UpdateController.self) private var updates

    var body: some View {
        @Bindable var updates = updates
        Form {
            Section {
                LabeledContent("현재 버전") {
                    Text(AppVersion.display)
                        .textSelection(.enabled)
                }
                Toggle("업데이트 자동 확인", isOn: $updates.automaticallyChecks)
                LabeledContent("마지막 확인") {
                    if let date = updates.lastCheckDate {
                        Text(date.formatted(.relative(presentation: .named)))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("없음")
                            .foregroundStyle(.tertiary)
                    }
                }
                HStack {
                    Spacer()
                    Button("지금 확인") {
                        updates.checkForUpdates()
                    }
                    .disabled(!updates.canCheck)
                }
            } footer: {
                Text("새 버전을 찾으면 알려 드립니다. 무엇이 바뀌는지 확인하고 직접 승인하셔야 설치됩니다. 이 앱은 사용자 모르게 스스로를 바꾸지 않습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("만세력 계산 규칙이 바뀌는 업데이트는 릴리스 노트에 명시하고, 설치 후 앱이 한 번 더 알려 드립니다. 이미 보신 명식의 결과가 달라질 수 있기 때문입니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("계산이 바뀌는 업데이트")
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("四八")
                        .font(.hanja(size: 34))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FourEight")
                            .font(.title3.weight(.semibold))
                        Text("사주 명식 계산과 온디바이스 해석")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text(AppVersion.display)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }
                    Spacer(minLength: 0)
                }
                Divider()
                Group {
                    labeled("계산 엔진", "SajuKit — VSOP87D 태양 시황경, IAU 1980 장동, Meeus 삭망. 절기·음양력을 이 Mac에서 직접 계산합니다.")
                    labeled("시간 보정", "IANA tzdb 기반 역사 표준시·서머타임(1948–1960, 1987–1988), 출생지 경도 진태양시.")
                    labeled("해석", "결정론적 룰 엔진이 근거를 선별하고, 선택 시 Gemma 4가 문장으로 엮습니다. 모든 해설에 근거가 표시됩니다.")
                    labeled("프라이버시", "생년월일시와 해석은 네트워크로 전송되지 않습니다. 네트워크는 모델 다운로드에만 사용됩니다.")
                }
                Divider()
                Text("이 앱의 해설은 참고용이며 의료·투자·법률 조언이 아닙니다.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("MIT License · © 2026 waylake")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func labeled(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.callout.weight(.semibold))
            Text(body)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
