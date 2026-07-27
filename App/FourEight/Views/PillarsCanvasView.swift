import SwiftUI
import SajuKit

/// 명식 캔버스 — 이 앱의 시그니처 화면.
struct PillarsCanvasView: View {
    let reading: Reading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                pillarsGrid
                HStack(alignment: .top, spacing: 14) {
                    ElementChartView(analysis: reading.analysis)
                        .paperCard()
                    strengthCard
                }
                if reading.daeun != nil {
                    DaeUnTimelineView(reading: reading)
                        .paperCard()
                }
                relationsCard
            }
            .padding(20)
        }
        .background(.background)
        .navigationTitle(reading.person.name)
        .navigationSubtitle(reading.person.birthSummary)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(reading.chart.compactHanja)
                    .font(.hanja(size: 26))
                Spacer()
                // 연도에 String()을 쓰는 이유: 한국어 로케일에서 Int를 그대로
                // 보간하면 "2,003년"처럼 천 단위 구분자가 붙는다.
                Text("\(String(reading.chart.sajuYear))년 기준 · \(reading.chart.monthPillar.branch.korean)월(\(reading.chart.governingJeol.korean))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            CorrectionSummary(chart: reading.chart)
        }
    }

    private var pillarsGrid: some View {
        // 전통 배치: 왼쪽부터 시·일·월·년.
        HStack(spacing: 10) {
            let order: [PillarPosition] = [.hour, .day, .month, .year]
            ForEach(order, id: \.self) { position in
                PillarColumn(reading: reading, position: position)
            }
        }
    }

    private var strengthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("일간 세력")
                .font(.headline)
            let ratio = reading.analysis.strengthRatio
            HStack(spacing: 8) {
                Text(reading.analysis.strength.rawValue)
                    .font(.title2.weight(.semibold))
                Text("\(Int((ratio * 100).rounded()))%")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Gauge(value: ratio) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinear)
            .tint(Ink.element(reading.chart.dayMaster.element))
            Text("월지·일지 가중 세력비 — 유파에 따라 판단이 다를 수 있습니다.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard()
    }

    @ViewBuilder
    private var relationsCard: some View {
        let relations = reading.analysis.relations
        let sinsal = reading.analysis.sinsalHits
        if !relations.isEmpty || !sinsal.isEmpty || !reading.analysis.voidPositions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("관계와 신살")
                    .font(.headline)
                FlowChips {
                    ForEach(Array(relations.enumerated()), id: \.offset) { _, r in
                        Chip(text: r.display, tint: .secondary)
                    }
                    ForEach(Array(sinsal.enumerated()), id: \.offset) { _, s in
                        Chip(text: "\(s.sinsal.rawValue)(\(s.position.rawValue))", tint: Ink.cinnabar)
                    }
                    if !reading.analysis.voidPositions.isEmpty {
                        let positions = reading.analysis.voidPositions.map(\.rawValue).joined(separator: "·")
                        Chip(text: "공망 \(positions)", tint: .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .paperCard()
        }
    }
}

/// 한 기둥 — 십신 눈썹, 천간·지지 활자 블록, 지장간, 운성.
struct PillarColumn: View {
    let reading: Reading
    let position: PillarPosition

    var body: some View {
        VStack(spacing: 8) {
            Text(position.rawValue)
                .font(.caption)
                .foregroundStyle(.tertiary)

            if let ganji = reading.chart.pillar(at: position) {
                // 천간 십신 눈썹.
                eyebrow(reading.chart.tenGod(at: position, stem: true)?.korean ?? "일간")
                GlyphBlock(
                    hanja: ganji.stem.hanja,
                    korean: "\(ganji.stem.korean)\(ganji.stem.element.korean)",
                    element: ganji.stem.element,
                    emphasized: position == .day
                )
                GlyphBlock(
                    hanja: ganji.branch.hanja,
                    korean: "\(ganji.branch.korean)\(ganji.branch.element.korean)",
                    element: ganji.branch.element,
                    emphasized: false
                )
                eyebrow(reading.chart.tenGod(at: position, stem: false)?.korean ?? "")

                // 지장간.
                HStack(spacing: 3) {
                    ForEach(ganji.branch.hiddenStems, id: \.self) { stem in
                        Text(stem.hanja)
                            .font(.hanja(size: 11))
                            .foregroundStyle(Ink.element(stem.element))
                    }
                }
                .help("지장간 — 여기·중기·정기")

                if let stage = reading.chart.twelveStage(at: position) {
                    Text(stage.korean)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                emptyHourColumn
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(Ink.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    position == .day ? AnyShapeStyle(Ink.cinnabar.opacity(0.55)) : AnyShapeStyle(.separator.opacity(0.5)),
                    lineWidth: position == .day ? 1.5 : 1
                )
        )
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(.caption2)
            .foregroundStyle(position == .day && text == "일간" ? AnyShapeStyle(Ink.cinnabar) : AnyShapeStyle(.secondary))
    }

    private var emptyHourColumn: some View {
        VStack(spacing: 10) {
            Text("미상")
                .font(.caption)
                .foregroundStyle(.tertiary)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.quaternary)
                .frame(height: 148)
                .overlay {
                    Text("시주 없음")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
        }
        .padding(.top, 14)
    }
}

/// 간지 한 글자 활자 블록.
struct GlyphBlock: View {
    let hanja: String
    let korean: String
    let element: Element
    let emphasized: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(hanja)
                .font(.hanja(size: 44))
                .foregroundStyle(Ink.element(element))
            Text(korean)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Ink.wash(element), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// 단순 칩.
struct Chip: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary.opacity(0.5), in: Capsule())
            .foregroundStyle(tint)
    }
}

/// 줄바꿈되는 칩 나열.
struct FlowChips<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        // macOS 15+: 간단한 flow 레이아웃.
        FlowLayout(spacing: 6) { content }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
