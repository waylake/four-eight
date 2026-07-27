import Foundation
import Observation
import SajuKit

/// 생성된 해석의 보관소.
///
/// 해석은 뷰의 상태가 아니라 문서의 상태다. 인물을 바꿨다 돌아와도,
/// 창을 다시 열어도, 시트를 띄웠다 닫아도 이미 만든 문장은 남아야 한다.
/// 뷰에 두면 SwiftUI가 뷰를 다시 만들 때마다 처음부터 생성한다.
///
/// 중단과 재개도 이 구조가 있어야 성립한다. 섹션 단위로 완료를 기록하므로
/// 재개는 "미완료 섹션부터"라는 명확한 의미를 갖는다.
@MainActor
@Observable
final class InterpretationStore {
    /// 어떤 내용을, 어떤 엔진으로 만들었는지까지 포함한 키.
    /// 유파 옵션을 바꾸면 명식 서명이 바뀌므로 자동으로 새 키가 된다.
    struct Key: Hashable {
        let subject: String       // 인물 ID 또는 "today:2026-07-28"
        let signature: String     // 명식 서명
        let engine: String        // "template" 또는 모델 ID
    }

    struct SectionState {
        var text: String = ""
        var isComplete: Bool = false
    }

    struct Document {
        var order: [String] = []
        var titles: [String: String] = [:]
        var evidence: [String: [Rule]] = [:]
        var sections: [String: SectionState] = [:]

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
    }

    enum Phase: Equatable {
        case idle
        case running(section: String, index: Int, total: Int)
        case stopped
        case done
        case failed(String)
    }

    private(set) var documents: [Key: Document] = [:]
    private(set) var phases: [Key: Phase] = [:]
    private var tasks: [Key: Task<Void, Never>] = [:]

    // MARK: - 조회

    func document(for key: Key) -> Document {
        documents[key] ?? Document()
    }

    func phase(for key: Key) -> Phase {
        phases[key] ?? .idle
    }

    /// 실행 중 판정은 phase가 아니라 task로 한다.
    ///
    /// phase는 첫 청크가 도착해야 .running이 된다. 그 사이에 뷰가 다시
    /// 나타나면 ensure가 한 번 더 통과해 같은 섹션에 두 번 이어붙는다.
    /// 실제로 이 버그가 스크린샷에서 잡혔다.
    func isRunning(_ key: Key) -> Bool {
        tasks[key] != nil
    }

    // MARK: - 생성 제어

    /// 캐시가 없을 때만 생성을 시작한다. 뷰가 다시 나타나도 안전하다.
    ///
    /// 사용자가 시키지 않으면 재생성하지 않는다는 원칙이 여기에 있다.
    /// 계산은 공짜지만 생성은 배터리와 시간이다.
    func ensure(key: Key, sections: [InterpretationSection], interpreter: any Interpreter) {
        guard !isRunning(key) else { return }
        let doc = document(for: key)
        if doc.isComplete { return }
        if case .stopped = phase(for: key) { return }   // 중단은 사용자의 의사다.
        run(key: key, sections: sections, interpreter: interpreter, resuming: !doc.order.isEmpty)
    }

    /// 사용자가 명시적으로 요청한 재생성. 캐시를 버린다.
    func regenerate(key: Key, sections: [InterpretationSection], interpreter: any Interpreter) {
        tasks[key]?.cancel()
        tasks[key] = nil
        documents[key] = nil
        run(key: key, sections: sections, interpreter: interpreter, resuming: false)
    }

    /// 중단. 만들어 둔 문장은 남긴다.
    func stop(key: Key) {
        tasks[key]?.cancel()
        tasks[key] = nil
        phases[key] = .stopped
    }

    /// 재개. 미완료 섹션부터 이어간다.
    func resume(key: Key, sections: [InterpretationSection], interpreter: any Interpreter) {
        guard !isRunning(key) else { return }
        run(key: key, sections: sections, interpreter: interpreter, resuming: true)
    }

    // MARK: - 실행

    private func run(
        key: Key,
        sections: [InterpretationSection],
        interpreter: any Interpreter,
        resuming: Bool
    ) {
        var doc = resuming ? document(for: key) : Document()
        doc.order = sections.map(\.id)
        for section in sections {
            doc.titles[section.id] = section.title
            doc.evidence[section.id] = section.rules
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
            return
        }

        let total = sections.count
        let stream = interpreter.stream(sections: pending)
        // Task를 만들기 전에 상태를 잡아 둔다. 첫 청크를 기다리는 사이에
        // 다른 호출이 들어오면 같은 섹션이 두 번 생성된다.
        if let first = pending.first {
            let index = (doc.order.firstIndex(of: first.id) ?? 0) + 1
            phases[key] = .running(section: first.id, index: index, total: total)
        }

        tasks[key] = Task { [weak self] in
            do {
                for try await chunk in stream {
                    guard let self, !Task.isCancelled else { return }
                    switch chunk {
                    case .sectionStart(let id):
                        let index = (self.documents[key]?.order.firstIndex(of: id) ?? 0) + 1
                        self.phases[key] = .running(section: id, index: index, total: total)
                    case .text(let id, let delta):
                        self.documents[key]?.sections[id, default: SectionState()].text += delta
                    case .sectionEnd(let id):
                        self.documents[key]?.sections[id]?.isComplete = true
                    case .done:
                        break
                    }
                }
                guard let self, !Task.isCancelled else { return }
                self.phases[key] = self.document(for: key).isComplete ? .done : .stopped
            } catch is CancellationError {
                // 중단은 stop()이 이미 표시했다.
            } catch {
                self?.phases[key] = .failed(error.localizedDescription)
            }
            self?.tasks[key] = nil
        }
    }

    /// 인물이 사라졌을 때 정리.
    func discard(subject: String) {
        for key in documents.keys where key.subject == subject {
            tasks[key]?.cancel()
            tasks[key] = nil
            documents[key] = nil
            phases[key] = nil
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
