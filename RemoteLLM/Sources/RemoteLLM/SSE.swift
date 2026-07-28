import Foundation

/// Server-Sent Events 조립기.
///
/// `URLSession.AsyncBytes`의 `.lines`를 쓰지 않는다. 두 가지 이유다.
///
/// 첫째, `.lines`는 텍스트 줄 나누기이고 SSE는 **빈 줄이 의미를 갖는**
/// 프레이밍이다. 줄만 받으면 어디까지가 한 이벤트인지 다시 세어야 한다.
///
/// 둘째, 바이트를 문자열로 먼저 바꾸는 층을 통과하면 청크 경계에서 잘린
/// 멀티바이트 문자를 어떻게 다루는지가 그 층의 사정이 된다. 이 앱의 출력은
/// 전부 한국어이므로 거의 모든 글자가 3바이트이고, 경계에 걸릴 확률이
/// 영어의 몇 배다. 실제로 깨지면 증상은 "글자 하나가 물음표로 나온다"이고,
/// 재현이 어렵고 조용하다.
///
/// 그래서 **바이트를 모아 두고 줄 끝에서만 문자열로 바꾼다.** 줄 끝
/// (`\n`, `\r`)은 ASCII이고 UTF-8 연속 바이트에는 나타날 수 없으므로,
/// 줄 경계는 항상 유효한 문자 경계다. 이것이 이 구조의 근거다.
///
/// 규격: WHATWG HTML §9.2 Server-sent events.
public struct SSEParser: Sendable {
    /// 조립 중인 바이트. 줄 하나가 완성될 때까지 여기 남는다.
    private var pending: [UInt8] = []
    /// 직전 청크가 `\r`로 끝났다. 다음 바이트가 `\n`이면 한 줄 끝이고,
    /// 아니면 `\r` 자체가 줄 끝이었다. 청크 경계에 걸린 CRLF를 두 줄로
    /// 세지 않으려면 이 한 비트가 필요하다.
    private var awaitingLineFeed = false
    /// 지금 이벤트에 모인 `data:` 줄들.
    private var data: [String] = []
    /// 지금 이벤트의 `event:` 이름. 쓰는 제공자가 있다.
    private var eventName: String?

    public init() {}

    public struct Event: Equatable, Sendable {
        /// `data:` 줄들을 개행으로 이어붙인 것. 규격이 정한 방식이다.
        public let data: String
        public let name: String?
    }

    /// 바이트를 넣고 완성된 이벤트를 받는다. 남는 것은 안에 보관된다.
    public mutating func feed(_ bytes: some Sequence<UInt8>) -> [Event] {
        var events: [Event] = []
        for byte in bytes {
            if awaitingLineFeed {
                awaitingLineFeed = false
                // CRLF의 LF는 앞의 CR이 이미 끝낸 줄에 속한다. 버린다.
                if byte == 0x0A { continue }
            }
            switch byte {
            case 0x0A: // LF
                if let event = endLine() { events.append(event) }
            case 0x0D: // CR
                awaitingLineFeed = true
                if let event = endLine() { events.append(event) }
            default:
                pending.append(byte)
            }
        }
        return events
    }

    /// 스트림이 끝났다. 줄 끝 없이 남은 것을 마지막으로 꺼낸다.
    ///
    /// 제공자가 마지막 이벤트 뒤에 빈 줄을 보내지 않고 연결을 닫는 경우가
    /// 있다. 규격대로라면 그 이벤트는 버려야 하지만, 버리면 사용자는
    /// 마지막 문장 몇 글자를 잃는다. 여기서는 살린다.
    public mutating func finish() -> [Event] {
        var events: [Event] = []
        if !pending.isEmpty, let event = endLine() { events.append(event) }
        if let event = dispatch() { events.append(event) }
        return events
    }

    // MARK: - 내부

    private mutating func endLine() -> Event? {
        defer { pending.removeAll(keepingCapacity: true) }
        // 빈 줄 — 이벤트 경계다. SSE에서 유일하게 의미를 갖는 공백이다.
        guard !pending.isEmpty else { return dispatch() }

        // 잘못된 바이트열은 버리지 않고 치환 문자로 남긴다. 한 줄을
        // 통째로 버리면 그 자리에 무엇이 있었는지 알 수 없게 된다.
        let line = String(decoding: pending, as: UTF8.self)

        // `:`로 시작하는 줄은 주석이다. 여러 제공자가 이것으로 하트비트를
        // 보낸다. 무시하되 연결이 살아 있다는 뜻이므로 오류가 아니다.
        guard !line.hasPrefix(":") else { return nil }

        let field: String
        var value: String
        if let colon = line.firstIndex(of: ":") {
            field = String(line[line.startIndex..<colon])
            value = String(line[line.index(after: colon)...])
            // 규격: 콜론 뒤 공백 **하나만** 버린다. 두 개를 버리면
            // 들여쓴 JSON을 보내는 제공자에서 내용이 깎인다.
            if value.hasPrefix(" ") { value.removeFirst() }
        } else {
            // 콜론이 없는 줄은 필드 이름만 있고 값이 빈 것으로 읽는다.
            field = line
            value = ""
        }

        switch field {
        case "data": data.append(value)
        case "event": eventName = value
        // `id`와 `retry`는 재연결용이다. 이 앱은 재연결하지 않는다 —
        // 끊긴 생성을 이어붙이면 앞뒤가 어긋난 글이 나오므로, 섹션을
        // 다시 만드는 것이 옳다. 그래서 읽지 않는다.
        default: break
        }
        return nil
    }

    private mutating func dispatch() -> Event? {
        defer {
            data.removeAll(keepingCapacity: true)
            eventName = nil
        }
        guard !data.isEmpty else { return nil }
        return Event(data: data.joined(separator: "\n"), name: eventName)
    }
}
