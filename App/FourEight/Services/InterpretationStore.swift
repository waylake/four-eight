import Foundation
import Observation
import RemoteLLM
import SajuKit

/// **AI가 쓴 해석문**의 보관소.
///
/// 규칙 엔진 문장은 여기 없다. 그것은 `InterpretationSection.baselineText`로
/// 계산과 함께 나오며, 화면에 항상 있다. 이 보관소가 다루는 것은 사용자가
/// 시간과 배터리를 들여 주문한 산출물 하나뿐이다.
///
/// 둘을 한 슬롯에 넣었을 때 실제로 벌어진 일:
/// 캐시 키에 엔진 종류가 들어 있어서, 모델을 켜는 것이 "캐시 전체 무효화"와
/// 같은 의미가 됐다. 사용자는 문장을 갈아치우라고 한 적이 없는데 앱은
/// 빈 캐시를 발견하고 성실하게 채웠다. 지금 키에 엔진이 없는 이유다.
///
/// 규칙 하나: **읽기는 앱이 알아서, 쓰기는 사용자만.**
/// `restore`는 뷰가 나타날 때 불러도 좋다. `generate`는 버튼만 부른다.
@MainActor
@Observable
final class InterpretationStore {
    /// 무엇에 대한 해석인가. 어떤 엔진으로 만들었는지는 키가 아니라 기록이다.
    ///
    /// 유파 옵션을 바꾸면 명식 서명이 바뀌므로 자동으로 다른 문서가 된다.
    struct Key: Hashable, Sendable {
        let subject: String       // 인물 ID 또는 "인물 ID#2026-07-28"
        let signature: String     // 명식 서명
    }

    /// 이 문장을 누가 언제 무엇으로 썼는가.
    ///
    /// 표시용 라벨을 "현재 설정"에서 뽑으면 거짓말이 된다. 설정을 바꾸는
    /// 순간 이미 화면에 있는 문장의 출처 표기가 바뀌기 때문이다.
    /// 라벨은 예측이 아니라 기록에서 나와야 한다.
    struct Provenance: Codable, Sendable, Hashable {
        var modelID: String
        var modelName: String
        var writtenAt: Date
        var appVersion: String
        /// 근거 콘텐츠 판(rules.json version). 이 값이 지금과 다르면
        /// 그 사이 근거 문장이 바뀐 것이므로 화면에 표시한다.
        var ruleSetVersion: Int
        /// 이 문장을 만드는 동안 글이 어디까지 갔는가.
        ///
        /// 옵셔널인 이유는 마이그레이션이다. 이 항목이 생기기 전에 보관된
        /// 문서에는 값이 없고, 그때는 원격 경로가 존재하지 않았으므로
        /// **nil은 `.inProcess`를 뜻한다.** "모른다"가 아니다.
        /// 기본값을 준 비옵셔널 항목으로 두면 합성된 디코더가 키 없음에서
        /// 실패해 사용자가 이미 만든 해석을 전부 잃는다.
        var destination: Destination?

        /// 화면과 내보내기에 쓰는 목적지. nil의 뜻을 한 곳에서만 해석한다.
        var resolvedDestination: Destination { destination ?? .inProcess }
    }

    struct SectionState: Codable, Sendable, Hashable {
        var text: String = ""
        var isComplete: Bool = false
        /// **이 섹션을** 누가 어디로 보내 썼는가.
        ///
        /// 문서 단위 출처만 두었을 때 거짓말이 생긴다. 재개는 미완료
        /// 섹션만 다시 만들므로, Gemma로 절반을 만들고 원격으로 이어가면
        /// 문서의 출처는 원격으로 덮어써지고 앞의 절반도 원격이 쓴 것으로
        /// 표시된다. 생성의 단위가 섹션이면 출처의 단위도 섹션이어야 한다.
        var provenance: Provenance?
    }

    struct Document: Codable, Sendable {
        var order: [String] = []
        var titles: [String: String] = [:]
        var sections: [String: SectionState] = [:]
        var provenance: Provenance

        var isComplete: Bool {
            !order.isEmpty && order.allSatisfy { sections[$0]?.isComplete == true }
        }
        /// 아직 만들지 않았거나 중간에 끊긴 첫 섹션.
        var firstIncomplete: String? {
            order.first { sections[$0]?.isComplete != true }
        }
        var completedCount: Int {
            order.filter { sections[$0]?.isComplete == true }.count
        }
        func text(for sectionID: String) -> String? {
            guard let state = sections[sectionID], !state.text.isEmpty else { return nil }
            return state.text
        }

        /// 완성된 섹션들이 실제로 거쳐 간 목적지. 중복 없이, 나온 순서대로.
        ///
        /// 문서 하나에 여러 개가 담길 수 있다. 사용자가 Gemma로 절반을
        /// 만들고 원격으로 이어간 경우가 그렇고, 그때 "이 해석은 어디서
        /// 왔는가"의 정직한 답은 하나가 아니다.
        var destinations: [Destination] {
            var seen: [Destination] = []
            for id in order {
                guard let state = sections[id], state.isComplete else { continue }
                let destination = (state.provenance ?? provenance).resolvedDestination
                if !seen.contains(destination) { seen.append(destination) }
            }
            return seen
        }

        /// 이 문서의 일부가 이 Mac을 벗어난 적이 있는가.
        var anySectionLeftMachine: Bool {
            destinations.contains { $0.leavesMachine }
        }
    }

    enum Phase: Equatable {
        case idle
        /// 모델을 메모리에 올리는 중. 생성의 일부이지 별도의 설정 단계가 아니다.
        case preparingModel
        case running(section: String, index: Int, total: Int)
        case stopped
        case done
        case failed(String)
    }

    /// 생성에 필요한 재료를 그때그때 준비하는 쪽. 모델 적재가 여기서 일어난다.
    /// nil을 돌려주면 준비 실패다.
    typealias Supplier = @MainActor () async -> (interpreter: any Interpreter, provenance: Provenance)?

    private(set) var documents: [Key: Document] = [:]
    private(set) var phases: [Key: Phase] = [:]
    private var tasks: [Key: Task<Void, Never>] = [:]
    private var restored: Set<Key> = []

    init(prunesArchive: Bool = true) {
        guard prunesArchive else { return }
        // 보존 기한 정리는 시작을 늦출 이유가 없다.
        Task.detached(priority: .background) {
            InterpretationArchive.prune()
        }
    }

    // MARK: - 조회

    /// AI가 쓴 문서. nil이면 아직 주문한 적이 없다는 뜻이며, 화면은
    /// 기준선 문장을 보여준다. nil은 실패가 아니라 정상 상태다.
    func document(for key: Key) -> Document? {
        documents[key]
    }

    func phase(for key: Key) -> Phase {
        phases[key] ?? .idle
    }

    /// 실행 중 판정은 phase가 아니라 task로 한다.
    ///
    /// phase는 첫 청크가 도착해야 .running이 된다. 그 사이에 뷰가 다시
    /// 나타나면 같은 섹션에 두 번 이어붙는다. 실제로 겪은 버그다.
    func isRunning(_ key: Key) -> Bool {
        tasks[key] != nil
    }

    /// 디스크에서 되살린다. 뷰가 나타날 때 불러도 안전하다 — 읽기뿐이고,
    /// 없으면 아무 일도 하지 않는다. **이 메서드는 절대 생성하지 않는다.**
    func restore(key: Key) {
        guard !restored.contains(key) else { return }
        restored.insert(key)
        guard documents[key] == nil,
              let document = InterpretationArchive.load(
                  subject: key.subject, signature: key.signature
              )
        else { return }
        documents[key] = document
        phases[key] = document.isComplete ? .done : .stopped
    }

    // MARK: - 생성 — 사용자의 행위

    /// 처음부터 쓴다. 버튼에서만 불린다.
    func generate(key: Key, sections: [InterpretationSection], supplier: @escaping Supplier) {
        guard !isRunning(key) else { return }
        run(key: key, sections: sections, supplier: supplier, resuming: false)
    }

    /// 중단·실패 지점부터 이어 쓴다.
    func resume(key: Key, sections: [InterpretationSection], supplier: @escaping Supplier) {
        guard !isRunning(key) else { return }
        run(key: key, sections: sections, supplier: supplier, resuming: documents[key] != nil)
    }

    /// 중단. 만들어 둔 문장은 남긴다.
    func stop(key: Key) {
        tasks[key]?.cancel()
        tasks[key] = nil
        phases[key] = .stopped
        persist(key)
    }

    /// 사용자가 AI 문장을 버린다. 기준선은 원래 지울 수 있는 것이 아니다.
    func discardDocument(key: Key) {
        tasks[key]?.cancel()
        tasks[key] = nil
        documents[key] = nil
        phases[key] = .idle
        InterpretationArchive.remove(subject: key.subject, signature: key.signature)
    }

    /// 인물이 사라졌을 때 정리. 그 인물의 날짜별 풀이까지 함께 지운다.
    func discard(subject: String) {
        for key in documents.keys where key.subject.hasPrefix(subject) {
            tasks[key]?.cancel()
            tasks[key] = nil
            documents[key] = nil
            phases[key] = nil
            restored.remove(key)
        }
        let prefix = subject
        Task.detached(priority: .utility) {
            InterpretationArchive.removeAll(subjectPrefix: prefix)
        }
    }

    // MARK: - 실행

    private func run(
        key: Key,
        sections: [InterpretationSection],
        supplier: @escaping Supplier,
        resuming: Bool
    ) {
        let total = sections.count
        phases[key] = .preparingModel

        // Task를 먼저 등록한다. 모델 적재는 수 초가 걸리고, 그 사이에
        // 버튼이 다시 눌리면 같은 문서를 두 번 쓴다.
        tasks[key] = Task { [weak self] in
            guard let prepared = await supplier() else {
                self?.phases[key] = .failed("모델을 불러오지 못했습니다.")
                self?.tasks[key] = nil
                return
            }
            guard let self, !Task.isCancelled else { return }

            var doc = resuming ? (documents[key] ?? Document(provenance: prepared.provenance))
                               : Document(provenance: prepared.provenance)
            doc.provenance = prepared.provenance
            doc.order = sections.map(\.id)
            for section in sections {
                doc.titles[section.id] = section.title
                if doc.sections[section.id] == nil {
                    doc.sections[section.id] = SectionState()
                }
            }
            // 끊긴 섹션은 부분 문장을 버리고 다시 만든다. 문장 중간에서
            // 이어붙이면 앞뒤가 어긋난 글이 나온다.
            if let incomplete = doc.firstIncomplete {
                doc.sections[incomplete] = SectionState()
            }
            documents[key] = doc

            let pending = sections.filter { doc.sections[$0.id]?.isComplete != true }
            guard !pending.isEmpty else {
                phases[key] = .done
                tasks[key] = nil
                persist(key)
                return
            }
            if let first = pending.first {
                let index = (doc.order.firstIndex(of: first.id) ?? 0) + 1
                phases[key] = .running(section: first.id, index: index, total: total)
            }

            do {
                for try await chunk in prepared.interpreter.stream(sections: pending) {
                    guard !Task.isCancelled else { return }
                    switch chunk {
                    case .sectionStart(let id):
                        let index = (documents[key]?.order.firstIndex(of: id) ?? 0) + 1
                        phases[key] = .running(section: id, index: index, total: total)
                    case .text(let id, let delta):
                        documents[key]?.sections[id, default: SectionState()].text += delta
                    case .sectionEnd(let id):
                        documents[key]?.sections[id]?.isComplete = true
                        // 이 섹션을 실제로 쓴 쪽을 여기서 적는다. 문서
                        // 단위로만 적으면 재개할 때 앞서 다른 곳에서 쓴
                        // 섹션의 출처가 덮어써진다.
                        documents[key]?.sections[id]?.provenance = prepared.provenance
                        // 섹션 단위로 보관한다. 여기서 앱이 죽어도 완성된
                        // 섹션은 남고, 다음 실행은 남은 것부터 이어간다.
                        persist(key)
                    case .done:
                        break
                    }
                }
                guard !Task.isCancelled else { return }
                phases[key] = (documents[key]?.isComplete ?? false) ? .done : .stopped
            } catch is CancellationError {
                // 중단은 stop()이 이미 표시했다.
            } catch {
                phases[key] = .failed(error.localizedDescription)
            }
            persist(key)
            tasks[key] = nil
        }
    }

    private func persist(_ key: Key) {
        guard let document = documents[key] else { return }
        let subject = key.subject
        let signature = key.signature
        Task.detached(priority: .utility) {
            InterpretationArchive.save(subject: subject, signature: signature, document: document)
        }
    }
}

extension SajuChart {
    /// 명식 서명 — 계산 결과가 같으면 같은 값.
    /// 유파 옵션을 바꾸면 명식이나 보정이 달라지므로 서명도 달라진다.
    var signature: String {
        let c = corrections
        return [
            compactHanja,
            String(c.solarTimeSecondsOfDay),
            String(c.utcOffsetSeconds),
            isNightJasi ? "y" : "n",
            governingJeol.korean,
        ].joined(separator: "|")
    }
}
