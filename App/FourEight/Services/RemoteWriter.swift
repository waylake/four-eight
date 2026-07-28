import Foundation
import RemoteLLM
import SajuKit

/// OpenAI 호환 엔드포인트로 문장을 주문하는 쪽.
///
/// 온디바이스 경로와 다른 점은 **전송뿐이다.** 어떤 근거를 쓸지, 어떤
/// 톤으로 쓸지, 무엇을 하지 말라고 지시할지는 `InterpretationBrief`와
/// `CounselBrief`가 이미 정해 두었다. 이 파일에 프롬프트 문장이 하나도
/// 없는 것이 의도다.
///
/// 온디바이스와 달리 섹션마다 요청을 새로 만든다. 세션을 이어 붙이지
/// 않으므로 잘린 턴이 KV 캐시에 남는 문제(MLX PR #414)가 애초에 없고,
/// 대신 매 요청에 지시가 다시 실린다 — 원격에서는 그것이 요금이지만
/// 지시를 잊는 것보다 낫다.
struct RemoteWriter: Sendable {
    let client: ChatClient
    let model: String
    /// 사용자가 정한 출력 상한. nil이면 요청에 실리지 않는다.
    var maxTokens: Int?
    var compatibility: ChatRequest.Compatibility
    /// 제공자가 사용량을 보고했을 때. 보고하지 않는 제공자도 있다.
    let onUsage: @Sendable (Int?, Int?) -> Void

    init(
        client: ChatClient,
        model: String,
        maxTokens: Int? = nil,
        compatibility: ChatRequest.Compatibility = .init(),
        onUsage: @escaping @Sendable (Int?, Int?) -> Void = { _, _ in }
    ) {
        self.client = client
        self.model = model
        self.maxTokens = maxTokens
        self.compatibility = compatibility
        self.onUsage = onUsage
    }

    /// 한 번의 요청. 본문 조각만 흘려보내고, 잘림과 오류는 던진다.
    ///
    /// `truncated`를 정상 종료로 다루지 않는 것이 이 함수의 핵심이다.
    /// 토큰 한도에서 끊긴 해설은 완성된 해설처럼 읽힌다 — 이 앱은 근거를
    /// 통합한 서술을 만들므로 마지막 문단이 없어도 문장이 이어진다.
    /// 조용히 통과시키면 사용자는 덜 받은 것을 모른다.
    func run(
        system: String,
        user: String,
        onText: @escaping @Sendable (String) -> Void
    ) async throws {
        let request = ChatRequest(
            model: model, system: system, user: user,
            maxTokens: maxTokens, compatibility: compatibility
        )
        var sawText = false
        var thoughtChars = 0
        for try await piece in client.stream(request) {
            try Task.checkCancellation()
            switch piece {
            case .text(let delta):
                sawText = true
                onText(delta)
            case .reasoning(let chars):
                // 글자는 버리고 분량만 센다. 이 수치가 아래 진단의 근거다.
                thoughtChars += chars
            case .usage(let prompt, let completion):
                onUsage(prompt, completion)
            case .truncated:
                // **잘림의 원인을 구분한다.**
                //
                // 본문이 한 글자도 없고 생각만 길었다면 추론이 예산을 다 쓴
                // 것이다. "답이 잘렸습니다"라고만 말하면 사용자는 무엇을
                // 해야 할지 모른다 — 실제로 이 앱이 그 상태였다.
                throw sawText
                    ? RemoteWriterError.truncated
                    : RemoteWriterError.reasoningExhaustedBudget(thoughtChars: thoughtChars)
            case .finished:
                break
            case .failure(let error):
                throw error
            }
        }
        // 취소를 "빈 응답"으로 잘못 읽지 않는다.
        //
        // URLSession은 취소를 `CancellationError`가 아니라
        // `URLError(.cancelled)`(-999)로 던지고, `ChatClient`는 그것을
        // 정상 종료로 바꿔 스트림을 닫는다. 그래서 사용자가 중단 버튼을
        // 누르면 이 반복문은 **오류 없이** 끝난다. 여기서 확인하지 않으면
        // 사용자의 중단이 "제공자가 빈 답을 보냈습니다"로 표시된다.
        try Task.checkCancellation()
        // 200에 빈 스트림. 조용히 성공으로 두면 빈 말풍선이 남는다.
        guard sawText else {
            throw thoughtChars > 0
                ? RemoteWriterError.reasoningExhaustedBudget(thoughtChars: thoughtChars)
                : RemoteWriterError.emptyResponse
        }
    }
}

/// 격리 밖에서 오는 조각을 모으는 상자.
///
/// `onText`는 `@Sendable`이므로 지역 `var`를 그대로 더할 수 없다. 컴파일러가
/// 막는 것이 옳다 — 스트림 조각은 실제로 다른 실행 문맥에서 도착한다.
/// 확인 요청처럼 결과를 통째로 필요할 때만 쓴다. 화면에 흐르는 생성은
/// 이것을 거치지 않고 조각마다 바로 상태에 들어간다.
final class CollectedText: @unchecked Sendable {
    private let lock = NSLock()
    private var value = ""

    func append(_ delta: String) {
        lock.lock()
        value += delta
        lock.unlock()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

enum RemoteWriterError: LocalizedError, Equatable {
    /// 토큰 한도에서 잘렸다. 본문은 일부 나왔다.
    case truncated
    /// **추론이 예산을 다 써서 본문이 한 글자도 나오지 않았다.**
    ///
    /// 추론 모델에서 출력 상한은 생각과 답변을 합쳐 센다. 상한이 낮으면
    /// 모델이 생각만 하다 끝나고, 사용자는 요금을 내고 아무것도 받지 못한다.
    /// OpenAI가 직접 적는 증상이다 — "This might occur before any visible
    /// output tokens are produced, meaning you could incur costs for input
    /// and reasoning tokens without receiving a visible response."
    ///
    /// 자동으로 상한을 올려 다시 보내지 않는다. `finish_reason: "length"`가
    /// 네 가지 원인을 뭉갠 값이어서 — 상한 초과, **컨텍스트 초과**, 크레딧
    /// 상한 — 올리는 것이 해결인 경우와 악화인 경우가 섞여 있다. 무엇이
    /// 일어났는지 말하고 사용자가 정하게 한다.
    case reasoningExhaustedBudget(thoughtChars: Int)
    /// 제공자가 200을 주고 아무 글자도 보내지 않았다.
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .truncated:
            "답이 길이 한도에서 잘렸습니다. 받은 문장은 그대로 남아 있습니다. 이어서 만들면 이 섹션을 처음부터 다시 씁니다."
        case .reasoningExhaustedBudget(let chars):
            """
            이 모델이 생각에만 \(String(chars))자를 쓰고 답변을 시작하지 못했습니다.             추론 모델은 출력 한도를 생각과 답변에 함께 쓰기 때문입니다.
            설정 → 해석에서 출력 토큰 상한을 비우시면(권장) 제공자의 기본값을 쓰고,             값을 두시려면 넉넉하게 — OpenAI는 25,000 이상을 권합니다.
            """
        case .emptyResponse:
            "제공자가 응답은 했지만 아무 문장도 보내지 않았습니다. 모델 이름이 맞는지 확인해 주세요."
        }
    }
}

// MARK: - 해석

/// 원격 해석기. 섹션마다 요청 하나.
struct RemoteInterpreter: Interpreter {
    let writer: RemoteWriter
    let brief: InterpretationBrief

    func stream(sections: [InterpretationSection]) -> AsyncThrowingStream<InterpretationChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for (index, section) in sections.enumerated() {
                        try Task.checkCancellation()
                        continuation.yield(.sectionStart(id: section.id))
                        try await writer.run(
                            system: brief.instructions,
                            user: brief.promptText(for: section, includesFacts: index == 0)
                        ) { delta in
                            continuation.yield(.text(sectionID: section.id, delta: delta))
                        }
                        // `sectionEnd`는 "이 섹션이 완성됐다"는 뜻이고,
                        // 보관소는 그것을 받으면 `isComplete = true`로 적어
                        // 디스크에 남긴다. 중단된 섹션에 이것을 보내면
                        // 부분 문장이 완성된 것으로 굳고, 이어가기가 그
                        // 섹션을 건너뛴다. 끊긴 섹션은 버리고 다시 만든다는
                        // 규칙이 여기서 깨진다.
                        try Task.checkCancellation()
                        continuation.yield(.sectionEnd(id: section.id))
                    }
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    // 여기서 끝내면 앞서 완성된 섹션은 남는다. 중단이
                    // 실패가 아니라 행위인 것과 같은 이유로, 실패도
                    // 만들어 둔 것을 지우지 않는다.
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - 상담

/// 원격 상담가.
struct RemoteCounselor: Counselor {
    let writer: RemoteWriter
    let brief: CounselBrief

    func stream(for consultation: Consultation, followUp: String?)
        -> AsyncThrowingStream<String, Error>
    {
        let user = brief.promptText(for: consultation, followUp: followUp)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await writer.run(system: CounselBrief.instructions, user: user) { delta in
                        continuation.yield(delta)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
