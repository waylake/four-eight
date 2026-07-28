import Testing
import Foundation
@testable import RemoteLLM

/// 실제 제공자가 보낸 바이트로 하는 검사.
///
/// ## 왜 필요한가
///
/// 이 파일 밖의 SSE 테스트는 전부 제가 만든 문자열을 제가 만든 파서에 넣는
/// 것이다. 그것은 파서가 제 상상과 일치하는지만 증명한다. 절기 계산이
/// 맞는지 확인하려고 절기 계산을 두 번 돌리는 것과 같은 종류의 검증이며,
/// 이 저장소는 그것을 검증으로 보지 않는다.
///
/// 그래서 외부에서 받은 바이트를 골든 데이터로 고정한다.
/// `Fixtures/*.sse`는 실제 엔드포인트가 보낸 응답을 그대로 저장한 것이다.
/// 편집하지 않았고, 예쁘게 고치지도 않았다.
///
/// ## 이 파일이 검증하지 못하는 것 — 지우지 말 것
///
/// **다섯 파일 모두 본문 텍스트가 0자이고 `finish_reason`이 `length`다.**
/// 녹화할 때 토큰 예산을 작게 준 탓에 모델이 그것을 전부 추론 토큰으로
/// 쓰고 본문을 한 글자도 내지 못한 것이다(`reasoning_tokens: 16`, `23`).
///
/// 그러므로 이 골든 데이터는 **프레이밍·잘림·사용량·추론 토큰 무시**를
/// 검증하고, **본문을 이어 붙이는 정상 경로는 검증하지 않는다.** 그쪽은
/// `SSETests`와 `ChatStreamTests`의 합성 입력이 담당한다.
///
/// 이 한계를 적어 두는 이유는, 골든 데이터가 있다는 사실만 보고 "실제
/// 응답으로 전부 검증했다"고 오해하기 쉽기 때문이다. 불편한 사실이 가장
/// 값진 정보다.
///
/// 뜻밖의 소득이 하나 있었다. **"200인데 본문이 비어 있다"가 가상의
/// 경우가 아니라는 것을 이 파일들이 증명한다.** 그래서 `RemoteWriter`가
/// 빈 응답과 잘림을 오류로 올리는 것은 방어적 코드가 아니라 실제로
/// 일어나는 일에 대한 대응이다.
@Suite("실제 응답 골든 데이터")
struct FixtureTests {
    /// 녹화된 응답과 그 안에 실제로 들어 있는 것.
    ///
    /// 기댓값을 구현에 맞춰 고치지 않는다. 이 값들은 파일을 읽어서 나온
    /// 것이고, 검사가 깨지면 구현이 틀린 것이다.
    struct Fixture {
        let name: String
        /// 하트비트 주석 줄 수. 0이면 그 제공자는 주석을 보내지 않았다.
        let commentLines: Int
        /// `[DONE]` **뒤에** 도착한 프레임 수.
        let framesAfterDone: Int
        let promptTokens: Int?
        let completionTokens: Int?
        /// 이 응답에 `finish_reason: "length"`가 있었는가.
        let truncated: Bool
    }

    static let fixtures: [Fixture] = [
        // Ollama — 이 Mac에서 도는 로컬 엔드포인트. 주석을 보내지 않고
        // `[DONE]`으로 깔끔하게 끝낸다.
        .init(name: "ollama-stream", commentLines: 0, framesAfterDone: 0,
              promptTokens: nil, completionTokens: nil, truncated: true),
        .init(name: "ollama-stream-usage", commentLines: 0, framesAfterDone: 0,
              promptTokens: 19, completionTokens: 8, truncated: true),
        .init(name: "ollama-tools-stream", commentLines: 0, framesAfterDone: 0,
              promptTokens: nil, completionTokens: nil, truncated: true),
        // 게이트웨이 경유. 같은 게이트웨이인데 **경로에 따라 하트비트가
        // 있고 없다.** 한쪽만 보고 파서를 만들면 다른 쪽에서 깨진다.
        .init(name: "opencode-zen-stream", commentLines: 5, framesAfterDone: 1,
              promptTokens: 253, completionTokens: 24, truncated: true),
        .init(name: "opencode-zen-deepseek-stream", commentLines: 0, framesAfterDone: 1,
              promptTokens: 88, completionTokens: 16, truncated: true),
    ]

    private func bytes(_ name: String) throws -> [UInt8] {
        let url = try #require(
            Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "sse")
        )
        return Array(try Data(contentsOf: url))
    }

    /// 바이트를 넣고 나온 조각을 모은다.
    private func run(_ raw: [UInt8], chunkSize: Int) -> [ChatStreamDecoder.Piece] {
        var parser = SSEParser()
        let decoder = ChatStreamDecoder()
        var pieces: [ChatStreamDecoder.Piece] = []
        var index = 0
        while index < raw.count {
            let end = min(index + chunkSize, raw.count)
            for event in parser.feed(raw[index..<end]) {
                pieces += decoder.decode(event)
            }
            index = end
        }
        for event in parser.finish() {
            pieces += decoder.decode(event)
        }
        return pieces
    }

    /// 쪼개는 크기를 바꿔도 결과가 같아야 한다.
    ///
    /// 실제 네트워크는 우리가 고른 자리에서 끊어 주지 않는다. 1바이트씩
    /// 넣는 경로를 포함하는 것이 이 검사의 핵심이다.
    @Test("쪼개는 크기가 결과를 바꾸지 않는다", arguments: fixtures)
    func framingIsChunkIndependent(_ fixture: Fixture) throws {
        let raw = try bytes(fixture.name)
        let reference = run(raw, chunkSize: raw.count)
        for chunkSize in [1, 3, 17, 256, 4096] {
            #expect(run(raw, chunkSize: chunkSize) == reference,
                    "\(fixture.name)을 \(chunkSize)바이트씩 넣으면 결과가 달라집니다")
        }
    }

    /// 건강한 응답에서 오류 조각이 나오면 안 된다.
    ///
    /// 이것이 가장 중요한 검사다. 파서가 모르는 것을 오류로 올리도록
    /// 만들어 두었으므로(조용히 버리지 않기 위해), 정상 응답에 오류가
    /// 섞이면 사용자는 되는 조합에서 실패를 본다.
    ///
    /// `[DONE]` 뒤에 도착하는 프레임과 하트비트 주석이 여기서 걸린다.
    @Test("정상 응답에 오류가 섞이지 않는다", arguments: fixtures)
    func noSpuriousFailures(_ fixture: Fixture) throws {
        let pieces = run(try bytes(fixture.name), chunkSize: 1)
        let failures = pieces.compactMap { piece -> ProviderError? in
            if case .failure(let error) = piece { return error }
            return nil
        }
        #expect(failures.isEmpty, "\(fixture.name)에서 오류 조각이 나왔습니다: \(failures)")
    }

    /// 잘림은 조용히 통과하지 않는다.
    ///
    /// 다섯 파일 모두 `finish_reason: "length"`다. 즉 "200인데 답이 잘렸다"는
    /// 가상의 경우가 아니다.
    @Test("잘림을 잡는다", arguments: fixtures)
    func truncationDetected(_ fixture: Fixture) throws {
        let pieces = run(try bytes(fixture.name), chunkSize: 7)
        #expect(pieces.contains(.truncated) == fixture.truncated,
                "\(fixture.name)의 잘림 판정이 다릅니다")
    }

    /// 사용량은 보고한 것만, 보고한 값 그대로.
    @Test("사용량을 읽는다", arguments: fixtures)
    func usage(_ fixture: Fixture) throws {
        let pieces = run(try bytes(fixture.name), chunkSize: 64)
        let reported = pieces.compactMap { piece -> (Int?, Int?)? in
            if case .usage(let prompt, let completion) = piece { return (prompt, completion) }
            return nil
        }
        if let expectedPrompt = fixture.promptTokens {
            let found = try #require(reported.first)
            #expect(found.0 == expectedPrompt)
            #expect(found.1 == fixture.completionTokens)
        } else {
            // 보고하지 않는 응답에서 0을 만들어내지 않는다.
            #expect(reported.isEmpty, "\(fixture.name)에서 없는 사용량을 만들어냈습니다")
        }
    }

    /// 추론 토큰을 쓴 응답에서도 본문이 새어 나오지 않는다.
    ///
    /// 이 파일들은 본문이 0자이고 완성 토큰은 8~24개다. 그 토큰은 전부
    /// 추론에 쓰였다. 파서가 추론 내용을 본문으로 읽으면 여기서 텍스트가
    /// 나오고, 사용자는 사주 해설 자리에서 모델의 혼잣말을 읽는다.
    @Test("추론만 한 응답에서 본문이 나오지 않는다", arguments: fixtures)
    func reasoningNeverBecomesText(_ fixture: Fixture) throws {
        let pieces = run(try bytes(fixture.name), chunkSize: 1)
        let text = pieces.compactMap { piece -> String? in
            if case .text(let delta) = piece { return delta }
            return nil
        }.joined()
        #expect(text.isEmpty, "\(fixture.name)에서 본문이 나왔습니다: \(text)")
    }

    /// 하트비트 주석은 이벤트가 아니다.
    ///
    /// 같은 게이트웨이인데 경로에 따라 주석이 있고 없다. 한쪽만 보고
    /// 파서를 만들면 다른 쪽에서 깨진다. 그리고 한 파일은 **첫 줄부터**
    /// 주석이다 — 첫 이벤트를 기준으로 무언가를 판단하는 코드가 있으면
    /// 거기서 걸린다.
    @Test("하트비트 주석이 섞인 응답을 읽는다")
    func heartbeatComments() throws {
        let raw = try bytes("opencode-zen-stream")
        let text = String(decoding: raw, as: UTF8.self)
        #expect(text.hasPrefix(": OPENROUTER PROCESSING"), "첫 줄이 주석인 골든 데이터가 아닙니다")
        #expect(text.components(separatedBy: "\n: ").count - 1 >= 1)

        // 주석이 5개 있어도 오류나 빈 텍스트 조각이 생기지 않는다.
        let pieces = run(raw, chunkSize: 1)
        #expect(!pieces.isEmpty)
        #expect(!pieces.contains { if case .failure = $0 { return true } else { return false } })
    }

    /// `[DONE]` 뒤에 프레임이 더 오는 제공자가 있다.
    ///
    /// 규격대로면 `[DONE]`이 끝이지만, 게이트웨이는 그 뒤에 비용 정보를
    /// 한 프레임 더 보낸다. `[DONE]`을 보고 파싱을 멈추면 그 프레임을
    /// 못 읽고, 멈추지 않으면서 모르는 것을 오류로 올리면 정상 응답이
    /// 실패가 된다. 양쪽 다 아니어야 한다.
    @Test("종료 표지 뒤의 프레임을 조용히 통과시킨다",
          arguments: ["opencode-zen-stream", "opencode-zen-deepseek-stream"])
    func framesAfterDone(_ name: String) throws {
        let raw = try bytes(name)
        let text = String(decoding: raw, as: UTF8.self)
        let doneIndex = try #require(text.range(of: "data: [DONE]"))
        let tail = text[doneIndex.upperBound...]
        #expect(tail.contains("data: "), "종료 표지 뒤에 프레임이 있는 골든 데이터가 아닙니다")

        let pieces = run(raw, chunkSize: 1)
        #expect(!pieces.contains { if case .failure = $0 { return true } else { return false } },
                "\(name): 종료 표지 뒤의 프레임이 오류로 읽혔습니다")
    }

    /// 녹화된 파일은 전부 LF만 쓴다.
    ///
    /// CRLF 경로가 검증되지 않았다는 뜻이다. 그쪽은 `SSETests`의 합성
    /// 입력이 담당한다. 이 사실을 적어 두지 않으면 "실제 응답으로 CRLF까지
    /// 검증했다"고 오해하게 된다.
    @Test("녹화 파일에 CR이 없다는 사실을 고정한다", arguments: fixtures)
    func fixturesAreLineFeedOnly(_ fixture: Fixture) throws {
        let raw = try bytes(fixture.name)
        #expect(!raw.contains(0x0D), "\(fixture.name)에 CR이 생겼습니다. 골든 데이터를 편집하지 마십시오.")
    }
}

extension FixtureTests.Fixture: CustomTestStringConvertible {
    var testDescription: String { name }
}
