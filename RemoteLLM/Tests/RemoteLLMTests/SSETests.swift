import Testing
import Foundation
@testable import RemoteLLM

@Suite("SSE 조립")
struct SSETests {
    /// 청크 경계를 임의로 쪼개 넣어도 결과가 같아야 한다.
    ///
    /// 실제 네트워크는 우리가 고른 자리에서 끊어 주지 않는다. 테스트가
    /// 한 번에 다 넣기만 하면 이 파서의 존재 이유 자체를 검사하지 않는 것이다.
    private func events(_ text: String, chunkSize: Int) -> [SSEParser.Event] {
        var parser = SSEParser()
        var out: [SSEParser.Event] = []
        let bytes = Array(text.utf8)
        var index = 0
        while index < bytes.count {
            let end = min(index + chunkSize, bytes.count)
            out += parser.feed(bytes[index..<end])
            index = end
        }
        out += parser.finish()
        return out
    }

    @Test("기본 프레이밍")
    func basic() {
        let wire = "data: {\"a\":1}\n\ndata: {\"a\":2}\n\n"
        #expect(events(wire, chunkSize: 4096).map(\.data) == ["{\"a\":1}", "{\"a\":2}"])
    }

    /// 이 프로젝트에서 가장 중요한 SSE 테스트다.
    ///
    /// 이 앱의 출력은 전부 한국어다. 한글 한 글자는 UTF-8에서 3바이트이고,
    /// 청크 경계는 그 3바이트 사이에 떨어질 수 있다. 바이트를 문자열로
    /// 먼저 바꾸는 파서는 여기서 글자를 잃거나 물음표로 바꾼다. 증상은
    /// "가끔 글자 하나가 깨진다"이고, 재현이 어렵고 조용하다.
    ///
    /// 그래서 1바이트씩 넣는 경로를 포함해 모든 쪼개기 크기를 검사한다.
    /// 1바이트씩 넣는 것은 멀티바이트 문자를 **항상** 쪼갠다.
    @Test("멀티바이트 문자가 청크 경계에 걸려도 온전하다",
          arguments: [1, 2, 3, 5, 7, 13, 64, 4096])
    func multibyteAcrossChunks(_ chunkSize: Int) {
        let sentence = "재성이 흔들리는 국면입니다. 壬水가 월지에 앉아 있습니다."
        let wire = "data: {\"t\":\"\(sentence)\"}\n\n"
        let result = events(wire, chunkSize: chunkSize)
        #expect(result.count == 1)
        #expect(result.first?.data == "{\"t\":\"\(sentence)\"}")
        // 치환 문자가 하나라도 생기면 실패다.
        #expect(result.first?.data.contains("\u{FFFD}") == false)
    }

    /// CRLF의 LF를 별도의 줄 끝으로 세면 **빈 줄이 하나 더 생기고**,
    /// 빈 줄은 SSE에서 이벤트 경계다. 즉 이벤트가 조각난다.
    ///
    /// 이 증상은 `data:` 줄이 하나뿐인 이벤트에서는 보이지 않는다.
    /// 조각나도 조각이 하나이므로 결과가 같기 때문이다. 처음 쓴 테스트가
    /// 그랬고, 그래서 `awaitingLineFeed`를 지워도 통과했다. 두 줄이어야
    /// 판별된다 — 검사가 실제로 무엇을 잡는지 확인하지 않으면 이런 것이 남는다.
    @Test("CRLF를 두 줄 끝으로 세면 이벤트가 조각난다", arguments: [1, 2, 3, 8, 4096])
    func crlfDoesNotSplitEvents(_ chunkSize: Int) {
        let wire = "data: a\r\ndata: b\r\n\r\n"
        #expect(events(wire, chunkSize: chunkSize).map(\.data) == ["a\nb"])
    }

    /// CR과 LF가 서로 다른 `feed` 호출에 들어오는 경우. 청크 경계는
    /// 우리가 고르는 것이 아니므로 실제로 일어난다.
    @Test("CRLF가 청크 경계에 정확히 걸린다")
    func crlfSplitExactlyAtChunkBoundary() {
        var parser = SSEParser()
        var out = parser.feed(Array("data: a\r".utf8))
        out += parser.feed(Array("\ndata: b\r\n\r\n".utf8))
        out += parser.finish()
        #expect(out.map(\.data) == ["a\nb"])
    }

    @Test("줄 끝이 셋 다 통한다", arguments: ["\n", "\r\n", "\r"])
    func allLineTerminators(_ eol: String) {
        // 규격은 LF, CRLF, CR 셋을 모두 줄 끝으로 인정한다.
        let wire = "data: one\(eol)\(eol)data: two\(eol)\(eol)"
        #expect(events(wire, chunkSize: 1).map(\.data) == ["one", "two"])
    }

    @Test("주석 줄은 이벤트가 아니다")
    func commentsIgnored() {
        // 여러 제공자가 `: ping`이나 `:` 하나로 하트비트를 보낸다.
        // 이것을 데이터로 읽으면 JSON 파싱이 실패하고, 오류로 다루면
        // 연결이 살아 있는데 실패했다고 말하게 된다.
        let wire = ": ping\n\ndata: real\n\n:\n\n"
        #expect(events(wire, chunkSize: 3).map(\.data) == ["real"])
    }

    @Test("data 줄이 여러 개면 개행으로 이어붙인다")
    func multipleDataLines() {
        let wire = "data: line1\ndata: line2\n\n"
        #expect(events(wire, chunkSize: 5).map(\.data) == ["line1\nline2"])
    }

    @Test("콜론 뒤 공백은 하나만 버린다")
    func stripsExactlyOneSpace() {
        // 두 개를 버리면 들여쓴 JSON을 보내는 제공자에서 내용이 깎인다.
        let wire = "data:  {\"a\":1}\n\n"
        #expect(events(wire, chunkSize: 2).map(\.data) == [" {\"a\":1}"])
    }

    @Test("event 이름을 읽는다")
    func eventName() {
        let wire = "event: message_stop\ndata: {}\n\n"
        let result = events(wire, chunkSize: 4)
        #expect(result.first?.name == "message_stop")
    }

    @Test("id와 retry는 이벤트를 만들지 않는다")
    func ignoresReconnectFields() {
        // 이 앱은 재연결하지 않는다. 끊긴 생성을 이어붙이면 앞뒤가 어긋난
        // 글이 나오므로 섹션을 다시 만드는 것이 옳다.
        let wire = "id: 42\nretry: 3000\ndata: x\n\n"
        #expect(events(wire, chunkSize: 1).map(\.data) == ["x"])
    }

    @Test("빈 줄 없이 끝난 마지막 이벤트를 살린다")
    func recoversUnterminatedTail() {
        // 규격대로면 버려야 하지만, 버리면 사용자는 마지막 문장 몇 글자를
        // 잃는다. 이미 화면에 나오던 문장이 끝에서 잘리는 것은 눈에 띈다.
        let wire = "data: first\n\ndata: last"
        #expect(events(wire, chunkSize: 3).map(\.data) == ["first", "last"])
    }

    @Test("빈 줄만 와도 이벤트를 만들지 않는다")
    func blankLinesAlone() {
        #expect(events("\n\n\n\n", chunkSize: 1).isEmpty)
    }
}
