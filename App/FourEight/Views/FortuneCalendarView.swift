import SwiftUI
import SajuKit

/// 운세 캘린더.
///
/// 밀집 격자에 오행 5색을 그대로 뿌리면 잡음이 된다. 주 신호는 하나로
/// 둔다 — 그날이 내 명식과 접점을 갖는가(충·합·형·공망). 오행은 얇은
/// 밑줄로 내려 부차 신호로 둔다.
///
/// 날에 등급을 매기지 않는 원칙은 여기서도 지킨다. 접점 표시는 "중요한
/// 날"이라는 뜻이지 "좋은 날"이나 "나쁜 날"이라는 뜻이 아니다.
struct FortuneCalendarView: View {
    let reading: Reading
    @Environment(AppState.self) private var appState

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    private var components: DateComponents {
        calendar.dateComponents([.year, .month], from: appState.visibleMonth)
    }

    private var grid: [DayReading] {
        TimeFortune.calendarGrid(
            year: components.year ?? 2026,
            month: components.month ?? 1,
            chart: reading.chart
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            monthBar
            Divider()
            // `HSplitView`가 아니라 `HStack`이다. 상담 화면과 같은 이유이며
            // 근거는 ADR 0013에 있다 — `HSplitView`는 자식이 적어 놓은
            // `minWidth`까지 눌러 주지 않아 창보다 큰 최소를 요구하고, 창은
            // 줄어드는 대신 **자른다.**
            HStack(spacing: 0) {
                calendarGrid
                    .frame(minWidth: 460, idealWidth: 600)
                Divider()
                // 상한을 둔다. 남는 폭은 격자가 가져가야 한다. 근거는
                // ContentView의 같은 주석에 있다.
                detailPane
                    .frame(minWidth: 300, idealWidth: 360, maxWidth: 420)
            }
        }
        .background(.background)
        .navigationTitle("캘린더")
        .navigationSubtitle(reading.person.name)
    }

    // MARK: - 월 이동과 주기 표시

    private var monthBar: some View {
        HStack(spacing: 14) {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.leftArrow, modifiers: [.command])

            Text(appState.visibleMonth.formatted(
                .dateTime.year().month(.wide).locale(Locale(identifier: "ko_KR"))
            ))
            .font(.title3.weight(.semibold))
            .frame(minWidth: 132)

            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.rightArrow, modifiers: [.command])

            Button("오늘") {
                appState.visibleMonth = Date()
                appState.selectedDate = nil
            }
            .buttonStyle(.borderless)
            .help("오늘로 이동 (⌘T)")

            Spacer()

            // 이 달을 관할하는 주기.
            let midMonth = calendar.date(
                from: DateComponents(year: components.year, month: components.month, day: 15)
            ) ?? Date()
            let fortune = SajuService.fortune(on: midMonth, reading: reading)
            HStack(spacing: 8) {
                periodBadge("월운", fortune.month.ganji, fortune.month.stemGod)
                periodBadge("세운", fortune.year.ganji, fortune.year.stemGod)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func periodBadge(_ label: String, _ ganji: Ganji, _ god: TenGod) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(ganji.hanja)
                .font(.hanja(size: 14))
                .foregroundStyle(Ink.element(ganji.stem.element))
            Text(god.korean)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.35), in: Capsule())
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: appState.visibleMonth) {
            appState.visibleMonth = next
        }
    }

    // MARK: - 격자

    private var calendarGrid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(["일", "월", "화", "수", "목", "금", "토"].enumerated()), id: \.offset) { index, name in
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(index == 0 ? AnyShapeStyle(Ink.cinnabar.opacity(0.8)) : AnyShapeStyle(.secondary))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)

            let rows = stride(from: 0, to: grid.count, by: 7).map { Array(grid[$0..<min($0 + 7, grid.count)]) }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week) { day in
                        DayCell(
                            day: day,
                            isCurrentMonth: calendar.component(.month, from: day.date) == components.month,
                            isToday: calendar.isDateInToday(day.date),
                            isSelected: calendar.isDate(day.date, inSameDayAs: appState.activeDate)
                        )
                        .onTapGesture {
                            appState.selectedDate = day.date
                        }
                    }
                }
                // 남는 공간을 나눠 갖되 무한히 벌어지지는 않게 한다.
                .frame(maxHeight: 84)
            }
            Spacer(minLength: 0)
            legend
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Ink.cinnabar)
                    .frame(width: 5, height: 5)
                Text("충·삼합·일간합이 닿는 날")
            }
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Ink.element(.wood))
                    .frame(width: 14, height: 2.5)
                Text("일진 천간의 오행")
            }
            Spacer()
            Text("접점은 중요도이지 길흉이 아닙니다")
                .foregroundStyle(.tertiary)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.top, 8)
    }

    // MARK: - 선택한 날

    private var detailPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                let fortune = SajuService.fortune(on: appState.activeDate, reading: reading)
                DayDetailHeader(fortune: fortune, chart: reading.chart)
                TimeInterpretationPanel(reading: reading, fortune: fortune)
            }
            .padding(16)
        }
    }
}

/// 격자 한 칸.
struct DayCell: View {
    let day: DayReading
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool

    /// 이 격자의 주 신호. 모든 접점을 표시하면 대부분의 날에 점이 찍혀
    /// 신호가 죽는다. 육합과 형은 흔하고 작용도 완만하므로 상세 패널로
    /// 내리고, 여기서는 충·삼합·일간합만 표시한다.
    private var hasContact: Bool {
        day.combinesDayMaster || day.relations.contains {
            $0.kind == .chung || $0.kind == .samhap
        }
    }

    private var dayNumber: Int {
        Calendar.current.component(.day, from: day.date)
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Text("\(dayNumber)")
                    .font(.system(size: 13, weight: isToday ? .bold : .regular).monospacedDigit())
                if hasContact {
                    Circle()
                        .fill(Ink.cinnabar)
                        .frame(width: 4, height: 4)
                }
            }
            Text(day.ganji.hanja)
                .font(.hanja(size: 14))
                .foregroundStyle(day.isVoid ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
            // 오행은 얇은 밑줄로. 부차 신호이므로 채도를 낮춘다.
            RoundedRectangle(cornerRadius: 1)
                .fill(Ink.element(day.ganji.stem.element))
                .frame(width: 18, height: 2.5)
                .opacity(isCurrentMonth ? 0.85 : 0.3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .opacity(isCurrentMonth ? 1 : 0.34)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Ink.cinnabar.opacity(0.11))
            }
        }
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Ink.cinnabar.opacity(0.6), lineWidth: 1.4)
            } else if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Ink.cinnabar.opacity(0.35), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
        .help(helpText)
    }

    private var helpText: String {
        var parts = ["\(day.ganji.korean)일 · \(day.stemGod.korean)"]
        if !day.relations.isEmpty {
            parts.append(day.relations.map(\.display).joined(separator: ", "))
        }
        if day.isVoid { parts.append("공망") }
        return parts.joined(separator: " · ")
    }
}

/// 선택한 날의 요약 머리.
struct DayDetailHeader: View {
    let fortune: DayFortune
    let chart: SajuChart

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 0) {
                    Text(fortune.day.ganji.stem.hanja)
                        .foregroundStyle(Ink.element(fortune.day.ganji.stem.element))
                    Text(fortune.day.ganji.branch.hanja)
                        .foregroundStyle(Ink.element(fortune.day.ganji.branch.element))
                }
                .font(.hanja(size: 30))

                VStack(alignment: .leading, spacing: 3) {
                    Text(fortune.date.formatted(
                        .dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ko_KR"))
                    ))
                    .font(.headline)
                    Text("\(fortune.day.ganji.korean)일 · \(fortune.day.stemGod.korean) · \(fortune.day.stage.korean)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            if !fortune.day.relations.isEmpty || fortune.day.isVoid || fortune.day.combinesDayMaster {
                FlowChips {
                    ForEach(Array(fortune.day.relations.enumerated()), id: \.offset) { _, relation in
                        Chip(
                            text: "\(relation.display) · \(relation.position.rawValue)",
                            tint: relation.kind == .chung ? Ink.cinnabar : .secondary
                        )
                    }
                    if fortune.day.isVoid { Chip(text: "공망") }
                    if fortune.day.combinesDayMaster { Chip(text: "일간과 합") }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 14)
    }
}
