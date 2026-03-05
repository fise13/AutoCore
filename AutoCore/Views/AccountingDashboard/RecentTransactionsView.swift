import SwiftUI

/// Последние операции: fintech panel, semantic colors (positive/negative/steel)
struct RecentTransactionsView: View {
    let operations: [FinancialOperation]
    
    var body: some View {
        FintechPanel(cornerRadius: 16, edgeGlowOpacity: 0.2) {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("Последние операции")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(FintechColors.steelMuted)
                    .textCase(.uppercase)
                    .tracking(0.8)
                
                if operations.isEmpty {
                    FintechEmptyBlock(icon: "arrow.left.arrow.right", message: "Нет операций", height: 120)
                } else {
                    Table(operations) {
                        TableColumn("Дата") { op in
                            Text(formatDate(op.createdAt))
                                .font(.caption)
                                .foregroundStyle(FintechColors.steel)
                        }
                        .width(min: 100, ideal: 120)
                        
                        TableColumn("Тип") { op in
                            Text(typeLabel(op.type))
                                .font(.caption)
                                .foregroundStyle(typeColor(op.type))
                        }
                        .width(min: 70, ideal: 90)
                        
                        TableColumn("Категория") { op in
                            Text(op.category ?? "—")
                                .font(.caption)
                                .foregroundStyle(FintechColors.steel)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .width(min: 80, ideal: 120)
                        
                        TableColumn("Сумма") { op in
                            Text(formatCurrency(op.amount))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(amountColor(op.type))
                        }
                        .width(min: 80, ideal: 100)
                    }
                    #if os(macOS)
                    .tableStyle(.bordered(alternatesRowBackgrounds: true))
                    #endif
                    .frame(maxHeight: 280)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: date)
    }
    
    private func typeLabel(_ type: FinancialOperationEntity.OperationType) -> String {
        switch type {
        case .sale: return "Продажа"
        case .refund: return "Возврат"
        case .expense: return "Расход"
        case .transfer: return "Перевод"
        case .income: return "Приход"
        }
    }
    
    private func typeColor(_ type: FinancialOperationEntity.OperationType) -> Color {
        switch type {
        case .sale: return FintechColors.positive
        case .refund: return FintechColors.negative
        case .expense: return FintechColors.negative
        case .transfer: return FintechColors.accent
        case .income: return FintechColors.positive
        }
    }
    
    private func amountColor(_ type: FinancialOperationEntity.OperationType) -> Color {
        switch type {
        case .sale: return FintechColors.positive
        case .refund: return FintechColors.negative
        case .expense: return FintechColors.negative
        case .transfer: return FintechColors.steel
        case .income: return FintechColors.positive
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
}
