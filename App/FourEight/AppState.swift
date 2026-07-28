import Foundation
import Observation
import SajuKit

/// 사이드바 목적지. 앱에는 두 가지 사용 모드가 있다.
///
/// 명식은 평생 바뀌지 않으므로 "한 번 보고 닫는" 화면이다. 그것만으로는
/// 앱을 다시 열 이유가 없다. 시간 축(오늘·캘린더)이 두 번째 모드이며,
/// 같은 명식을 매일 다른 각도에서 보게 한다.
enum Destination: Hashable {
    case today
    case calendar
    case chart
    case consultation
}

@MainActor
@Observable
final class AppState {
    var store = PersonStore()
    var selectedPersonID: Person.ID?
    var destination: Destination = .today
    var isAddingPerson = false
    var editingPerson: Person?
    /// 캘린더에서 선택한 날. nil이면 오늘.
    var selectedDate: Date?
    /// 보고 있는 상담. nil이면 새 상담 화면.
    var selectedConsultationID: UUID?
    /// 캘린더가 보고 있는 달.
    var visibleMonth = Date()

    var options: SajuOptions {
        didSet { saveOptions() }
    }

    var useLLM: Bool {
        didSet { UserDefaults.standard.set(useLLM, forKey: "useLLM") }
    }

    init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: "sajuOptions"),
           let decoded = try? JSONDecoder().decode(SajuOptions.self, from: data) {
            options = decoded
        } else {
            options = .default
        }
        useLLM = d.object(forKey: "useLLM") as? Bool ?? true
        if let saved = d.string(forKey: "selectedPerson"), let id = UUID(uuidString: saved),
           store.people.contains(where: { $0.id == id }) {
            selectedPersonID = id
        } else {
            selectedPersonID = store.people.first?.id
        }
    }

    private func saveOptions() {
        if let data = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(data, forKey: "sajuOptions")
        }
    }

    func select(_ id: Person.ID?) {
        selectedPersonID = id
        // 상담은 인물에 매인 기록이다. 다른 사람으로 옮기면 선택을 놓는다.
        selectedConsultationID = nil
        UserDefaults.standard.set(id?.uuidString, forKey: "selectedPerson")
    }

    var selectedPerson: Person? {
        store.people.first { $0.id == selectedPersonID }
    }

    /// 계산 결과. 같은 입력에는 같은 결과가 나오므로 캐시해 둔다.
    /// 계산 자체는 밀리초 단위지만, 뷰가 그릴 때마다 다시 도는 것을 막는다.
    private var readingCache: (key: String, reading: Reading)?

    var reading: Reading? {
        guard let person = selectedPerson else { return nil }
        let key = "\(person.id)|\(person.birth.hashValue)|\(options.hashValue)"
        if let cached = readingCache, cached.key == key { return cached.reading }
        guard let fresh = try? SajuService.reading(for: person, options: options) else { return nil }
        readingCache = (key, fresh)
        return fresh
    }

    /// 캘린더·오늘 화면이 보는 날짜.
    var activeDate: Date {
        selectedDate ?? Date()
    }
}
