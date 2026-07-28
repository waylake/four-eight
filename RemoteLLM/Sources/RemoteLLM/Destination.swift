import Foundation

/// 글이 어디까지 가는가.
///
/// 이 앱은 지금까지 "로컬 모델"과 "원격 API"라는 두 칸으로 생각할 수 있었다.
/// 그 구분은 틀렸다. 실제 경계는 **모델이 어디 있는가**가 아니라
/// **사용자의 글이 이 Mac을 벗어나는가**이고, 셋으로 갈린다.
///
/// | 목적지 | 예 | 글이 이 Mac을 떠나는가 |
/// |---|---|---|
/// | `inProcess` | MLX/Gemma | 아니오 — 프로세스 안에서 끝난다 |
/// | `onMachine` | `localhost`의 Ollama·LM Studio | 아니오 — 루프백은 기기를 벗어나지 않는다 |
/// | `offMachine` | `api.openai.com`, LAN의 다른 Mac | **예** |
///
/// 가운데 칸이 이 타입을 만든 이유다. 같은 집 안에 있는 Ollama에
/// HTTP를 쓰는 것과 남의 서버에 사주를 보내는 것을 "둘 다 원격"으로
/// 묶으면, 앱은 위험하지 않은 일에 경고를 띄우고 위험한 일에 같은 경고를
/// 띄운다. 경고가 두 번째 의미를 잃는다.
///
/// LAN 주소(`192.168.x.x`)는 `onMachine`이 아니라 `offMachine`이다.
/// 옆방 서버도 이 Mac은 아니다.
public enum Destination: Equatable, Hashable, Sendable {
    /// 이 앱의 프로세스 안. 네트워크를 아예 쓰지 않는다.
    case inProcess
    /// 루프백. 네트워크 스택은 쓰지만 패킷이 기기를 벗어나지 않는다.
    case onMachine(host: String)
    /// 이 Mac 밖. 글이 남의 컴퓨터에 도착한다.
    case offMachine(host: String)

    /// 사용자에게 "당신의 글이 나갑니까"라고 물었을 때의 답.
    ///
    /// UI가 봐야 하는 것은 대개 이 한 줄이다. 세 칸을 각각 분기하면
    /// 화면마다 판단이 흩어지고, 한 곳을 고칠 때 다른 곳이 남는다.
    public var leavesMachine: Bool {
        if case .offMachine = self { return true }
        return false
    }

    public var host: String? {
        switch self {
        case .inProcess: nil
        case .onMachine(let host), .offMachine(let host): host
        }
    }

    // MARK: - 판정

    /// 루프백으로 **확실히** 판정되는 호스트만 `onMachine`이 된다.
    ///
    /// 애매하면 `offMachine`이라고 말한다. 이 비대칭은 의도한 것이다.
    /// 틀렸을 때의 대가가 한쪽으로 몰려 있기 때문이다 — 루프백을 원격이라
    /// 부르면 사용자가 필요 없는 확인 화면을 한 번 보고, 원격을 루프백이라
    /// 부르면 사용자는 자기 글이 나간 것을 모른 채로 남는다.
    ///
    /// 그래서 `127.1`처럼 `inet_aton`이 루프백으로 받아 주는 축약 표기도
    /// 여기서는 루프백으로 인정하지 않는다. 실제로 접속은 되지만, 이
    /// 함수가 "확실하다"고 말할 수 있는 형태가 아니다. 과하게 경고하는
    /// 쪽으로 틀린다.
    public static func classify(host rawHost: String) -> Destination {
        let host = rawHost
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            // URLComponents는 IPv6를 대괄호 없이 돌려주지만, 손으로 넣은
            // 문자열에는 남아 있을 수 있다.
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))

        if host == "localhost" || host.hasSuffix(".localhost") {
            // RFC 6761 §6.3 — `localhost`와 그 하위 이름은 루프백으로
            // 해석되어야 한다. 접미사 검사에 점을 포함하는 것이 중요하다.
            // `.localhost`가 아니라 `localhost`로 끝나는 것만 보면
            // `notlocalhost`가 통과한다.
            return .onMachine(host: host)
        }
        if host == "::1" {
            return .onMachine(host: host)
        }
        if isDottedQuadLoopback(host) {
            return .onMachine(host: host)
        }
        return .offMachine(host: host)
    }

    /// 사람이 읽을 이름. 화면과 보관 파일에 함께 쓴다.
    public var label: String {
        switch self {
        case .inProcess: "이 앱 안"
        case .onMachine(let host): "이 Mac (\(host))"
        case .offMachine(let host): host
        }
    }

    /// `127.0.0.0/8` 전체가 루프백이다. `127.0.0.1`만 보면 안 된다 —
    /// `127.0.0.2`로 서버를 띄우는 사람이 실제로 있다.
    ///
    /// 네 마디가 모두 0–255인 점 표기만 받는다. 축약형은 받지 않는다.
    private static func isDottedQuadLoopback(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        let octets = parts.compactMap { part -> Int? in
            // "01"이나 "0x7f"를 숫자로 받아 주면 판정이 표기법마다 갈린다.
            guard !part.isEmpty, part.count <= 3, part.allSatisfy(\.isNumber),
                  let value = Int(part), value >= 0, value <= 255
            else { return nil }
            return value
        }
        guard octets.count == 4 else { return false }
        return octets[0] == 127
    }
}
