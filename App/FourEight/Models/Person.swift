import Foundation
import SajuKit

/// 저장되는 인물 — 이름 + 출생 정보.
struct Person: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var birth: BirthInput
    var createdAt = Date()

    /// 표시용 생년월일 요약.
    var birthSummary: String {
        let calendarLabel: String
        switch birth.calendarType {
        case .solar: calendarLabel = "양력"
        case .lunar(let leap): calendarLabel = leap ? "음력(윤달)" : "음력"
        }
        var s = "\(calendarLabel) \(birth.year).\(String(format: "%02d", birth.month)).\(String(format: "%02d", birth.day))"
        if let hour = birth.hour {
            s += " \(String(format: "%02d:%02d", hour, birth.minute))"
        } else {
            s += " 시간 미상"
        }
        return s
    }
}

/// JSON 파일 기반 인물 저장소.
@MainActor
@Observable
final class PersonStore {
    private(set) var people: [Person] = []

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FourEight", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("people.json")
    }

    init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let decoded = try? JSONDecoder().decode([Person].self, from: data) else { return }
        people = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(people) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    func add(_ person: Person) {
        people.append(person)
        save()
    }

    func update(_ person: Person) {
        guard let i = people.firstIndex(where: { $0.id == person.id }) else { return }
        people[i] = person
        save()
    }

    func remove(_ id: Person.ID) {
        people.removeAll { $0.id == id }
        save()
    }
}
