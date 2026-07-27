import SwiftUI
import SajuKit

/// 메뉴바 — 오늘의 일진.
struct TodayMenuView: View {
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
        return candidates
            .filter { $0.1 > now }
            .min { $0.1 < $1.1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(spacing: 0) {
                    Text(today.stem.hanja)
                        .font(.hanja(size: 26))
                        .foregroundStyle(Ink.element(today.stem.element))
                    Text(today.branch.hanja)
                        .font(.hanja(size: 26))
                        .foregroundStyle(Ink.element(today.branch.element))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("오늘의 일진 — \(today.korean)일")
                        .font(.headline)
                    if let lunar = lunarToday {
                        Text("음력 \(lunar.description)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let next = nextTerm {
                        Text("\(next.term.korean)(\(next.term.hanja)) \(next.instant.formatted(.dateTime.month().day().hour().minute()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Divider()
            Text("\(today.branch.animal)의 날 · \(today.stem.element.korean)\(today.stem.yinYang.korean) 기운")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 280)
    }
}
