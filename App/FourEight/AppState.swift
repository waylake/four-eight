import Foundation
import Observation
import SajuKit

/// 앱 전역 상태 — 인물 목록, 선택, 계산 옵션.
@MainActor
@Observable
final class AppState {
    var store = PersonStore()
    var selectedPersonID: Person.ID?
    var isAddingPerson = false
    var editingPerson: Person?

    /// 유파 옵션 — UserDefaults 지속.
    var options: SajuOptions {
        didSet { saveOptions() }
    }

    /// 해석 톤 설정.
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
        if selectedPersonID == nil { selectedPersonID = store.people.first?.id }
    }

    private func saveOptions() {
        if let data = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(data, forKey: "sajuOptions")
        }
    }

    var selectedPerson: Person? {
        store.people.first { $0.id == selectedPersonID }
    }

    /// 현재 선택 인물의 계산 결과.
    var reading: Reading? {
        guard let person = selectedPerson else { return nil }
        return try? SajuService.reading(for: person, options: options)
    }
}
