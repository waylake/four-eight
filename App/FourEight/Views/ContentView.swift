import SwiftUI
import SajuKit

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        NavigationSplitView {
            PeopleSidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        } content: {
            Group {
                if let reading = appState.reading {
                    PillarsCanvasView(reading: reading)
                } else {
                    EmptyCanvasView()
                }
            }
            .navigationSplitViewColumnWidth(min: 500, ideal: 560)
        } detail: {
            Group {
                if let reading = appState.reading {
                    InterpretationPanel(reading: reading)
                } else {
                    ContentUnavailableView(
                        "해석",
                        systemImage: "text.book.closed",
                        description: Text("인물을 선택하면 명식 해석이 표시됩니다.")
                    )
                }
            }
            .navigationSplitViewColumnWidth(min: 320, ideal: 380)
        }
        .sheet(isPresented: $state.isAddingPerson) {
            BirthInputSheet(mode: .add)
        }
        .sheet(item: $state.editingPerson) { person in
            BirthInputSheet(mode: .edit(person))
        }
    }
}

/// 인물 미선택 상태.
struct EmptyCanvasView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 20) {
            Text("四八")
                .font(.hanja(size: 72))
                .foregroundStyle(.tertiary)
            Text("사주 명식을 계산할 인물을 추가하세요")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("생년월일시는 이 Mac을 벗어나지 않습니다.")
                .font(.callout)
                .foregroundStyle(.tertiary)
            Button("새 인물 추가") {
                appState.isAddingPerson = true
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
