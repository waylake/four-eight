import SwiftUI
import SajuKit

/// 메뉴바 — 오늘의 기운.
///
/// 인물이 선택되어 있으면 그 사람 기준으로 오늘을 읽고, 없으면 일진만
/// 보여준다. 앱을 열지 않고도 오늘을 확인하는 자리다.
struct TodayMenuView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    private var today: Ganji {
        PillarsEngine.dayGanji(on: Date(), timeZone: .current)
    }

    private var lunarToday: LunarDate? {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return KoreanLunarCalendar.lunar(fromSolarYear: c.year!, month: c.month!, day: c.day!)
    }

    private var nextTerm: (term: SolarTerm, instant: Date)? {
        let now = Date()
        let year = Calendar.current.component(.year, from: now)
        var candidates: [(SolarTerm, Date)] = []
        for y in [year, year + 1] {
            for term in SolarTerm.allCases {
                candidates.append((term, SolarTerms.instant(of: term, year: y)))
            }
        }
        return candidates.filter { $0.1 > now }.min { $0.1 < $1.1 }
    }

    private var fortune: DayFortune? {
        guard let reading = appState.reading else { return nil }
        return SajuService.fortune(on: Date(), reading: reading)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let fortune, let reading = appState.reading {
                Divider().padding(.vertical, 10)
                personalSection(fortune: fortune, reading: reading)
            }
            Divider().padding(.vertical, 10)
            footer
        }
        .padding(14)
        .frame(width: 296)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 11) {
            VStack(spacing: 0) {
                Text(today.stem.hanja)
                    .foregroundStyle(Ink.element(today.stem.element))
                Text(today.branch.hanja)
                    .foregroundStyle(Ink.element(today.branch.element))
            }
            .font(.hanja(size: 27))

            VStack(alignment: .leading, spacing: 3) {
                Text("오늘 \(today.korean)일")
                    .font(.headline)
                if let lunar = lunarToday {
                    Text("음력 \(lunar.description)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let next = nextTerm {
                    Text("\(next.term.korean) \(next.instant.formatted(.dateTime.month().day().hour().minute().locale(Locale(identifier: "ko_KR"))))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func personalSection(fortune: DayFortune, reading: Reading) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(reading.person.name)
                    .font(.callout.weight(.medium))
                Text("일간 \(reading.chart.dayMaster.korean)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 5) {
                Chip(text: "\(fortune.day.stemGod.korean)의 기운", tint: Ink.cinnabar)
                Chip(text: fortune.day.stage.korean)
                if fortune.day.isVoid { Chip(text: "공망") }
            }
            if !fortune.day.relations.isEmpty {
                Text("명식과 만남: " + fortune.day.relations.map(\.display).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("앱 열기") {
                appState.destination = .today
                appState.selectedDate = nil
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.borderless)
            Spacer()
            Text("\(today.branch.animal)의 날")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
