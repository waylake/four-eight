import Foundation
import Observation
import RemoteLLM

/// 원격 제공자 설정.
///
/// `ModelManager`가 온디바이스 모델을 세 층으로 나눠 말하는 것과 같은
/// 구조를 쓴다. 그 층 나누기는 실제로 겪은 버그에서 나왔다 — 세션 수명
/// 값으로 영구적 의사를 판단하면 앱을 껐다 켠 사용자에게 "설정을 다시
/// 하라"고 보인다.
///
/// | 층 | 뜻 | 수명 |
/// |---|---|---|
/// | 설정됨 | 주소와 모델 이름이 있다 | 영구 (`config`) |
/// | 키가 있음 | 키체인에 키가 있다 | 영구 (Keychain) |
/// | 확인됨 | 이 주소가 실제로 응답한 적이 있다 | 영구 (`verification`) |
/// | 동의됨 | 무엇이 나가는지 보고 확인했다 | 영구 (`acknowledgedHosts`) |
///
/// 온디바이스에 있던 "적재됨"에 해당하는 층이 없다. 원격은 메모리에 올릴
/// 것이 없기 때문이다. 그래서 원격을 고른 사용자에게는 "처음 한 번은 몇 초
/// 더 걸립니다"라는 안내가 나가지 않는다 — 사실이 아니므로.
@MainActor
@Observable
final class RemoteProviderStore {
    struct Config: Codable, Equatable, Sendable {
        /// 정규화된 API 뿌리. `Endpoint.normalize`를 통과한 값만 들어온다.
        var base: URL
        var model: String
        var compatibility: ChatRequest.Compatibility
        /// 사용자가 정한 출력 토큰 상한. **nil이 기본이고 권장값이다.**
        ///
        /// 비워 두면 요청에 항목 자체가 실리지 않고 제공자의 기본값이 쓰인다.
        /// 앱이 고를 수 있는 옳은 숫자가 없기 때문이다 — 같은 모델이
        /// 업스트림 라우트에 따라 출력 상한이 32배로 갈린다.
        ///
        /// 요금을 묶고 싶은 사용자를 위해 남겨 둔다. 추론 모델에서 낮게
        /// 잡으면 생각만 하다 끝나므로 화면에서 그 사실을 알린다.
        ///
        /// 옵셔널이라 이 항목이 없는 예전 설정도 그대로 디코드된다.
        var maxTokens: Int?

        var endpoint: Endpoint { Endpoint(base: base) }
        var destination: Destination { endpoint.destination }
    }

    /// 이 주소가 실제로 응답한 기록.
    ///
    /// "확인됨"을 세션 값으로 두면 앱을 껐다 켤 때마다 사용자에게 다시
    /// 확인하라고 보인다. 파일도 설정도 그대로인데 메모리에만 없어서
    /// 생기는 오해이며, 이 저장소가 이미 한 번 겪은 실수다.
    struct Verification: Codable, Equatable, Sendable {
        var at: Date
        var host: String
        var model: String
        /// 무엇으로 확인했는가. 화면에 그대로 적는다.
        var evidence: String
    }

    private(set) var config: Config?
    private(set) var verification: Verification?
    /// 무엇이 나가는지 보고 확인한 호스트.
    ///
    /// 호스트 단위인 이유는 호스트가 프라이버시 경계이기 때문이다. 같은
    /// 제공자에서 모델만 바꾸는 것은 글이 가는 곳을 바꾸지 않으므로 다시
    /// 묻지 않는다. 주소를 바꾸면 다시 묻는다.
    private(set) var acknowledgedHosts: Set<String>
    /// 제공자가 보고한 마지막 사용량. 보고하지 않는 제공자도 있고, 그때는 nil이다.
    private(set) var lastUsage: (prompt: Int?, completion: Int?)?

    private let defaults: UserDefaults
    private enum Keys {
        static let config = "remoteProvider"
        static let verification = "remoteProviderVerification"
        static let acknowledged = "remoteProviderAcknowledgedHosts"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        config = Self.decode(Config.self, from: defaults, key: Keys.config)
        verification = Self.decode(Verification.self, from: defaults, key: Keys.verification)
        acknowledgedHosts = Set(defaults.stringArray(forKey: Keys.acknowledged) ?? [])
    }

    // MARK: - 층

    var isConfigured: Bool { config != nil }

    /// 키체인 계정 이름. 주소가 키를 구분한다.
    var keyAccount: String? { config?.base.absoluteString }

    var hasKey: Bool {
        guard let keyAccount else { return false }
        return Secrets.exists(account: keyAccount)
    }

    var destination: Destination? { config?.destination }

    /// 이 주소로 보내려면 사용자에게 무엇이 나가는지 먼저 보여야 하는가.
    ///
    /// 이 Mac 안이면 묻지 않는다. 글이 기기를 벗어나지 않으므로 물을 것이
    /// 없고, 물으면 경고가 두 번째 의미를 잃는다.
    var needsAcknowledgement: Bool {
        guard let destination, destination.leavesMachine, let host = destination.host
        else { return false }
        return !acknowledgedHosts.contains(host)
    }

    /// AI 기능을 제시해도 되는가.
    ///
    /// 동의 여부는 보지 않는다. 동의는 생성 버튼을 누른 뒤의 첫 단계이지
    /// 기능을 감출 이유가 아니다 — 감추면 사용자는 설정을 했는데 아무
    /// 버튼도 안 보이는 상태에 놓인다.
    ///
    /// 키는 이 Mac 밖일 때만 요구한다. 로컬 Ollama와 LM Studio는 키 없이
    /// 도는 것이 기본값이고, 그것을 "설정 미완료"로 다루면 정상 구성을
    /// 앱이 거절하게 된다.
    var isUsable: Bool {
        guard let config else { return false }
        guard !config.model.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return config.destination.leavesMachine ? hasKey : true
    }

    /// 화면에 적을 이름. 어디로 가는지가 이름에 들어간다.
    var label: String? {
        guard let config, let destination else { return nil }
        return "\(config.model) · \(destination.label)"
    }

    // MARK: - 사용자의 조작

    /// 주소와 모델을 정한다.
    ///
    /// 호스트가 바뀌면 동의를 지운다. 새 목적지에 대해 예전 동의를
    /// 물려주면, 사용자는 A에 보내겠다고 했는데 B로 나간다.
    func configure(
        base: URL,
        model: String,
        compatibility: ChatRequest.Compatibility,
        maxTokens: Int? = nil
    ) {
        let previousHost = config?.destination.host
        config = Config(
            base: base, model: model, compatibility: compatibility, maxTokens: maxTokens
        )
        persistConfig()

        let newHost = config?.destination.host
        if previousHost != newHost {
            verification = nil
            persistVerification()
        }
    }

    func setCompatibility(_ compatibility: ChatRequest.Compatibility) {
        guard var config else { return }
        config.compatibility = compatibility
        self.config = config
        persistConfig()
    }

    /// 사용자가 무엇이 나가는지 보고 확인했다.
    func acknowledge(host: String) {
        acknowledgedHosts.insert(host)
        defaults.set(Array(acknowledgedHosts), forKey: Keys.acknowledged)
    }

    /// 동의를 되돌린다. 다음 생성에서 다시 무엇이 나가는지 보여준다.
    func revokeAcknowledgement(host: String) {
        acknowledgedHosts.remove(host)
        defaults.set(Array(acknowledgedHosts), forKey: Keys.acknowledged)
    }

    func record(verification: Verification) {
        self.verification = verification
        persistVerification()
    }

    func record(usage prompt: Int?, _ completion: Int?) {
        guard prompt != nil || completion != nil else { return }
        lastUsage = (prompt, completion)
    }

    /// 설정을 지운다. 키도 함께 지운다 — 주소가 없으면 그 키를 다시 쓸
    /// 방법이 없고, 남겨 두면 키체인에 주인 없는 비밀이 남는다.
    func clear() throws {
        if let keyAccount { try Secrets.remove(account: keyAccount) }
        config = nil
        verification = nil
        lastUsage = nil
        defaults.removeObject(forKey: Keys.config)
        defaults.removeObject(forKey: Keys.verification)
    }

    // MARK: - 보내는 쪽 만들기

    /// 키를 읽지 못했을 때 화면에 남기는 말. 생성 버튼을 누른 자리에서
    /// 보여야 하므로 상태로 들고 있는다.
    private(set) var keyProblem: String?

    /// 보낼 준비를 한다. **생성을 시작하기 전에 부른다.**
    ///
    /// 키체인 읽기를 여기서 한 번만 하는 것이 중요하다. 업데이트 직후
    /// 첫 읽기에서는 macOS가 승인 대화상자를 띄우는데, 그것이 스트리밍
    /// 도중에 뜨면 사용자는 문장이 나오다 멈춘 자리에서 암호를 묻는 창을
    /// 만난다. 무슨 일이 일어난 것인지 알 수 없는 화면이다.
    ///
    /// nil을 돌려주면 준비 실패이고, 이유는 `keyProblem`에 남는다.
    func writer() -> RemoteWriter? {
        guard let config else { return nil }
        let leaves = config.destination.leavesMachine

        var key: String?
        switch Secrets.lookup(account: config.base.absoluteString) {
        case .found(let value):
            key = value
            keyProblem = nil
        case .absent:
            // 키가 없는 것은 이 Mac 안의 엔드포인트에서는 정상이다.
            // 밖으로 나가는데 키가 없으면 401을 받으러 가는 것이므로
            // 여기서 멈춘다.
            guard !leaves else {
                keyProblem = "이 주소는 이 Mac 밖이므로 API 키가 필요합니다. 설정에서 키를 넣어 주세요."
                return nil
            }
            keyProblem = nil
        case .needsReentry(let status), .failed(let status):
            let lookup: Secrets.Lookup = status == errSecAuthFailed
                || status == errSecInteractionNotAllowed
                ? .needsReentry(status: status) : .failed(status: status)
            keyProblem = lookup.message
            // 키 없이 보내면 401이 오고, 사용자는 키체인 문제를 인증 문제로
            // 오해한다. 실제 원인을 말하고 멈추는 것이 낫다.
            guard !leaves else { return nil }
        }

        let resolved = key
        let client = ChatClient(
            endpoint: config.endpoint,
            // 이미 읽어 둔 값을 돌려준다. 요청마다 키체인을 다시 두드리면
            // 섹션마다 대화상자가 뜰 수 있다.
            apiKey: { resolved }
        )
        return RemoteWriter(
            client: client,
            model: config.model,
            maxTokens: config.maxTokens,
            compatibility: config.compatibility,
            onUsage: { [weak self] prompt, completion in
                Task { @MainActor [weak self] in
                    self?.record(usage: prompt, completion)
                }
            }
        )
    }

    func clearKeyProblem() { keyProblem = nil }

    // MARK: - 확인

    enum VerifyState: Equatable {
        case idle
        case running
        case succeeded(String)
        case failed(String)
    }

    private(set) var verifyState: VerifyState = .idle

    /// 이 설정이 실제로 되는지 확인한다.
    ///
    /// **`/v1/models`를 부르지 않는다.** 그쪽이 싸고 간단하지만 두 가지를
    /// 확인하지 못한다. 구현하지 않는 제공자가 있고, 더 중요하게는 키를
    /// 검사하지 않고 목록을 내주는 게이트웨이가 있다. 그런 곳에서
    /// `/v1/models`가 200을 주면 앱은 "확인됐다"고 말하고 사용자는 진짜
    /// 생성에서 401을 만난다. 확인이 확인을 하지 않은 것이다.
    ///
    /// 그래서 **진짜로 할 일을 작게 한 번 한다.** 토큰 몇 개어치 요금이
    /// 들지만, 주소·키·모델 이름·스트리밍이 한 번에 검증된다. 알리기 전에
    /// 사슬 전체를 확인하는 것과 같은 이유다.
    func verify() async {
        guard let config else { return }
        verifyState = .running
        guard let writer = writer() else {
            verifyState = .failed(keyProblem ?? "설정이 아직 완전하지 않습니다.")
            return
        }

        let received = CollectedText()
        do {
            try await writer.run(
                system: "당신은 확인용 응답기입니다. 한 낱말로만 답합니다.",
                user: "연결 확인을 위해 '확인'이라고만 답해 주세요."
            ) { delta in
                // 조각은 격리 밖에서 도착한다. 지역 var에 더하면 Swift 6가
                // 막고, 막는 것이 옳다.
                received.append(delta)
            }
        } catch {
            // 제공자가 쓴 원문을 그대로 남긴다. 뭉개면 사용자는 무엇이
            // 틀렸는지 알 수 없다.
            var message = error.localizedDescription
            if case .rejected(let detail) = error as? ProviderError ?? .transport(""),
               let hint = ChatRequest.hint(forRejection: detail) {
                message += "\n\n" + hint.message
            }
            verifyState = .failed(message)
            return
        }

        let answer = received.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let evidence = answer.isEmpty
            ? "응답은 왔지만 본문이 비었습니다."
            : "응답: \(answer.prefix(80))"
        record(verification: Verification(
            at: Date(),
            host: config.destination.host ?? "?",
            model: config.model,
            evidence: evidence
        ))
        verifyState = .succeeded(evidence)
    }

    func clearVerifyState() { verifyState = .idle }

    // MARK: - 키

    /// 키를 넣는다. 실패하면 던진다 — 다른 곳에 대신 저장하지 않는다.
    func storeKey(_ key: String) throws {
        guard let keyAccount else { return }
        try Secrets.store(key, account: keyAccount)
        keyProblem = nil
        // 키가 바뀌면 예전 확인 기록은 더 이상 근거가 아니다.
        verification = nil
        persistVerification()
        verifyState = .idle
    }

    func removeKey() throws {
        guard let keyAccount else { return }
        try Secrets.remove(account: keyAccount)
        verification = nil
        persistVerification()
    }

    // MARK: - 보관

    private func persistConfig() {
        guard let config, let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: Keys.config)
    }

    private func persistVerification() {
        guard let verification else {
            defaults.removeObject(forKey: Keys.verification)
            return
        }
        guard let data = try? JSONEncoder().encode(verification) else { return }
        defaults.set(data, forKey: Keys.verification)
    }

    private static func decode<T: Decodable>(
        _ type: T.Type, from defaults: UserDefaults, key: String
    ) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
