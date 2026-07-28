import Foundation
import Observation
import Sparkle

/// 자동 업데이트.
///
/// 정책: **조용히 갈아치우지 않는다.** 확인은 자동으로 하되 다운로드와
/// 설치는 사용자가 승인해야 진행한다. 생년월일시를 다루면서 프라이버시를
/// 내세우는 앱이 사용자 모르게 바이너리를 바꾸는 것은 앞뒤가 맞지 않는다.
///
/// 기본값은 `Info.plist`의 `SUEnableAutomaticChecks`(확인 켬)와
/// `SUAutomaticallyUpdate`(자동 설치 끔)로 표현되어 있다.
@MainActor
@Observable
final class UpdateController {
    private let controller: SPUStandardUpdaterController
    private let delegate = UpdateDelegate()

    /// 업데이트 확인 메뉴를 눌러도 되는 상태인가.
    /// Sparkle이 이미 확인 중이면 false가 된다.
    private(set) var canCheck = true

    /// 자동 확인 사용 여부. 설정 화면과 양방향으로 묶인다.
    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    /// 마지막으로 확인한 시각. 확인한 적이 없으면 nil.
    var lastCheckDate: Date? {
        controller.updater.lastUpdateCheckDate
    }

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
        observeCanCheck()
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    private func observeCanCheck() {
        withObservationTracking {
            _ = controller.updater.canCheckForUpdates
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.canCheck = self.controller.updater.canCheckForUpdates
                self.observeCanCheck()
            }
        }
        canCheck = controller.updater.canCheckForUpdates
    }
}

/// Sparkle 델리게이트.
///
/// 이 앱만의 요구사항이 하나 있다. **만세력 계산 규칙이 바뀌는 릴리스는
/// 사용자가 이미 본 명식을 바꿀 수 있다.** 그런 업데이트를 조용히 넘기면
/// 사용자는 앱이 틀렸다고 생각한다. appcast 항목에 계산 변경 표시가 있으면
/// 기록해 두었다가 설치 후 앱이 알린다.
private final class UpdateDelegate: NSObject, SPUUpdaterDelegate {
    /// appcast에서 계산 변경을 표시하는 채널 이름.
    /// 일반 채널만 구독하므로 이 값은 표시용으로만 읽는다.
    static let calculationChangeKey = "fourEightCalculationChanged"

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        // appcast의 <sparkle:criticalUpdate> 또는 커스텀 노드로 표시된다.
        let changesCalculation = item.propertiesDictionary[Self.calculationChangeKey] != nil
        UserDefaults.standard.set(changesCalculation, forKey: "pendingCalculationChangeNotice")
        UserDefaults.standard.set(item.displayVersionString, forKey: "pendingCalculationChangeVersion")
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        // Info.plist의 SUFeedURL을 그대로 쓴다. 채널을 나누지 않는다.
        // 사용자가 없는 상태에서 베타 채널은 관리 비용만 늘린다.
        nil
    }
}
