//
//  DashboardView.swift
//  AutoCore
//
//  Accounting dashboard - stats grid + analytics placeholder
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: AccountingViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.x3) {
                // Stats Grid (2 columns)
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: DSSpacing.x2),
                    GridItem(.flexible(), spacing: DSSpacing.x2)
                ], spacing: DSSpacing.x2) {
                    StatCard(
                        title: "Касса",
                        value: formatCurrency(viewModel.cashBalance),
                        valueColor: DSColors.positive
                    )
                    StatCard(
                        title: "Каспи",
                        value: formatCurrency(viewModel.kaspiBalance),
                        valueColor: DSColors.accent
                    )
                    StatCard(
                        title: "Сегодняшние продажи",
                        value: formatCurrency(viewModel.todaySales),
                        valueColor: DSColors.textPrimary
                    )
                }
                
                // Large analytics section placeholder
                SectionContainer {
                    VStack(spacing: DSSpacing.x2) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 40))
                            .foregroundColor(DSColors.textSecondary.opacity(0.6))
                        Text("Аналитика")
                            .font(DSTypography.sectionTitle)
                            .foregroundColor(DSColors.textSecondary)
                        Text("Секция аналитики будет добавлена позже")
                            .font(DSTypography.caption)
                            .foregroundColor(DSColors.textSecondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSSpacing.x5)
                }
            }
            .padding(DSSpacing.x3)
        }
        .background(DSColors.background)
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.currencySymbol = "₸"
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) ₸"
    }
}
