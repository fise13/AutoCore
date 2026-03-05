import SwiftUI

/// KPI blocks: fintech framed stat modules with glow edge and micro gradient
struct FinanceKPIView: View {
    let kpis: DashboardKPIs?
    let period: DashboardPeriod
    let onPeriodChange: (DashboardPeriod) -> Void
    
    var body: some View {
        FintechPanel(cornerRadius: 16, edgeGlowOpacity: 0.25) {
            VStack(alignment: .leading, spacing: Spacing.x3) {
                HStack {
                    Text("Ключевые показатели")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(FintechColors.steelMuted)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer()
                    Picker("Период", selection: Binding(
                        get: { period },
                        set: { onPeriodChange($0) }
                    )) {
                        ForEach(DashboardPeriod.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 320)
                }
                
                if let kpis = kpis {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: Spacing.x2),
                        GridItem(.flexible(), spacing: Spacing.x2),
                        GridItem(.flexible(), spacing: Spacing.x2),
                        GridItem(.flexible(), spacing: Spacing.x2)
                    ], spacing: Spacing.x2) {
                        FintechKPIBlock(
                            title: "Доходы",
                            value: formatCurrency(kpis.income),
                            subtitle: kpis.incomeChangePercent.map { formatPercent($0) },
                            accent: .positive
                        )
                        FintechKPIBlock(
                            title: "Расходы",
                            value: formatCurrency(kpis.expenses),
                            subtitle: kpis.expensesChangePercent.map { formatPercent($0) },
                            accent: .negative
                        )
                        FintechKPIBlock(
                            title: "Чистая прибыль",
                            value: formatCurrency(kpis.netProfit),
                            subtitle: kpis.netProfitChangePercent.map { formatPercent($0) },
                            accent: kpis.netProfit >= 0 ? .positive : .negative
                        )
                        FintechKPIBlock(
                            title: "Операций",
                            value: "\(kpis.operationCount)",
                            subtitle: kpis.operationCountChangePercent.map { formatPercent($0) },
                            accent: .accent
                        )
                    }
                } else {
                    VStack(spacing: Spacing.x2) {
                        ProgressView()
                            .scaleEffect(0.9)
                            .tint(FintechColors.accent)
                        Text("Загрузка…")
                            .font(.caption)
                            .foregroundStyle(FintechColors.steel)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.x3)
                }
            }
        }
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
        formatter.positivePrefix = "+"
        return formatter.string(from: NSNumber(value: value / 100)) ?? "\(value)%"
    }
}
