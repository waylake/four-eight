import SwiftUI
import SajuKit

/// 대운 타임라인 — 10년 단위 흐름, 현재 대운 강조.
struct DaeUnTimelineView: View {
    let reading: Reading

    private var currentAge: Int {
        FactExtractor.ageYears(chart: reading.chart, at: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("대운")
                    .font(.headline)
                if let daeun = reading.daeun {
                    Text(daeun.isForward ? "순행" : "역행")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("대운수 \(daeun.daeunSu)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("만 \(currentAge)세")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let daeun = reading.daeun {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(daeun.periods) { period in
                            let isCurrent = daeun.current(ageYears: currentAge)?.index == period.index
                            VStack(spacing: 4) {
                                Text("\(period.startAge)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                                VStack(spacing: 0) {
                                    Text(period.ganji.stem.hanja)
                                        .font(.hanja(size: 20))
                                        .foregroundStyle(Ink.element(period.ganji.stem.element))
                                    Text(period.ganji.branch.hanja)
                                        .font(.hanja(size: 20))
                                        .foregroundStyle(Ink.element(period.ganji.branch.element))
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    isCurrent ? AnyShapeStyle(Ink.cinnabar.opacity(0.12)) : AnyShapeStyle(.quaternary.opacity(0.4)),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(
                                            isCurrent ? Ink.cinnabar.opacity(0.6) : .clear,
                                            lineWidth: 1.2
                                        )
                                )
                                let god = TenGod.of(dayMaster: reading.chart.dayMaster, target: period.ganji.stem)
                                Text(god.korean)
                                    .font(.caption2)
                                    .foregroundStyle(isCurrent ? AnyShapeStyle(Ink.cinnabar) : AnyShapeStyle(.secondary))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
