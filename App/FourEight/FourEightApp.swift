import SwiftUI
import SajuKit

@main
struct FourEightApp: App {
    @State private var appState = AppState()
    @State private var modelManager = ModelManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(modelManager)
                .frame(minWidth: 1080, minHeight: 680)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(after: .newItem) {
                Button("새 인물 추가…") {
                    appState.isAddingPerson = true
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
                .environment(modelManager)
        }

        MenuBarExtra {
            TodayMenuView()
        } label: {
            Text(todayGanjiLabel)
        }
        .menuBarExtraStyle(.window)
    }

    private var todayGanjiLabel: String {
        let ganji = PillarsEngine.dayGanji(on: Date(), timeZone: .current)
        return ganji.hanja
    }
}
