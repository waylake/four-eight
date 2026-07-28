import SwiftUI
import SajuKit

@main
struct FourEightApp: App {
    @State private var appState = AppState()
    @State private var modelManager = ModelManager()
    @State private var interpretations = InterpretationStore()
    @State private var consultations = ConsultationStore()
    @State private var updates = UpdateController()

    init() {
        // README용 스크린샷 생성 모드. 화면 기록 권한 없이 뷰를 직접 렌더링한다.
        if let path = ScreenshotRunner.requestedPath {
            DispatchQueue.main.async { ScreenshotRunner.run(outputPath: path) }
        }
    }

    var body: some Scene {
        // 단일 창. 명식은 문서가 아니라 사람이고, 사람은 사이드바로 고른다.
        // 창을 여러 개 열 수 있게 두면 같은 인물의 해석이 창마다 따로
        // 생성되어 배터리만 쓴다.
        Window("FourEight", id: "main") {
            ContentView()
                .environment(appState)
                .environment(modelManager)
                .environment(interpretations)
                .environment(consultations)
                .frame(minWidth: 1000, minHeight: 660)
        }
        .defaultSize(width: 1180, height: 780)
        .commands {
            // SwiftUI 기본 ⌘N은 새 창을 연다. 그대로 두면 새 창이 뜨면서
            // 해석이 처음부터 다시 생성된다. 명령 자체를 대체한다.
            CommandGroup(replacing: .newItem) {
                Button("새 인물 추가…") {
                    appState.isAddingPerson = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            // macOS 관례상 "업데이트 확인"은 앱 메뉴의 정보 바로 아래에 온다.
            CommandGroup(after: .appInfo) {
                Button("업데이트 확인…") {
                    updates.checkForUpdates()
                }
                .disabled(!updates.canCheck)
            }
            CommandGroup(after: .toolbar) {
                Divider()
                Button("오늘") { appState.destination = .today }
                    .keyboardShortcut("1", modifiers: .command)
                Button("캘린더") { appState.destination = .calendar }
                    .keyboardShortcut("2", modifiers: .command)
                Button("명식") { appState.destination = .chart }
                    .keyboardShortcut("3", modifiers: .command)
                Button("상담") { appState.destination = .consultation }
                    .keyboardShortcut("4", modifiers: .command)
                Divider()
                Button("오늘로 이동") {
                    appState.selectedDate = nil
                    appState.visibleMonth = Date()
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
                .environment(modelManager)
                .environment(updates)
        }

        MenuBarExtra {
            TodayMenuView()
                .environment(appState)
        } label: {
            Text(PillarsEngine.dayGanji(on: Date(), timeZone: .current).hanja)
        }
        .menuBarExtraStyle(.window)
    }
}
