//
//  IOSAccountingTabView.swift
//  AutoCore
//
//  Бухгалтерия на iPhone. Только iOS, данные из БД через AccountingViewModel.
//
import SwiftUI

#if os(iOS)

struct IOSAccountingTabView: View {
    let database: DatabaseService
    
    @StateObject private var viewModel: AccountingViewModel
    
    init(database: DatabaseService) {
        self.database = database
        let repo = FinancialOperationRepositoryImpl(database: database)
        _viewModel = StateObject(wrappedValue: AccountingViewModel(financialOperationRepository: repo))
    }
    
    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        f.groupingSeparator = " "
        return f
    }()
    
    var body: some View {
        NavigationStack {
            List {
                Section("Балансы") {
                    HStack {
                        Label("Касса", systemImage: "banknote")
                        Spacer()
                        Text(currencyFormatter.string(from: viewModel.cashBalance as NSDecimalNumber) ?? "0")
                            .fontWeight(.medium)
                    }
                    HStack {
                        Label("Kaspi", systemImage: "creditcard")
                        Spacer()
                        Text(currencyFormatter.string(from: viewModel.kaspiBalance as NSDecimalNumber) ?? "0")
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("Продажи сегодня")
                        Spacer()
                        Text(currencyFormatter.string(from: viewModel.todaySales as NSDecimalNumber) ?? "0")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Последние операции") {
                    if viewModel.isLoading && viewModel.operations.isEmpty {
                        VStack(spacing: Spacing.x2) {
                            ProgressView()
                                .tint(FintechColors.accent)
                            Text("Загрузка…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.x3)
                    } else if viewModel.operations.isEmpty {
                        VStack(spacing: Spacing.unit) {
                            Image(systemName: "tray")
                                .font(.system(size: 24))
                                .foregroundStyle(FintechColors.steel.opacity(0.8))
                            Text("Нет операций")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.x2)
                    } else {
                        ForEach(viewModel.operations.prefix(50)) { op in
                            IOSOperationRow(operation: op)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                viewModel.refreshAll()
            }
            .navigationTitle("Бухгалтерия")
            .onAppear {
                viewModel.refreshAll()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private func operationTypeName(_ type: FinancialOperationEntity.OperationType) -> String {
    switch type {
    case .sale: return "Продажа"
    case .income: return "Приход"
    case .refund: return "Возврат"
    case .expense: return "Расход"
    case .transfer: return "Перевод"
    }
}

private struct IOSOperationRow: View {
    let operation: FinancialOperation
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "ru_RU")
        return f
    }()
    
    private let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()
    
    private var amountColor: Color {
        switch operation.type {
        case .sale, .income:
            return .green
        case .expense, .refund:
            return .red
        case .transfer:
            return .secondary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(operationTypeName(operation.type))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(amountFormatter.string(from: operation.amount as NSDecimalNumber) ?? "")
                    .foregroundStyle(amountColor)
            }
            Text(dateFormatter.string(from: operation.createdAt))
                .font(.caption)
                .foregroundStyle(.secondary)
            if !operation.comment.isEmpty {
                Text(operation.comment)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

#endif
