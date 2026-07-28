import Foundation
import Observation
import SajuKit

/// 상담 기록의 보관소.
///
/// 해석과 같은 취급이다. 상담은 뷰의 상태가 아니라 **사용자가 남긴 기록**이며,
/// 인물을 바꿔도, 창을 닫아도, 앱을 껐다 켜도 남는다. 상담은 며칠에 걸쳐
/// 이어질 수 있는 종류의 것이다.
///
/// 여기서도 규칙은 하나다. **읽기는 앱이 알아서, 쓰기는 사용자만.**
/// `restore`는 화면이 나타날 때 불러도 좋다. `answer`는 버튼만 부른다.
@MainActor
@Observable
final class ConsultationStore {
    enum Phase: Equatable {
        case idle
        case preparingModel
        case writing
        case stopped
        case failed(String)
    }

    /// 답변 재료를 준비하는 쪽. 모델 적재가 여기서 일어난다.
    typealias Supplier = @MainActor () async -> (counselor: Counselor, provenance: InterpretationStore.Provenance)?

    private(set) var consultations: [Consultation] = []
    private(set) var phases: [UUID: Phase] = [:]
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var restoredPeople: Set<UUID> = []

    // MARK: - 조회

    func consultations(for personID: UUID) -> [Consultation] {
        consultations
            .filter { $0.personID == personID }
            .sorted { $0.openedAt > $1.openedAt }
    }

    func consultation(id: UUID) -> Consultation? {
        consultations.first { $0.id == id }
    }

    func phase(of id: UUID) -> Phase { phases[id] ?? .idle }

    func isWriting(_ id: UUID) -> Bool { tasks[id] != nil }

    /// 디스크에서 되살린다. 읽기뿐이고, 없으면 아무 일도 하지 않는다.
    func restore(personID: UUID) {
        guard !restoredPeople.contains(personID) else { return }
        restoredPeople.insert(personID)
        let loaded = Archive.load(personID: personID)
        let known = Set(consultations.map(\.id))
        consultations.append(contentsOf: loaded.filter { !known.contains($0.id) })
    }

    // MARK: - 사용자의 행위

    /// 상담을 연다. **모델을 부르지 않는다.**
    ///
    /// 고민을 받고, 축을 정하고, 근거를 고르고, 되묻는 것까지가 여기서
    /// 끝난다. 전부 결정론적이므로 0초에 끝나고 모델이 없어도 된다.
    /// 사용자는 모델을 내려받기 전에도 상담을 시작할 수 있다.
    func open(
        personID: UUID,
        signature: String,
        concern: String,
        topic: ConsultationTopic,
        matchedTerms: [String],
        evidenceIDs: [String],
        includesToday: Bool,
        opening: [Consultation.Turn]
    ) -> Consultation {
        let consultation = Consultation(
            id: UUID(),
            personID: personID,
            signature: signature,
            openedAt: Date(),
            concern: concern,
            topic: topic,
            matchedTerms: matchedTerms,
            evidenceIDs: evidenceIDs,
            includesToday: includesToday,
            turns: opening,
            provenance: nil
        )
        consultations.append(consultation)
        persist(consultation)
        return consultation
    }

    /// 사용자가 사정을 덧붙인다. 이것도 모델을 부르지 않는다.
    func addPersonTurn(_ text: String, to id: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = index(of: id) else { return }
        consultations[index].turns.append(.init(speaker: .person, text: trimmed))
        persist(consultations[index])
    }

    /// 앱이 결정론적으로 말하는 것 — 되묻기, 안전 안내, 한계 고지.
    func addAppTurn(_ text: String, to id: UUID) {
        guard let index = index(of: id) else { return }
        consultations[index].turns.append(.init(speaker: .app, text: text))
        persist(consultations[index])
    }

    /// 주제를 사용자가 고친다. 근거가 함께 바뀌므로 호출자가 새 근거를 준다.
    func retopic(_ id: UUID, topic: ConsultationTopic, evidenceIDs: [String]) {
        guard let index = index(of: id) else { return }
        consultations[index].topic = topic
        consultations[index].evidenceIDs = evidenceIDs
        consultations[index].matchedTerms = []
        persist(consultations[index])
    }

    func setIncludesToday(_ value: Bool, for id: UUID) {
        guard let index = index(of: id) else { return }
        consultations[index].includesToday = value
        persist(consultations[index])
    }

    /// 풀이를 받는다. **버튼에서만 불린다.**
    func answer(id: UUID, followUp: String? = nil, supplier: @escaping Supplier) {
        guard !isWriting(id), let index = index(of: id) else { return }
        phases[id] = .preparingModel
        let snapshot = consultations[index]

        tasks[id] = Task { [weak self] in
            guard let prepared = await supplier() else {
                self?.phases[id] = .failed("모델을 불러오지 못했습니다.")
                self?.tasks[id] = nil
                return
            }
            guard let self, !Task.isCancelled, let index = self.index(of: id) else { return }

            if let followUp, !followUp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                consultations[index].turns.append(
                    .init(speaker: .person, text: followUp.trimmingCharacters(in: .whitespacesAndNewlines))
                )
            }
            consultations[index].provenance = prepared.provenance
            let turn = Consultation.Turn(
                speaker: .counselor, text: "", isComplete: false,
                evidenceIDs: snapshot.evidenceIDs
            )
            consultations[index].turns.append(turn)
            phases[id] = .writing

            do {
                for try await chunk in prepared.counselor.stream(
                    for: consultations[index], followUp: followUp
                ) {
                    guard !Task.isCancelled else { return }
                    guard let at = self.index(of: id),
                          let turnAt = consultations[at].turns.firstIndex(where: { $0.id == turn.id })
                    else { return }
                    consultations[at].turns[turnAt].text += chunk
                }
                guard !Task.isCancelled else { return }
                // 4B 모델은 실제로 아무 말도 하지 않는 경우가 있다.
                // (Vectara 리더보드 기준 Gemma 3 4B의 응답률은 67.3%다.)
                // 빈 말풍선을 남기지 않고, 무슨 일이 일어났는지 적는다.
                if complete(turn: turn.id, in: id, dropIfEmpty: true) {
                    addAppTurn(
                        "모델이 이 근거로는 답을 내지 못했습니다. 위의 근거 원문이 이 주제에 대해 확정된 내용이며, 다시 시도하시거나 사정을 조금 더 적어 주시면 달라질 수 있습니다.",
                        to: id
                    )
                }
                phases[id] = .idle
            } catch is CancellationError {
                // stop()이 이미 정리했다.
            } catch {
                _ = complete(turn: turn.id, in: id, dropIfEmpty: true)
                phases[id] = .failed(error.localizedDescription)
            }
            if let at = self.index(of: id) { persist(consultations[at]) }
            tasks[id] = nil
        }
    }

    /// 중단. 쓰던 문장은 남긴다 — 사용자가 읽을 만큼 나왔을 수 있다.
    func stop(id: UUID) {
        tasks[id]?.cancel()
        tasks[id] = nil
        phases[id] = .stopped
        if let index = index(of: id),
           let last = consultations[index].turns.indices.last,
           consultations[index].turns[last].speaker == .counselor {
            consultations[index].turns[last].isComplete = true
            if consultations[index].turns[last].text.isEmpty {
                consultations[index].turns.removeLast()
            }
            persist(consultations[index])
        }
    }

    func delete(id: UUID) {
        tasks[id]?.cancel()
        tasks[id] = nil
        phases[id] = nil
        consultations.removeAll { $0.id == id }
        Task.detached(priority: .utility) { Archive.remove(id: id) }
    }

    /// 인물이 사라졌을 때.
    func discard(personID: UUID) {
        for consultation in consultations(for: personID) {
            tasks[consultation.id]?.cancel()
            tasks[consultation.id] = nil
            phases[consultation.id] = nil
        }
        consultations.removeAll { $0.personID == personID }
        restoredPeople.remove(personID)
        Task.detached(priority: .utility) { Archive.removeAll(personID: personID) }
    }

    // MARK: - 내부

    private func index(of id: UUID) -> Int? {
        consultations.firstIndex { $0.id == id }
    }

    /// 빈 답을 버렸으면 true.
    @discardableResult
    private func complete(turn turnID: UUID, in id: UUID, dropIfEmpty: Bool = false) -> Bool {
        guard let index = index(of: id),
              let at = consultations[index].turns.firstIndex(where: { $0.id == turnID })
        else { return false }
        consultations[index].turns[at].isComplete = true
        let isEmpty = consultations[index].turns[at].text
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if dropIfEmpty, isEmpty {
            consultations[index].turns.remove(at: at)
            return true
        }
        return false
    }

    private func persist(_ consultation: Consultation) {
        Task.detached(priority: .utility) { Archive.save(consultation) }
    }

    // MARK: - 디스크

    /// 상담 하나에 파일 하나. 파일명은 상담 ID이므로 해시가 필요 없다.
    enum Archive {
        static var directory: URL {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            return base.appendingPathComponent("FourEight/consultations", isDirectory: true)
        }

        static func save(_ consultation: Consultation) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let data = try encoder.encode(consultation)
                try data.write(to: url(for: consultation.id), options: .atomic)
            } catch {
                NSLog("상담 보관 실패: \(error.localizedDescription)")
            }
        }

        static func load(personID: UUID) -> [Consultation] {
            all().filter { $0.personID == personID }
        }

        static func remove(id: UUID) {
            try? FileManager.default.removeItem(at: url(for: id))
        }

        static func removeAll(personID: UUID) {
            for consultation in load(personID: personID) {
                remove(id: consultation.id)
            }
        }

        static func all() -> [Consultation] {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil
            ) else { return [] }
            return files.compactMap { url in
                guard url.pathExtension == "json", let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(Consultation.self, from: data)
            }
        }

        private static func url(for id: UUID) -> URL {
            directory.appendingPathComponent("\(id.uuidString).json")
        }

        private static let decoder: JSONDecoder = {
            let d = JSONDecoder()
            d.dateDecodingStrategy = .iso8601
            return d
        }()

        private static let encoder: JSONEncoder = {
            let e = JSONEncoder()
            e.dateEncodingStrategy = .iso8601
            e.outputFormatting = [.prettyPrinted, .sortedKeys]
            return e
        }()
    }
}
