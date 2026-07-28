import Foundation

/// OpenAI 호환 엔드포인트 주소.
///
/// 사용자는 이 칸에 온갖 것을 붙여넣는다. `https://api.openai.com`,
/// `.../v1`, `.../v1/`, `.../v1/chat/completions`, 스킴 없는 `api.x.com/v1`.
/// 앞의 셋은 같은 뜻이고 넷째는 사용자가 문서에서 복사한 전체 경로다.
///
/// **비어 있는 경로에 `/v1`을 몰래 붙이지 않는다.** 대부분의 제공자가
/// `/v1`을 쓰지만 전부는 아니고(게이트웨이는 임의 경로에 뿌리를 둔다),
/// 짐작이 맞을 때는 아무 일도 없지만 틀리면 404가 나면서 사용자는 자기가
/// 넣은 주소가 그대로 쓰였다고 믿는다. 대신 **최종 호출 주소를 화면에
/// 그대로 보여준다.** 기계가 한 일을 보여주는 것이 짐작을 잘하는 것보다
/// 낫고, 틀렸을 때 사용자가 스스로 고칠 수 있다.
public struct Endpoint: Equatable, Hashable, Sendable, Codable {
    /// 정규화된 API 뿌리. 뒤에 `chat/completions`가 붙는다.
    /// 항상 슬래시로 끝난다 — 상대 경로 해석을 예측 가능하게 두려는 것이다.
    public let base: URL

    public var destination: Destination {
        guard let host = base.host() else { return .offMachine(host: "?") }
        return Destination.classify(host: host)
    }

    /// 실제로 POST할 주소. 설정 화면이 이 값을 그대로 표시한다.
    public var chatCompletions: URL {
        base.appending(path: "chat/completions")
    }

    /// 모델 목록. 제공자가 구현하지 않는 경우도 있다.
    public var models: URL {
        base.appending(path: "models")
    }

    // MARK: - 정규화

    public enum Invalid: Error, Equatable, Sendable {
        case empty
        case notAURL
        case unsupportedScheme(String)
        /// 이 Mac 밖으로 평문 HTTP를 보내려 한다.
        case plaintextOffMachine(host: String)
        case missingHost
    }

    /// 사용자가 넣은 문자열에서 엔드포인트를 만든다.
    ///
    /// 하는 일:
    /// - 앞뒤 공백을 버린다. 붙여넣기에는 거의 항상 딸려 온다.
    /// - 스킴이 없으면 `https://`로 읽는다. 스킴 없는 문자열은
    ///   `URL`이 상대 경로로 해석해 호스트가 사라지므로 이 보정은
    ///   짐작이 아니라 파싱을 성립시키는 최소 조건이다.
    /// - 경로 끝의 `/chat/completions`를 떼어낸다. 문서에서 복사한
    ///   전체 경로를 그대로 붙여넣는 것이 가장 흔한 입력이다.
    /// - 질의 문자열과 프래그먼트를 버린다. 여기 붙어 있으면 경로를
    ///   이어붙일 때 조용히 망가진다.
    ///
    /// 하지 않는 일:
    /// - 빈 경로에 `/v1`을 붙이지 않는다.
    /// - 호스트를 고쳐 주지 않는다.
    public static func normalize(_ raw: String) throws(Invalid) -> Endpoint {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty }

        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard var components = URLComponents(string: withScheme) else { throw .notAURL }

        components.query = nil
        components.fragment = nil

        guard let scheme = components.scheme?.lowercased() else { throw .notAURL }
        guard scheme == "https" || scheme == "http" else { throw .unsupportedScheme(scheme) }
        components.scheme = scheme

        guard let host = components.host, !host.isEmpty else { throw .missingHost }

        // 평문 HTTP는 이 Mac 안에서만 허용한다.
        //
        // 경고가 아니라 거부다. 원격에 평문으로 보내면 API 키와 사용자가
        // 적은 고민이 같은 패킷에 실려 중간에 다 읽힌다. 사용자가 켤 수
        // 있는 스위치로 두지 않는 이유는, 그 스위치를 켜는 사람이 무엇을
        // 감수하는지 알 방법이 없기 때문이다. 유파가 갈리는 문제는 설정으로
        // 드러내지만 이것은 유파가 갈리는 문제가 아니다.
        if scheme == "http", Destination.classify(host: host).leavesMachine {
            throw .plaintextOffMachine(host: host)
        }

        var path = components.percentEncodedPath
        while path.hasSuffix("/") { path.removeLast() }
        for suffix in ["/chat/completions", "/v1/chat/completions"] where path.hasSuffix(suffix) {
            path.removeLast(suffix.count)
            // `/v1/chat/completions`를 지웠다면 `/v1`을 되살려야 한다.
            if suffix.hasPrefix("/v1/") { path += "/v1" }
            break
        }
        // 뿌리를 슬래시로 끝낸다. 이 규약이 있으면 경로 이어붙이기가
        // 한 가지 모양으로 고정된다.
        components.percentEncodedPath = path + "/"

        guard let url = components.url else { throw .notAURL }
        return Endpoint(base: url)
    }

    /// 저장된 값에서 되살릴 때. 정규화를 통과한 값이라고 전제한다.
    public init(base: URL) {
        self.base = base
    }
}

extension Endpoint.Invalid {
    /// 사용자에게 보여줄 말. 무엇이 잘못됐는지와 무엇을 하면 되는지를 함께 적는다.
    public var message: String {
        switch self {
        case .empty:
            "주소를 입력해 주세요."
        case .notAURL:
            "주소로 읽을 수 없습니다. `https://호스트/경로` 형태인지 확인해 주세요."
        case .unsupportedScheme(let scheme):
            "`\(scheme)`는 쓸 수 없습니다. `https` 또는 (이 Mac 안이라면) `http`만 됩니다."
        case .plaintextOffMachine(let host):
            "`\(host)`는 이 Mac이 아니므로 평문 `http`로 보낼 수 없습니다. API 키와 적어 주신 글이 중간에 그대로 읽힙니다. `https`를 쓰거나 이 Mac에서 도는 서버를 지정해 주세요."
        case .missingHost:
            "호스트가 없습니다."
        }
    }
}
