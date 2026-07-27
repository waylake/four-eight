import SwiftUI
import SajuKit

/// 출생 정보 입력 — 적용되는 보정을 입력 중에 그대로 보여준다.
struct BirthInputSheet: View {
    enum Mode {
        case add
        case edit(Person)
    }

    let mode: Mode
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var year = 1995
    @State private var month = 6
    @State private var day = 15
    @State private var knowsTime = true
    @State private var hour = 12
    @State private var minute = 0
    @State private var isLunar = false
    @State private var isLeapMonth = false
    @State private var gender: Gender = .male
    @State private var cityIndex = 0
    @State private var customLongitude = 126.978

    static let cities: [(name: String, longitude: Double)] = [
        ("서울", 126.978), ("부산", 129.075), ("대구", 128.601), ("인천", 126.705),
        ("광주", 126.852), ("대전", 127.385), ("울산", 129.311), ("세종", 127.289),
        ("수원", 127.029), ("청주", 127.489), ("전주", 127.148), ("포항", 129.343),
        ("창원", 128.681), ("제주", 126.532), ("평양", 125.754), ("직접 입력", .nan),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("기본 정보") {
                    TextField("이름", text: $name, prompt: Text("이름 또는 별칭"))
                    Picker("성별", selection: $gender) {
                        ForEach(Gender.allCases, id: \.self) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("생년월일") {
                    Picker("달력", selection: $isLunar) {
                        Text("양력").tag(false)
                        Text("음력").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if isLunar {
                        Toggle("윤달", isOn: $isLeapMonth)
                    }
                    HStack {
                        Picker("년", selection: $year) {
                            ForEach(1900...2100, id: \.self) { Text(String($0)).tag($0) }
                        }
                        .frame(width: 110)
                        Picker("월", selection: $month) {
                            ForEach(1...12, id: \.self) { Text("\($0)월").tag($0) }
                        }
                        .frame(width: 90)
                        Picker("일", selection: $day) {
                            ForEach(1...31, id: \.self) { Text("\($0)일").tag($0) }
                        }
                        .frame(width: 90)
                    }
                    .labelsHidden()
                }

                Section("출생 시각") {
                    Toggle("시각을 알고 있음", isOn: $knowsTime)
                    if knowsTime {
                        HStack {
                            Picker("시", selection: $hour) {
                                ForEach(0...23, id: \.self) { Text(String(format: "%02d시", $0)).tag($0) }
                            }
                            .frame(width: 100)
                            Picker("분", selection: $minute) {
                                ForEach(0...59, id: \.self) { Text(String(format: "%02d분", $0)).tag($0) }
                            }
                            .frame(width: 100)
                        }
                        .labelsHidden()
                    } else {
                        Text("시주를 비운 삼주(三柱)로 계산합니다. 임의로 채우지 않습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("출생지") {
                    Picker("도시", selection: $cityIndex) {
                        ForEach(Self.cities.indices, id: \.self) { i in
                            Text(Self.cities[i].name).tag(i)
                        }
                    }
                    if Self.cities[cityIndex].longitude.isNaN {
                        TextField("경도 (동경, 도)", value: $customLongitude, format: .number.precision(.fractionLength(3)))
                    }
                }

                if let preview = previewChart {
                    Section("미리 보기") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(preview.compactHanja)
                                .font(.hanja(size: 22))
                            CorrectionSummary(chart: preview)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                if case .edit = mode {
                    Text("보정 방식은 설정의 유파 옵션을 따릅니다.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(saveLabel) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || previewChart == nil)
            }
            .padding(12)
        }
        .frame(width: 480, height: 620)
        .onAppear(perform: populate)
    }

    private var saveLabel: String {
        if case .edit = mode { return "저장" }
        return "추가"
    }

    private var currentInput: BirthInput {
        let city = Self.cities[cityIndex]
        let place = city.longitude.isNaN
            ? BirthPlace(name: "사용자 지정", longitude: customLongitude)
            : BirthPlace(name: city.name, longitude: city.longitude)
        return BirthInput(
            year: year, month: month, day: day,
            hour: knowsTime ? hour : nil,
            minute: knowsTime ? minute : 0,
            calendarType: isLunar ? .lunar(isLeapMonth: isLeapMonth) : .solar,
            gender: gender,
            place: place,
            options: appState.options
        )
    }

    private var previewChart: SajuChart? {
        try? PillarsEngine.chart(for: currentInput)
    }

    private func populate() {
        guard case .edit(let person) = mode else { return }
        name = person.name
        let b = person.birth
        year = b.year
        month = b.month
        day = b.day
        knowsTime = b.hour != nil
        hour = b.hour ?? 12
        minute = b.minute
        if case .lunar(let leap) = b.calendarType {
            isLunar = true
            isLeapMonth = leap
        }
        gender = b.gender
        if let i = Self.cities.firstIndex(where: { $0.name == b.place.name }) {
            cityIndex = i
        } else {
            cityIndex = Self.cities.count - 1
            customLongitude = b.place.longitude
        }
    }

    private func save() {
        switch mode {
        case .add:
            let person = Person(name: name, birth: currentInput)
            appState.store.add(person)
            appState.selectedPersonID = person.id
        case .edit(let original):
            var updated = original
            updated.name = name
            updated.birth = currentInput
            appState.store.update(updated)
        }
        dismiss()
    }
}

/// 적용된 보정 요약 라인 — 신뢰의 시각화.
struct CorrectionSummary: View {
    let chart: SajuChart

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if chart.input.hour != nil {
                HStack(spacing: 6) {
                    let c = chart.corrections
                    let solar = String(
                        format: "%02d:%02d",
                        c.solarTimeSecondsOfDay / 3600, (c.solarTimeSecondsOfDay % 3600) / 60
                    )
                    Text("진태양시 \(solar)")
                    if c.longitudeCorrectionMinutes != 0 {
                        Text("경도 \(Int(c.longitudeCorrectionMinutes.rounded()))분")
                            .foregroundStyle(.secondary)
                    }
                    if c.equationOfTimeMinutes != 0 {
                        Text("균시차 \(String(format: "%+.1f", c.equationOfTimeMinutes))분")
                            .foregroundStyle(.secondary)
                    }
                    if c.isDST {
                        Text("서머타임 −60분")
                            .foregroundStyle(Ink.cinnabar)
                    }
                    if chart.isNightJasi {
                        Text("야자시")
                            .foregroundStyle(Ink.cinnabar)
                    }
                }
                .font(.caption)
            }
            if let lunar = chart.lunarDate {
                Text("음력 \(lunar.description) · \(chart.governingJeol.korean) 절기 관할")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
