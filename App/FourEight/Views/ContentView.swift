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
        // `HSplitView`가 아니라 `HStack`이다. 근거는 ADR 0013에 있다.
        // 실측하면 이 화면의 `HSplitView`는 min 460 + 320 = 780을 선언해
        // 두었는데도 상세 칸을 **1089** 밑으로 내려 주지 않았다.
        HStack(spacing: 0) {
            PillarsCanvasView(reading: reading)
                .frame(minWidth: 460, idealWidth: 560)
            Divider()
            // 상한을 둔다. `HStack`은 남는 폭을 유연한 자식에게 나눠 주므로,
            // 상한이 없으면 **곁칸이 먼저 자라고 본문이 최소에 눌린 채로**
            // 남는다. 실측에서 상세 892일 때 명식 캔버스가 460(최소)에 붙고
            // 해석 패널이 431까지 자랐다. 남는 폭은 본문이 가져가야 한다.
            InterpretationPanel(reading: reading)
                .frame(minWidth: 320, idealWidth: 400, maxWidth: 460)
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
