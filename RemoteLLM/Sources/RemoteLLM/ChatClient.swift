import Foundation

/// OpenAI 호환 엔드포인트에 요청을 보내고 조각을 돌려준다.
///
/// URLSession 글루만 있다. 판정은 전부 순수 함수(`ResponseGate`,
/// `SSEParser`, `ChatStreamDecoder`)에 있어서 네트워크 없이 검사한다.
/// 이 층에 판정을 섞으면 그 판정은 영원히 검사받지 않는다.
public struct ChatClient: Sendable {
    public let endpoint: Endpoint
    /// 키는 값으로 들고 다니지 않는다. 보낼 때마다 받아 온다 — 로그나
    /// 오류 객체에 실려 나갈 표면을 줄이려는 것이다.
    private let apiKey: @Sendable () -> String?
    private let session: URLSession

    public init(
        endpoint: Endpoint,
        apiKey: @escaping @Sendable () -> String?,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.session = session
    }

    /// 응답 헤더만 보고 내릴 수 있는 판정. 순수 함수다.
    public enum ResponseGate {
        /// 스트림을 읽어도 되는가. 아니면 왜 안 되는가.
        ///
        /// **본문을 읽기 전에 결정한다.** 401 본문은 SSE가 아니므로 SSE
        /// 파서에 넣으면 아무 이벤트도 나오지 않고, 그러면 "빈 답"으로
        /// 보인다. 조용한 실패다.
        public static func check(
            status: Int,
            contentType: String?
        ) -> Outcome {
            guard (200...299).contains(status) else { return .readErrorBody }
            guard let contentType = contentType?.lowercased() else {
                // Content-Type을 안 보내는 구현이 있다. 규격 위반이지만
                // 스트림 자체는 정상인 경우가 많으므로 통과시킨다.
                return .stream
            }
            if contentType.contains("text/event-stream") { return .stream }
            // 200 + JSON. 스트리밍을 무시하고 한 번에 돌려준 것일 수 있고,
            // 본문에 오류가 실린 것일 수도 있다. 둘 다 본문을 봐야 안다.
            if contentType.contains("json") { return .readWholeBody }
            // 200 + text/html. 거의 항상 주소가 API가 아닌 곳을 가리킨다.
            return .notStream(contentType: contentType)
        }

        public enum Outcome: Equatable, Sendable {
            case stream
            case readWholeBody
            case readErrorBody
            case notStream(contentType: String)
        }
    }

    /// 조각 스트림. 취소하면 연결이 끊긴다.
    public func stream(_ request: ChatRequest) -> AsyncThrowingStream<ChatStreamDecoder.Piece, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(request, into: continuation)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch let error as ProviderError {
                    continuation.finish(throwing: error)
                } catch let error as URLError where error.code == .cancelled {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ProviderError.transport(error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(
        _ chat: ChatRequest,
        into continuation: AsyncThrowingStream<ChatStreamDecoder.Piece, Error>.Continuation
    ) async throws {
        var request = URLRequest(url: endpoint.chatCompletions)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let key = apiKey(), !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try chat.body()
        // 첫 토큰까지 기다리는 시간. 스트리밍이므로 전체 시간에는 제한을
        // 두지 않는다 — 긴 답이 길다는 이유로 끊기면 안 된다.
        request.timeoutInterval = 60

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.transport("HTTP 응답이 아닙니다.")
        }
        let contentType = http.value(forHTTPHeaderField: "Content-Type")

        switch ResponseGate.check(status: http.statusCode, contentType: contentType) {
        case .notStream(let type):
            let body = try await collect(bytes, limit: 2_000)
            throw ProviderError.notEventStream(contentType: type, body: body)

        case .readErrorBody:
            let body = try await collect(bytes, limit: 4_000)
            let root = body.data(using: .utf8).flatMap {
                try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
            }
            throw ProviderError.from(
                status: http.statusCode,
                detail: root.flatMap { ProviderError.detail(from: $0) } ?? nonEmpty(body),
                retryAfter: ProviderError.retryAfter(from: http.allHeaderFields)
            )

        case .readWholeBody:
            // 200 + JSON. 스트리밍 요청을 무시하고 완성된 응답을 돌려준
            // 제공자이거나, 본문에 오류가 실린 경우다. 디코더가 둘 다 안다.
            let body = try await collect(bytes, limit: 200_000)
            let decoder = ChatStreamDecoder()
            for piece in decoder.decode(.init(data: body, name: nil)) {
                if case .failure(let error) = piece { throw error }
                continuation.yield(piece)
            }

        case .stream:
            var parser = SSEParser()
            let decoder = ChatStreamDecoder()
            for try await byte in bytes {
                try Task.checkCancellation()
                for event in parser.feed(CollectionOfOne(byte)) {
                    for piece in decoder.decode(event) {
                        if case .failure(let error) = piece { throw error }
                        continuation.yield(piece)
                    }
                }
            }
            // 빈 줄 없이 끝난 마지막 이벤트를 살린다.
            for event in parser.finish() {
                for piece in decoder.decode(event) {
                    if case .failure(let error) = piece { throw error }
                    continuation.yield(piece)
                }
            }
        }
    }

    /// 오류 본문을 문자열로 모은다. 상한을 두는 이유는 HTML 오류 페이지가
    /// 수백 KB일 수 있고, 그것을 전부 화면에 올릴 이유가 없기 때문이다.
    private func collect(_ bytes: URLSession.AsyncBytes, limit: Int) async throws -> String {
        var buffer: [UInt8] = []
        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= limit { break }
        }
        return String(decoding: buffer, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nonEmpty(_ text: String) -> String? {
        text.isEmpty ? nil : String(text.prefix(400))
    }
}
