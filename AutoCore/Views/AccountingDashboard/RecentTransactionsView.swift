import SwiftUI

/// Последние операции: fintech panel, semantic colors (positive/negative/steel)
struct RecentTransactionsView: View {
    let operations: [FinancialOperation]
    private static let sharedDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "ru_RU")
        return f
    }()
    private static let sharedCurrencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "KZT"
        f.currencySymbol = "₸"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()
    
    var body: some View {
        FintechPanel(cornerRadius: 16, edgeGlowOpacity: 0.2) {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("Последние операции")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(FintechColors.steelMuted)
                    .textCase(.uppercase)
                    .tracking(0.8)
                
                if operations.isEmpty {
                    FintechEmptyBlock(
                        icon: "arrow.left.arrow.right",
                        message: "Нет операций",
                        height: 120
                    )
                } else {
                    let recent = Array(operations.prefix(6))
                    VStack(spacing: 0) {
                        ForEach(Array(recent.enumerated()), id: \.element.id) { index, op in
                            OperationRow(operation: op)
                                .padding(.vertical, 8)
                            
                            if index != recent.indices.last {
                                Divider()
                                    .overlay(FintechColors.backgroundHighlight.opacity(0.35))
                                    .padding(.leading, 52)
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        Self.sharedDateFormatter.string(from: date)
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
        Self.sharedCurrencyFormatter.string(from: value as NSDecimalNumber) ?? "\(value) ₸"
    }
    
    // MARK: - Row
    
    private struct OperationRow: View {
        let operation: FinancialOperation
        
        private var iconName: String {
            switch operation.type {
            case .sale: return "arrow.up.right"
            case .income: return "plus"
            case .expense: return "minus"
            case .refund: return "arrow.uturn.backward"
            case .transfer: return "arrow.left.arrow.right"
            }
        }
        
        private var iconColor: Color {
            switch operation.type {
            case .sale, .income:
                return FintechColors.positive
            case .expense, .refund:
                return FintechColors.negative
            case .transfer:
                return FintechColors.steel
            }
        }
        
        private var amountColor: Color {
            switch operation.type {
            case .sale, .income:
                return FintechColors.positive
            case .expense, .refund:
                return FintechColors.negative
            case .transfer:
                return FintechColors.steel
            }
        }
        
        private var primaryDetailText: String? {
            if !operation.description.isEmpty { return operation.description }
            if !operation.details.isEmpty { return operation.details }
            if !operation.source.isEmpty { return operation.source }
            return nil
        }
        
        private var accountLabel: String {
            operation.account == .cashbox ? "Касса" : "Kaspi"
        }
        
        private var formattedDate: String {
            RecentTransactionsView.sharedDateFormatter.string(from: operation.createdAt)
        }
        
        private var formattedAmount: String {
            RecentTransactionsView.sharedCurrencyFormatter.string(from: operation.amount as NSDecimalNumber) ?? "\(operation.amount) ₸"
        }
        
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.16))
                        .frame(width: 34, height: 34)
                    Image(systemName: iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(typeLabel(operation.type))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.primary)
                        Text(accountLabel)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(FintechColors.backgroundHighlight.opacity(0.7))
                            )
                            .foregroundStyle(FintechColors.steel)
                    }
                    
                    if let text = primaryDetailText, !text.isEmpty {
                        Text(text)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                    }
                    
                    if let cat = operation.category, !cat.isEmpty {
                        Text(cat)
                            .font(.caption2)
                            .foregroundStyle(FintechColors.steel)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(FintechColors.backgroundElevated.opacity(0.85))
                            )
                    }
                    
                    HStack(spacing: 6) {
                        Text(formattedDate)
                            .font(.caption2)
                            .foregroundStyle(FintechColors.steelMuted)
                        if !operation.createdByUser.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(FintechColors.steelMuted)
                            Text(operation.createdByUser)
                                .font(.caption2)
                                .foregroundStyle(FintechColors.steelMuted)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer(minLength: 8)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formattedAmount)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(amountColor)
                    if !operation.comment.isEmpty {
                        Text(operation.comment)
                            .font(.caption2)
                            .foregroundStyle(FintechColors.steel)
                            .lineLimit(1)
                    }
                }
            }
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
    }
}
