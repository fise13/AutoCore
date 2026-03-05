import SwiftUI
import Charts

/// Расходы по категориям: fintech panel, rich segment colors
struct ExpenseBreakdownView: View {
    let items: [ExpenseCategoryItem]
    
    private static let colors: [Color] = [
        FintechColors.accent,
        FintechColors.positive,
        Color(red: 0.9, green: 0.6, blue: 0.2),
        Color(red: 0.7, green: 0.5, blue: 0.95),
        FintechColors.negative.opacity(0.9)
    ]
    
    var body: some View {
        FintechPanel(cornerRadius: 16, edgeGlowOpacity: 0.2) {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("Расходы по категориям")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(FintechColors.steelMuted)
                    .textCase(.uppercase)
                    .tracking(0.8)
                
                if items.isEmpty {
                    FintechEmptyBlock(icon: "chart.pie", message: "Нет расходов за период", height: 180)
                } else {
                    HStack(alignment: .top, spacing: Spacing.x3) {
                        Chart(items) { item in
                            SectorMark(
                                angle: .value("Сумма", item.amount),
                                innerRadius: .ratio(0.5),
                                angularInset: 1.5
                            )
                            .foregroundStyle(color(for: item))
                            .cornerRadius(4)
                        }
                        .frame(width: 160, height: 160)
                        
                        VStack(alignment: .leading, spacing: Spacing.unit) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                                HStack(spacing: Spacing.unit) {
                                    Circle()
                                        .fill(Self.colors[i % Self.colors.count])
                                        .frame(width: 8, height: 8)
                                    Text(item.category)
                                        .font(.caption)
                                        .foregroundStyle(FintechColors.steelMuted)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Spacer()
                                    Text(formatPercent(item.percent))
                                        .font(.caption)
                                        .foregroundStyle(FintechColors.steel)
                                    Text(formatCurrency(item.amount))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(FintechColors.negative)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private func color(for item: ExpenseCategoryItem) -> Color {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return FintechColors.steel }
        return Self.colors[i % Self.colors.count]
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "KZT"
        f.currencySymbol = "₸"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: value as NSDecimalNumber) ?? "\(value) ₸"
    }
    
    private func formatPercent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.multiplier = 1
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value / 100)) ?? "\(value)%"
    }
}
