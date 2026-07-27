import SwiftUI
import SajuKit

struct PeopleSidebar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        List(selection: $state.selectedPersonID) {
            Section("인물") {
                ForEach(appState.store.people) { person in
                    PersonRow(person: person)
                        .tag(person.id)
                        .contextMenu {
                            Button("편집…") { appState.editingPerson = person }
                            Divider()
                            Button("삭제", role: .destructive) {
                                appState.store.remove(person.id)
                                if appState.selectedPersonID == person.id {
                                    appState.selectedPersonID = appState.store.people.first?.id
                                }
                            }
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
                Spacer()
            }
            .padding(10)
        }
        .navigationTitle("FourEight")
    }
}

struct PersonRow: View {
    @Environment(AppState.self) private var appState
    let person: Person

    var body: some View {
        HStack(spacing: 10) {
            // 일간 한 글자 뱃지 — 그 사람의 정체성.
            if let dayMaster = try? SajuService.reading(for: person, options: appState.options).chart.dayMaster {
                Text(dayMaster.hanja)
                    .font(.hanja(size: 17))
                    .foregroundStyle(Ink.element(dayMaster.element))
                    .frame(width: 28, height: 28)
                    .background(Ink.wash(dayMaster.element), in: RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.body)
                Text(person.birthSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
