import Foundation
import Observation
import SajuKit

/// 사이드바가 고르는 화면. 앱에는 두 가지 사용 모드가 있다.
///
/// 이름이 `Destination`이었다. 원격 제공자를 붙이면서 "글이 어디까지
/// 가는가"를 뜻하는 `RemoteLLM.Destination`이 생겼고, 한 이름이 화면
/// 이동과 데이터 전송을 동시에 뜻하게 됐다. 둘 중 이쪽을 바꾼 이유는
/// 저쪽이 보관 파일의 `kind` 값과 패키지의 공개 API에 이미 박혀 있어서다.
/// 바꿀 수 있는 쪽을 바꾼다.
///
/// 명식은 평생 바뀌지 않으므로 "한 번 보고 닫는" 화면이다. 그것만으로는
/// 앱을 다시 열 이유가 없다. 시간 축(오늘·캘린더)이 두 번째 모드이며,
/// 같은 명식을 매일 다른 각도에서 보게 한다.
enum Page: Hashable {
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
    var page: Page = .today
    var isAddingPerson = false
    var editingPerson: Person?
    /// 캘린더에서 선택한 날. nil이면 오늘.
    var selectedDate: Date?
    /// 보고 있는 상담. nil이면 새 상담 화면.
    var selectedConsultationID: UUID?
    /// 캘린더가 보고 있는 달.
    var visibleMonth = Date()

    /// 지난 상담 목록을 보이는가. 접어 두면 읽는 열이 넓어진다.
    /// 사용자가 접어 둔 것은 다음 실행에도 접혀 있어야 한다.
    var showsConsultationList: Bool {
        didSet { UserDefaults.standard.set(showsConsultationList, forKey: "showsConsultationList") }
    }

    /// 상담 목록 검색어. 창 수명이면 충분하다 — 다음 실행에 검색어가
    /// 남아 있으면 사용자는 상담이 사라졌다고 읽는다.
    var consultationQuery = ""

    // MARK: - 포커스 신호
    //
    // 메뉴 명령과 칩이 "여기에 커서를 두라"고 말하는 방법이다. 값 자체에는
    // 뜻이 없고 **바뀌었다는 사실**만 뜻이 있다. 불리언으로 두면 두 번 연속
    // 부를 때 두 번째가 먹지 않는다.
    //
    // 생성은 이 경로로 시작되지 않는다. 포커스만 옮긴다.
    private(set) var composerFocusToken = 0
    private(set) var searchFocusToken = 0
    private(set) var exportRequestToken = 0

    func focusConsultationComposer() { composerFocusToken += 1 }

    /// 목록이 접혀 있으면 검색창이 아직 화면에 없다. 같은 갱신 안에서
    /// 신호를 보내면 그 뷰의 `onChange`가 아직 살아 있지 않아 조용히
    /// 삼켜지고, 사용자는 ⌘F를 두 번 눌러야 한다. 펴는 것과 커서를 옮기는
    /// 것을 한 박자 떼어 놓는다.
    func focusConsultationSearch() {
        guard !showsConsultationList else {
            searchFocusToken += 1
            return
        }
        showsConsultationList = true
        Task { @MainActor in searchFocusToken += 1 }
    }
    func requestConsultationExport() { exportRequestToken += 1 }

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
        showsConsultationList = d.object(forKey: "showsConsultationList") as? Bool ?? true
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
