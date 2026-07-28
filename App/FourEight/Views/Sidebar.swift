import SwiftUI
import SajuKit

struct Sidebar: View {
    @Environment(AppState.self) private var appState
    @Environment(InterpretationStore.self) private var interpretations
    @Environment(ConsultationStore.self) private var consultations

    var body: some View {
        @Bindable var state = appState
        List(selection: $state.destination) {
            if appState.selectedPerson != nil {
                Section {
                    Label("오늘", systemImage: "sun.horizon")
                        .tag(Destination.today)
                    Label("캘린더", systemImage: "calendar")
                        .tag(Destination.calendar)
                    Label("명식", systemImage: "square.grid.2x2")
                        .tag(Destination.chart)
                    Label("상담", systemImage: "bubble.left.and.text.bubble.right")
                        .tag(Destination.consultation)
                }
            }

            Section("인물") {
                ForEach(appState.store.people) { person in
                    PersonRow(person: person, isSelected: person.id == appState.selectedPersonID)
                        .contentShape(Rectangle())
                        .onTapGesture { appState.select(person.id) }
                        .contextMenu {
                            Button("편집…") { appState.editingPerson = person }
                            Divider()
                            Button("삭제", role: .destructive) { remove(person) }
                        }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    appState.isAddingPerson = true
                } label: {
                    Label("새 인물", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .help("새 인물 추가 (⌘N)")
                Spacer()
            }
            .padding(10)
        }
        .navigationTitle("FourEight")
    }

    private func remove(_ person: Person) {
        appState.store.remove(person.id)
        // 사람을 지우면 그 사람에 대해 쓴 문장도 남을 이유가 없다.
        // 날짜별 풀이까지 접두사로 함께 지운다.
        interpretations.discard(subject: person.id.uuidString)
        consultations.discard(personID: person.id)
        if appState.selectedPersonID == person.id {
            appState.select(appState.store.people.first?.id)
        }
    }
}

struct PersonRow: View {
    @Environment(AppState.self) private var appState
    let person: Person
    let isSelected: Bool

    /// 사이드바 행마다 명식을 다시 계산하지 않도록 일간만 뽑아 둔다.
    private var dayMaster: Cheongan? {
        var input = person.birth
        input.options = appState.options
        return try? PillarsEngine.chart(for: input).dayMaster
    }

    var body: some View {
        HStack(spacing: 10) {
            if let dayMaster {
                Text(dayMaster.hanja)
                    .font(.hanja(size: 17))
                    .foregroundStyle(Ink.element(dayMaster.element))
                    .frame(width: 28, height: 28)
                    .background(Ink.wash(dayMaster.element), in: RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.body)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.primary))
                Text(person.birthSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Ink.cinnabar)
            }
        }
        .padding(.vertical, 2)
    }
}
