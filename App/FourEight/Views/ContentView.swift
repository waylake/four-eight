import SwiftUI
import SajuKit

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 208, ideal: 236, max: 300)
        } detail: {
            Group {
                if let reading = appState.reading {
                    switch appState.page {
                    case .today:
                        TodayView(reading: reading)
                    case .calendar:
                        FortuneCalendarView(reading: reading)
                    case .chart:
                        ChartWorkspace(reading: reading)
                    case .consultation:
                        ConsultationView(reading: reading)
                    }
                } else {
                    WelcomeView()
                }
            }
        }
        .sheet(isPresented: $state.isAddingPerson) {
            BirthInputSheet(mode: .add)
        }
        .sheet(item: $state.editingPerson) { person in
            BirthInputSheet(mode: .edit(person))
        }
    }
}

/// 명식과 해석을 나란히 두는 작업 공간.
struct ChartWorkspace: View {
    let reading: Reading

    var body: some View {
        HSplitView {
            PillarsCanvasView(reading: reading)
                .frame(minWidth: 460, idealWidth: 560)
            InterpretationPanel(reading: reading)
                .frame(minWidth: 320, idealWidth: 400)
        }
        .navigationTitle(reading.person.name)
        .navigationSubtitle(reading.person.birthSummary)
    }
}

struct WelcomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 18) {
            Text("四八")
                .font(.hanja(size: 68))
                .foregroundStyle(.tertiary)
            VStack(spacing: 6) {
                Text("명식을 계산할 인물을 추가하세요")
                    .font(.title3)
                Text("생년월일시는 이 Mac을 벗어나지 않습니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Button("새 인물 추가") {
                appState.isAddingPerson = true
            }
            .keyboardShortcut(.defaultAction)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
