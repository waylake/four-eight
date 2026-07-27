import SwiftUI
import SajuKit

/// 오늘(또는 캘린더에서 고른 날)의 기운.
///
/// 이 화면은 날을 평가하지 않는다. 길일·흉일 같은 등급 대신 그날 어떤
/// 성격의 기운이 실리는지만 서술한다. 등급을 매기는 순간 공포 마케팅이
/// 되고, 근거 추적이라는 이 앱의 정체성과도 어긋난다.
struct TodayView: View {
    let reading: Reading
    @Environment(AppState.self) private var appState

    private var fortune: DayFortune {
        SajuService.fortune(on: appState.activeDate, reading: reading)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(fortune.date)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dayHeader
                cycleBand
                if !fortune.day.relations.isEmpty || fortune.day.isVoid || fortune.day.combinesDayMaster {
                    contactCard
                }
                TimeInterpretationPanel(reading: reading, fortune: fortune)
            }
            .padding(20)
        }
        .background(.background)
        .navigationTitle(isToday ? "오늘" : dateLabel)
        .navigationSubtitle(reading.person.name)
        .toolbar {
            if !isToday {
                ToolbarItem {
                    Button("오늘로") {
                        appState.selectedDate = nil
                    }
                    .help("오늘로 이동 (⌘T)")
                }
            }
        }
    }

    private var dateLabel: String {
        fortune.date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ko_KR")))
    }

    // MARK: - 일진

    private var dayHeader: some View {
        HStack(alignment: .top, spacing: 18) {
            // 일진 두 글자 — 이 화면의 주인공.
            VStack(spacing: 2) {
                Text(fortune.day.ganji.stem.hanja)
                    .font(.hanja(size: 52))
                    .foregroundStyle(Ink.element(fortune.day.ganji.stem.element))
                Text(fortune.day.ganji.branch.hanja)
                    .font(.hanja(size: 52))
                    .foregroundStyle(Ink.element(fortune.day.ganji.branch.element))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Ink.wash(fortune.day.ganji.stem.element),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("\(dateLabel) · \(fortune.day.ganji.korean)일")
                    .font(.title3.weight(.semibold))

                // 기운의 성격 — 등급이 아니라 종류.
                HStack(spacing: 6) {
                    Chip(text: "\(fortune.day.stemGod.korean)의 기운", tint: Ink.cinnabar)
                    Chip(text: fortune.day.stage.korean)
                    if fortune.day.isVoid {
                        Chip(text: "공망")
                    }
                    if fortune.day.combinesDayMaster {
                        Chip(text: "일간과 합")
                    }
                }

                Text("일간 \(reading.chart.dayMaster.korean)\(reading.chart.dayMaster.hanja) 기준 · 지지는 \(fortune.day.branchGod.korean)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard()
    }

    // MARK: - 대운·세운·월운

    private var cycleBand: some View {
        HStack(spacing: 10) {
            if let daeun = fortune.daeunPeriod {
                CycleTile(
                    label: "대운",
                    ganji: daeun.ganji,
                    god: TenGod.of(dayMaster: reading.chart.dayMaster, target: daeun.ganji.stem),
                    detail: "\(daeun.startAge)세~"
                )
            }
            CycleTile(
                label: "세운",
                ganji: fortune.year.ganji,
                god: fortune.year.stemGod,
                detail: fortune.year.label
            )
            CycleTile(
                label: "월운",
                ganji: fortune.month.ganji,
                god: fortune.month.stemGod,
                detail: fortune.month.label
            )
        }
    }

    // MARK: - 명식과 만나는 지점

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("명식과 만나는 지점")
                .font(.headline)
            FlowChips {
                ForEach(Array(fortune.day.relations.enumerated()), id: \.offset) { _, relation in
                    Chip(
                        text: "\(relation.display) · \(relation.position.rawValue)",
                        tint: relation.kind == .chung ? Ink.cinnabar : .secondary
                    )
                }
                if fortune.day.isVoid {
                    Chip(text: "일주 공망(\(reading.chart.dayPillar.voidBranches.map(\.korean).joined()))에 해당")
                }
                if fortune.day.combinesDayMaster {
                    Chip(text: "\(reading.chart.dayMaster.korean)\(fortune.day.ganji.stem.korean) 천간합")
                }
            }
            Text("충과 형은 좋고 나쁨이 아니라 움직임과 조정이 생기는 국면을 뜻합니다.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard()
    }
}

/// 대운·세운·월운 한 칸.
struct CycleTile: View {
    let label: String
    let ganji: Ganji
    let god: TenGod
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
            HStack(spacing: 8) {
                HStack(spacing: 1) {
                    Text(ganji.stem.hanja)
                        .foregroundStyle(Ink.element(ganji.stem.element))
                    Text(ganji.branch.hanja)
                        .foregroundStyle(Ink.element(ganji.branch.element))
                }
                .font(.hanja(size: 22))
                VStack(alignment: .leading, spacing: 1) {
                    Text(god.korean)
                        .font(.callout)
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 12)
    }
}
