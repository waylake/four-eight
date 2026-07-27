import SwiftUI
import Charts
import SajuKit

/// 오행 분포 — 고정 순서(목화토금수) 수평 막대.
///
/// dataviz 규칙 적용: 엔티티 고정색, 얇은 마크, 직접 레이블(텍스트는
/// 텍스트 토큰), 은은한 그리드 없음, 범례 불필요(축 레이블이 정체성).
struct ElementChartView: View {
    let analysis: SajuAnalysis

    private var data: [(element: Element, count: Int)] {
        Element.allCases.map { ($0, analysis.elementCounts[$0] ?? 0) }
    }

    private var total: Int {
        data.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("오행 분포")
                .font(.headline)
            Chart(data, id: \.element) { item in
                BarMark(
                    x: .value("개수", item.count),
                    y: .value("오행", item.element.korean),
                    height: .fixed(16)
                )
                .foregroundStyle(Ink.element(item.element))
                .cornerRadius(3)
                .annotation(position: .trailing, alignment: .leading, spacing: 6) {
                    Text("\(item.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(item.count == 0 ? Color.secondary.opacity(0.5) : Color.secondary)
                }
            }
            .chartXAxis(.hidden)
            .chartXScale(domain: 0...max(4, data.map(\.count).max() ?? 4))
            .chartYAxis {
                AxisMarks(preset: .aligned) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self),
                           let element = Element.allCases.first(where: { $0.korean == label }) {
                            HStack(spacing: 4) {
                                Text(element.hanja)
                                    .font(.hanja(size: 13))
                                    .foregroundStyle(Ink.element(element))
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(height: 128)
            Text("\(total)자 기준 · 지지는 본기 오행")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
