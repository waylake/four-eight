import Foundation

/// 보관용 표현.
///
/// 합성된 `Codable`을 쓰지 않고 직접 쓴다. 이 값은 해석 보관 파일에
/// 들어가고, 그 파일은 사용자가 열어 볼 수 있는 JSON이다. 합성 표현은
/// 연관값을 중첩 객체로 감싸므로 읽기 어렵고, 케이스 이름을 바꾸면 이미
/// 저장된 파일을 읽지 못한다.
///
/// 이 형태는 평평하고 스스로를 설명한다.
///
/// ```json
/// { "kind": "offMachine", "host": "api.openai.com" }
/// { "kind": "inProcess" }
/// ```
extension Destination: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, host
    }

    /// 저장되는 문자열. **바꾸면 이미 보관된 파일을 읽지 못한다.**
    private enum Kind: String, Codable {
        case inProcess, onMachine, offMachine
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .inProcess:
            self = .inProcess
        case .onMachine:
            self = .onMachine(host: try container.decode(String.self, forKey: .host))
        case .offMachine:
            self = .offMachine(host: try container.decode(String.self, forKey: .host))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .inProcess:
            try container.encode(Kind.inProcess, forKey: .kind)
        case .onMachine(let host):
            try container.encode(Kind.onMachine, forKey: .kind)
            try container.encode(host, forKey: .host)
        case .offMachine(let host):
            try container.encode(Kind.offMachine, forKey: .kind)
            try container.encode(host, forKey: .host)
        }
    }
}
