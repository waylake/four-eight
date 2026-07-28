import Testing
import Foundation
@testable import RemoteLLM

/// 목적지 판정.
///
/// 이 판정이 틀리면 사용자는 자기 글이 나간 것을 모른다. 그래서 양쪽을
/// 함께 고정한다 — 루프백을 원격이라 부르는 것(과경고)과 원격을 루프백이라
/// 부르는 것(무경고)은 대가가 다르고, 이 목록은 그 비대칭을 알고 고른 것이다.
@Suite("목적지 판정")
struct DestinationTests {
    @Test("루프백으로 확실한 것만 이 Mac 안이다", arguments: [
        "localhost",
        "LOCALHOST",
        "127.0.0.1",
        // 127.0.0.0/8 전체가 루프백이다. 실제로 127.0.0.2에 서버를 띄우는
        // 사람이 있고, 그 사람에게 "이 Mac을 벗어납니다"라고 말하면 거짓이다.
        "127.0.0.2",
        "127.1.2.3",
        "::1",
        "[::1]",
        // RFC 6761 §6.3 — localhost의 하위 이름도 루프백으로 해석된다.
        "app.localhost",
    ])
    func loopback(_ host: String) {
        #expect(Destination.classify(host: host).leavesMachine == false)
    }

    @Test("애매하거나 다른 기기면 나간다고 말한다", arguments: [
        "api.openai.com",
        "openrouter.ai",
        // LAN의 다른 컴퓨터. 집 안에 있어도 이 Mac은 아니다. 여기서
        // "안 나간다"고 말하면 프라이버시 주장이 거짓이 된다.
        "192.168.1.42",
        "10.0.0.5",
        "mac-studio.local",
        // 접미사 검사가 점을 포함하지 않으면 이것이 통과한다.
        "notlocalhost",
        "localhost.attacker.example",
        // inet_aton은 이것을 127.0.0.1로 받아 준다. 접속은 되지만 이
        // 함수는 "확실하다"고 말하지 않는다. 과하게 경고하는 쪽으로 틀린다.
        "127.1",
        // 8진수·16진수 표기도 인정하지 않는다. 표기법마다 판정이 갈리면
        // 판정 자체를 신뢰할 수 없다.
        "0177.0.0.1",
        "0x7f.0.0.1",
        "2130706433",
    ])
    func offMachine(_ host: String) {
        #expect(Destination.classify(host: host).leavesMachine == true)
    }

    @Test("프로세스 안은 호스트가 없다")
    func inProcessHasNoHost() {
        #expect(Destination.inProcess.host == nil)
        #expect(Destination.inProcess.leavesMachine == false)
    }
}

@Suite("목적지 보관")
struct DestinationCodableTests {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Test("왕복해도 같다", arguments: [
        Destination.inProcess,
        .onMachine(host: "localhost"),
        .offMachine(host: "api.openai.com"),
    ])
    func roundTrip(_ destination: Destination) throws {
        let data = try encoder.encode(destination)
        #expect(try decoder.decode(Destination.self, from: data) == destination)
    }

    /// 이 문자열들은 보관 파일에 들어간다. 바꾸면 이미 저장된 해석의
    /// 출처를 읽지 못하고, 사용자는 "누가 이 문장을 썼는지" 표기를 잃는다.
    /// 케이스 이름을 리팩터링하다 무심코 바꾸기 쉬운 자리다.
    @Test("저장 문자열이 고정되어 있다")
    func storedShapeIsStable() throws {
        let data = try encoder.encode(Destination.offMachine(host: "api.openai.com"))
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: String]
        )
        #expect(root == ["kind": "offMachine", "host": "api.openai.com"])

        let inProcess = try encoder.encode(Destination.inProcess)
        #expect(try JSONSerialization.jsonObject(with: inProcess) as? [String: String]
            == ["kind": "inProcess"])
    }
}
