import Testing
import Foundation
@testable import RemoteLLM

@Suite("엔드포인트 정규화")
struct EndpointTests {
    @Test("같은 뜻으로 붙여넣는 것들이 같은 주소가 된다", arguments: [
        "https://api.example.com/v1",
        "https://api.example.com/v1/",
        "https://api.example.com/v1/chat/completions",
        // 붙여넣기에는 거의 항상 공백이나 개행이 딸려 온다.
        "  https://api.example.com/v1  \n",
        // 스킴 없는 입력. 보정하지 않으면 URL이 상대 경로로 읽어 호스트가 사라진다.
        "api.example.com/v1",
        // 질의 문자열이 붙어 있으면 경로 이어붙이기가 조용히 망가진다.
        "https://api.example.com/v1?key=ignored",
    ])
    func equivalentInputs(_ raw: String) throws {
        let endpoint = try Endpoint.normalize(raw)
        #expect(endpoint.base.absoluteString == "https://api.example.com/v1/")
        #expect(endpoint.chatCompletions.absoluteString
            == "https://api.example.com/v1/chat/completions")
    }

    @Test("빈 경로에 /v1을 몰래 붙이지 않는다")
    func doesNotInventPath() throws {
        let endpoint = try Endpoint.normalize("https://gateway.example.com")
        // 짐작하면 맞을 때는 아무 일도 없지만 틀리면 404가 나면서 사용자는
        // 자기가 넣은 주소가 쓰였다고 믿는다. 대신 최종 주소를 보여준다.
        #expect(endpoint.chatCompletions.absoluteString
            == "https://gateway.example.com/chat/completions")
    }

    @Test("게이트웨이가 임의 경로에 뿌리를 둘 수 있다")
    func nonStandardRoot() throws {
        let endpoint = try Endpoint.normalize("https://gw.example.com/openai/deployments/x")
        #expect(endpoint.chatCompletions.absoluteString
            == "https://gw.example.com/openai/deployments/x/chat/completions")
    }

    @Test("이 Mac 안이면 평문 http를 받는다", arguments: [
        "http://localhost:11434/v1",
        "http://127.0.0.1:1234/v1",
    ])
    func plaintextOnMachine(_ raw: String) throws {
        let endpoint = try Endpoint.normalize(raw)
        #expect(endpoint.destination.leavesMachine == false)
    }

    @Test("이 Mac 밖으로 평문 http는 거부한다")
    func plaintextOffMachineRejected() {
        // 경고가 아니라 거부다. API 키와 사용자가 적은 고민이 같은 패킷에
        // 실려 중간에 다 읽힌다. 이것은 유파가 갈리는 문제가 아니다.
        #expect(throws: Endpoint.Invalid.plaintextOffMachine(host: "api.example.com")) {
            try Endpoint.normalize("http://api.example.com/v1")
        }
    }

    @Test("스킴 없는 입력은 https로 읽으므로 거부되지 않는다")
    func schemelessBecomesHTTPS() throws {
        let endpoint = try Endpoint.normalize("api.example.com/v1")
        #expect(endpoint.base.scheme == "https")
    }

    @Test("쓸 수 없는 스킴", arguments: ["ftp", "file", "ws"])
    func badScheme(_ scheme: String) {
        #expect(throws: Endpoint.Invalid.unsupportedScheme(scheme)) {
            try Endpoint.normalize("\(scheme)://api.example.com/v1")
        }
    }

    @Test("빈 입력")
    func empty() {
        #expect(throws: Endpoint.Invalid.empty) { try Endpoint.normalize("   ") }
    }

    @Test("모든 오류에 사용자가 읽을 말이 있다", arguments: [
        Endpoint.Invalid.empty,
        .notAURL,
        .unsupportedScheme("ftp"),
        .plaintextOffMachine(host: "api.example.com"),
        .missingHost,
    ])
    func everyErrorSpeaks(_ error: Endpoint.Invalid) {
        // 조용히 실패하는 고리를 만들지 않는다. 오류마다 무엇이 잘못됐고
        // 무엇을 하면 되는지가 있어야 한다.
        #expect(!error.message.isEmpty)
    }
}
