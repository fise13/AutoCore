import SwiftUI
import Charts

/// Cash Flow chart: gradient fill, glow stroke, ambient grid fade. No default SwiftUI chart look.
struct CashFlowChartView: View {
    let data: [CashFlowDataPoint]
    
    var body: some View {
        FintechPanel(cornerRadius: 16, edgeGlowOpacity: 0.2) {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("Динамика Cash Flow")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(FintechColors.steelMuted)
                    .textCase(.uppercase)
                    .tracking(0.8)
                
                if data.isEmpty {
                    FintechEmptyBlock(icon: "chart.line.uptrend.xyaxis", message: "Нет данных за период", height: 200)
                } else {
                    Chart(data) { point in
                        LineMark(
                            x: .value("Дата", point.date),
                            y: .value("Чистый поток", point.net)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FintechColors.accent, FintechColors.accent.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        
                        AreaMark(
                            x: .value("Дата", point.date),
                            y: .value("Чистый поток", point.net)
                        )
                        .foregroundStyle(FintechGradients.chartFill)
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(FintechColors.steel.opacity(0.2))
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                .foregroundStyle(FintechColors.steel)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(FintechColors.steel.opacity(0.2))
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(formatShortCurrency(Decimal(v)))
                                        .foregroundStyle(FintechColors.steel)
                                } else {
                                    Text("")
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                }
            }
        }
    }
    
    private func formatShortCurrency(_ value: Decimal) -> String {
        let d = Double(truncating: value as NSDecimalNumber)
        if abs(d) >= 1_000_000 {
            return String(format: "%.1fM ₸", d / 1_000_000)
        }
        if abs(d) >= 1_000 {
            return String(format: "%.0fK ₸", d / 1_000)
        }
        return String(format: "%.0f ₸", d)
    }
}
