import Foundation
import Observation
import RemoteLLM
import SajuKit

/// **누가 이 문장을 쓰는가.**
///
/// 이 앱에는 문장을 쓸 수 있는 곳이 둘이다 — 이 앱 안의 Gemma, 그리고
/// 사용자가 지정한 OpenAI 호환 엔드포인트. 둘은 같은 슬롯에 들어간다.
///
/// 같은 슬롯에 넣어도 되는지 먼저 물었다. 이 저장소가 가장 비싸게 배운
/// 것이 "같은 슬롯에 두 가지를 넣으면 하나를 켤 때 다른 하나가 지워진다"이고,
/// 그때 문제는 **기준선 문장과 AI 문장**을 한 슬롯에 넣은 것이었다. 그 둘은
/// 비용도(밀리초 대 수십 초) 존재도(항상 대 만들었을 때만) 달랐다.
///
/// 로컬 모델과 원격 제공자는 그렇지 않다. 둘 다 사용자가 주문해야 생기고,
/// 둘 다 비싸고, 둘 다 없어도 앱이 완결된다. 수명주기가 같으므로 한
/// 슬롯이 맞다.
///
/// 대신 **캐시 키에는 절대 들어가지 않는다.** 들어가면 제공자를 설정하는
/// 것이 캐시 전체 무효화와 같은 뜻이 되고, 사용자가 주문하지 않은 재생성이
/// 일어난다. 그 실수를 한 번 했고, 그래서 지금 키는 `subject + signature`
/// 뿐이다. 누가 썼는지는 키가 아니라 `Provenance`에 적는다.
///
/// 이 클래스의 두 번째 일은 그 `Provenance`를 **한 곳에서만 만드는 것**이다.
/// 예전에는 화면마다 손으로 만들었고, 항목이 하나 늘면 어느 화면에서
/// 빠뜨렸는지 알 수 없었다. 목적지는 특히 빠뜨리면 안 되는 항목이다 —
/// 사용자에게 글이 이 Mac을 벗어났는지 말해 주는 유일한 기록이기 때문이다.
@MainActor
@Observable
final class Writers {
    /// 어느 쪽에 주문하는가.
    enum Kind: String, CaseIterable, Codable, Sendable {
        case onDevice
        case remote

        var title: String {
            switch self {
            case .onDevice: "이 Mac에서 (Gemma)"
            case .remote: "지정한 제공자에게"
            }
        }
    }

    let local: ModelManager
    let remote: RemoteProviderStore

    private(set) var preferred: Kind {
        didSet { defaults.set(preferred.rawValue, forKey: Keys.preferred) }
    }

    private enum Keys {
        static let preferred = "preferredWriter"
    }

    /// 주입 가능한 이유는 캡처 때문이다. 스크린샷은 개발자의 설정을 읽으면
    /// 안 된다 — 읽으면 대표 이미지가 그 사람의 제공자 설정에 따라 달라지고,
    /// 실제로 "이 앱 안의 Gemma가 썼다"는 출처와 "제공자를 아직 넣지
    /// 않았습니다"라는 배너가 한 화면에 함께 나오는 자기모순이 찍혔다.
    private let defaults: UserDefaults

    init(local: ModelManager, remote: RemoteProviderStore, defaults: UserDefaults = .standard) {
        self.local = local
        self.remote = remote
        self.defaults = defaults
        // 예전 판에는 이 값이 없었다. 없으면 온디바이스다 — 그때는 그것뿐이었다.
        preferred = defaults.string(forKey: Keys.preferred)
            .flatMap(Kind.init(rawValue:)) ?? .onDevice
    }

    func choose(_ kind: Kind) {
        preferred = kind
    }

    // MARK: - 무엇을 제시할 수 있는가

    /// AI 기능을 화면에 제시해도 되는가.
    ///
    /// 고른 쪽만 본다. 원격을 골랐는데 로컬 모델이 있다는 이유로 버튼을
    /// 보여 주면, 누른 뒤에 엉뚱한 곳으로 나간다.
    var isAvailable: Bool {
        switch preferred {
        case .onDevice: local.isAvailable
        case .remote: remote.isUsable
        }
    }

    /// 지금 주문하면 글이 어디까지 가는가. **설정에서 읽은 예측이다.**
    ///
    /// 이미 화면에 있는 문장의 출처를 이 값으로 표시하면 거짓말이 된다.
    /// 그것은 `Provenance`에서 읽어야 한다. 이 값은 "앞으로 누를 버튼이
    /// 무엇을 할 것인가"에만 쓴다.
    var plannedDestination: Destination {
        switch preferred {
        case .onDevice: .inProcess
        case .remote: remote.destination ?? .inProcess
        }
    }

    /// 다음 생성에서 글이 이 Mac을 벗어나는가.
    var plannedToLeaveMachine: Bool { plannedDestination.leavesMachine }

    /// 보내기 전에 무엇이 나가는지 보여야 하는가.
    var needsAcknowledgement: Bool {
        preferred == .remote && remote.needsAcknowledgement
    }

    /// 첫 문장까지 몇 초 더 걸린다는 사실을 UI가 미리 말할 수 있게.
    ///
    /// 원격은 항상 false다. 올릴 것이 없기 때문이다. 이 구분이 없으면
    /// 원격을 고른 사용자에게 "모델을 불러오는 중"이라고 표시되고, 그것은
    /// 사실이 아니다.
    var needsLoadBeforeUse: Bool {
        preferred == .onDevice && local.needsLoadBeforeUse
    }

    /// 화면에 적을 이름. 무엇이, 어디서.
    var label: String? {
        switch preferred {
        case .onDevice: local.preferredModel?.displayName
        case .remote: remote.label
        }
    }

    /// 준비 실패의 이유. nil이면 문제가 없다.
    var problem: String? {
        switch preferred {
        case .onDevice:
            local.isAvailable ? nil : "쓸 모델을 아직 고르지 않았습니다."
        case .remote:
            remote.keyProblem ?? (remote.isUsable ? nil : remoteSetupHint)
        }
    }

    private var remoteSetupHint: String? {
        guard let config = remote.config else {
            return "제공자 주소와 모델 이름을 아직 넣지 않았습니다."
        }
        if config.model.trimmingCharacters(in: .whitespaces).isEmpty {
            return "모델 이름을 넣어 주세요."
        }
        if config.destination.leavesMachine && !remote.hasKey {
            return "이 주소는 이 Mac 밖이므로 API 키가 필요합니다."
        }
        return nil
    }

    // MARK: - 준비

    /// 해석기와 그 출처. nil이면 준비 실패다.
    func prepareInterpreter(brief: InterpretationBrief) async -> (
        interpreter: any Interpreter, provenance: InterpretationStore.Provenance
    )? {
        switch preferred {
        case .onDevice:
            guard let container = await local.prepare(), let model = local.preferredModel
            else { return nil }
            return (
                GemmaInterpreter(container: container, brief: brief),
                provenance(modelID: model.id, modelName: model.displayName, destination: .inProcess)
            )
        case .remote:
            guard let config = remote.config, let writer = remote.writer() else { return nil }
            return (
                RemoteInterpreter(writer: writer, brief: brief),
                provenance(
                    modelID: "\(config.destination.host ?? "?")/\(config.model)",
                    modelName: config.model,
                    destination: config.destination
                )
            )
        }
    }

    /// 상담가와 그 출처.
    func prepareCounselor(brief: CounselBrief) async -> (
        counselor: any Counselor, provenance: InterpretationStore.Provenance
    )? {
        switch preferred {
        case .onDevice:
            guard let container = await local.prepare(), let model = local.preferredModel
            else { return nil }
            return (
                GemmaCounselor(container: container, brief: brief),
                provenance(modelID: model.id, modelName: model.displayName, destination: .inProcess)
            )
        case .remote:
            guard let config = remote.config, let writer = remote.writer() else { return nil }
            return (
                RemoteCounselor(writer: writer, brief: brief),
                provenance(
                    modelID: "\(config.destination.host ?? "?")/\(config.model)",
                    modelName: config.model,
                    destination: config.destination
                )
            )
        }
    }

    /// 출처를 만드는 **유일한** 자리.
    ///
    /// 화면마다 손으로 만들면 항목이 하나 늘 때 어딘가에서 빠진다. 목적지는
    /// 빠뜨리면 사용자가 글이 나간 것을 모르게 되는 항목이므로, 만드는 곳을
    /// 하나로 둔다.
    private func provenance(
        modelID: String, modelName: String, destination: Destination
    ) -> InterpretationStore.Provenance {
        InterpretationStore.Provenance(
            modelID: modelID,
            modelName: modelName,
            writtenAt: Date(),
            appVersion: AppVersion.marketing,
            ruleSetVersion: SajuService.ruleSet.version,
            destination: destination
        )
    }
}
