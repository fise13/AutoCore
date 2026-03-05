import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct AccountingView: View {
    @StateObject private var viewModel: AccountingViewModel
    @State private var isShowingAddExpense = false
    @State private var isShowingExport = false
    
    private let createExpenseUseCase: CreateExpenseOperationUseCase
    private let financialOperationRepository: FinancialOperationRepository
    let onSettings: () -> Void
    let onLogout: (() -> Void)?
    let currentUser: UserEntity?
    
    init(
        financialOperationRepository: FinancialOperationRepository,
        currentUser: String,
        recoveryState: RecoveryState?,
        onSettings: @escaping () -> Void,
        onLogout: (() -> Void)?,
        userEntity: UserEntity?
    ) {
        _viewModel = StateObject(wrappedValue: AccountingViewModel(financialOperationRepository: financialOperationRepository))
        self.financialOperationRepository = financialOperationRepository
        self.createExpenseUseCase = CreateExpenseOperationUseCase(
            financialOperationRepository: financialOperationRepository,
            recoveryState: recoveryState,
            currentUser: currentUser
        )
        self.onSettings = onSettings
        self.onLogout = onLogout
        self.currentUser = userEntity
    }
    
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Обзор
            if selectedTab == 0 {
                AccountingOverviewView(viewModel: viewModel)
            }
            // Касса
            else if selectedTab == 1 {
                CashboxView(viewModel: viewModel)
            }
            // Расходы
            else if selectedTab == 2 {
                ExpensesView(viewModel: viewModel)
            }
            // Операции
            else {
                OperationsView(viewModel: viewModel)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                Picker("Раздел", selection: $selectedTab) {
                    Text("Обзор").tag(0)
                    Text("Касса").tag(1)
                    Text("Расходы").tag(2)
                    Text("Операции").tag(3)
                }
                .pickerStyle(.segmented)
            }
            
            AccountingToolbar(
                searchText: viewModel.searchText,
                onSearchTextChange: { newText in
                    viewModel.searchText = newText
                    viewModel.refreshOperations()
                },
                onAddExpense: {
                    isShowingAddExpense = true
                },
                onExport: {
                    isShowingExport = true
                },
                onSettings: onSettings,
                onLogout: onLogout,
                currentUser: currentUser
            )
        }
        .sheet(isPresented: $isShowingAddExpense) {
            AddExpenseView(viewModel: viewModel, createExpenseUseCase: createExpenseUseCase)
        }
        .sheet(isPresented: $isShowingExport) {
            FinancialExportView(
                isPresented: $isShowingExport,
                onExport: { config in
                    performExport(config: config)
                }
            )
        }
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.refreshOperations()
        }
    }
    
    private func performExport(config: FinancialExportConfig) {
        Task {
            do {
                let exportService = FinancialExportService(financialOperationRepository: financialOperationRepository)
                
                // Выбираем файл для сохранения
                let savePanel = NSSavePanel()
                let fileExtension = config.format == .excel ? "xlsx" : "pdf"
                savePanel.allowedContentTypes = [config.format == .excel ? .init(filenameExtension: "xlsx")! : .pdf]
                savePanel.nameFieldStringValue = "Финансовый отчёт \(dateFormatter.string(from: Date())).\(fileExtension)"
                
                if savePanel.runModal() == .OK, let url = savePanel.url {
                    let fileURL: URL
                    if config.format == .excel {
                        fileURL = try await Task.detached {
                            try exportService.exportToExcel(config: config, to: url)
                        }.value
                    } else {
                        fileURL = try await Task.detached {
                            try exportService.exportToPDF(config: config, to: url)
                        }.value
                    }
                    
                    // Показываем уведомление об успехе
                    await MainActor.run {
                        NSWorkspace.shared.open(fileURL)
                    }
                }
            } catch {
                print("Ошибка экспорта: \(error)")
                // TODO: Показать alert с ошибкой
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }
}

struct AccountingOverviewView: View {
    @ObservedObject var viewModel: AccountingViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Карточки балансов
                HStack(spacing: 16) {
                    BalanceCard(
                        title: "Касса",
                        amount: viewModel.cashBalance,
                        color: .green
                    )
                    
                    BalanceCard(
                        title: "Каспи",
                        amount: viewModel.kaspiBalance,
                        color: .blue
                    )
                }
                .padding()
                
                // Сегодняшние продажи
                VStack(alignment: .leading, spacing: 8) {
                    Text("Сегодняшние продажи")
                        .font(.headline)
                    
                    Text(formatCurrency(viewModel.todaySales))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.currencySymbol = "₸"
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) ₸"
    }
}

struct BalanceCard: View {
    let title: String
    let amount: Decimal
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(formatCurrency(amount))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.currencySymbol = "₸"
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) ₸"
    }
}

struct CashboxView: View {
    @ObservedObject var viewModel: AccountingViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Баланс кассы
            HStack {
                Text("Текущий баланс кассы")
                    .font(.headline)
                Spacer()
                Text(formatCurrency(viewModel.cashBalance))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.green)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding()
            
            // Список операций по кассе
            List {
                ForEach(viewModel.operations.filter { $0.account == .cashbox }) { operation in
                    OperationRow(operation: operation)
                }
            }
        }
        .onAppear {
            viewModel.filterAccount = .cashbox
            viewModel.refreshOperations()
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.currencySymbol = "₸"
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) ₸"
    }
}

struct OperationsView: View {
    @ObservedObject var viewModel: AccountingViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Фильтры
            HStack {
                Picker("Тип", selection: $viewModel.filterType) {
                    Text("Все").tag(nil as FinancialOperationEntity.OperationType?)
                    Text("Продажа").tag(FinancialOperationEntity.OperationType.sale as FinancialOperationEntity.OperationType?)
                    Text("Возврат").tag(FinancialOperationEntity.OperationType.refund as FinancialOperationEntity.OperationType?)
                    Text("Расход").tag(FinancialOperationEntity.OperationType.expense as FinancialOperationEntity.OperationType?)
                }
                .frame(width: 150)
                
                Picker("Счёт", selection: $viewModel.filterAccount) {
                    Text("Все").tag(nil as FinancialOperationEntity.Account?)
                    Text("Касса").tag(FinancialOperationEntity.Account.cashbox as FinancialOperationEntity.Account?)
                    Text("Каспи").tag(FinancialOperationEntity.Account.kaspi as FinancialOperationEntity.Account?)
                }
                .frame(width: 150)
                
                Spacer()
            }
            .padding()
            
            // Список операций
            List {
                ForEach(viewModel.operations) { operation in
                    OperationRow(operation: operation)
                }
            }
        }
        .onChange(of: viewModel.filterType) { _, _ in
            viewModel.refreshOperations()
        }
        .onChange(of: viewModel.filterAccount) { _, _ in
            viewModel.refreshOperations()
        }
    }
}

struct ExpensesView: View {
    @ObservedObject var viewModel: AccountingViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Фильтры
            HStack {
                Picker("Счёт", selection: $viewModel.filterAccount) {
                    Text("Все").tag(nil as FinancialOperationEntity.Account?)
                    Text("Касса").tag(FinancialOperationEntity.Account.cashbox as FinancialOperationEntity.Account?)
                    Text("Каспи").tag(FinancialOperationEntity.Account.kaspi as FinancialOperationEntity.Account?)
                }
                .frame(width: 150)
                
                Spacer()
            }
            .padding()
            
            // Список расходов
            Table(viewModel.operations.filter { $0.type == .expense }) {
                TableColumn("Дата") { operation in
                    Text(formatDate(operation.createdAt))
                        .foregroundStyle(.secondary)
                }
                
                TableColumn("Сумма") { operation in
                    Text(formatCurrency(operation.amount))
                        .foregroundStyle(.red)
                        .fontWeight(.medium)
                }
                
                TableColumn("Счёт") { operation in
                    Text(operation.account == .cashbox ? "Касса" : "Каспи")
                        .foregroundStyle(.secondary)
                }
                
                TableColumn("Категория") { operation in
                    Text(operation.category ?? "—")
                        .foregroundStyle(.secondary)
                }
                
                TableColumn("Описание") { operation in
                    Text(operation.description)
                        .foregroundStyle(.primary)
                }
                
                TableColumn("Пользователь") { operation in
                    Text(operation.createdByUser)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        .onAppear {
            viewModel.filterType = .expense
            viewModel.refreshOperations()
        }
        .onChange(of: viewModel.filterAccount) { _, _ in
            viewModel.refreshOperations()
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.currencySymbol = "₸"
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) ₸"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct OperationRow: View {
    let operation: FinancialOperation
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(operationTypeName(operation.type))
                    .font(.headline)
                
                if !operation.description.isEmpty {
                    Text(operation.description)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                } else if !operation.source.isEmpty {
                    Text(operation.source)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                
                if let category = operation.category, !category.isEmpty {
                    Text(category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                }
                
                if !operation.details.isEmpty && operation.description != operation.details {
                    Text(operation.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(formatDate(operation.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if !operation.comment.isEmpty {
                    Text(operation.comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(operation.amount))
                    .font(.headline)
                    .foregroundStyle(operationTypeColor(operation.type))
                
                Text(operation.account == .cashbox ? "Касса" : "Каспи")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
    
    private func operationTypeColor(_ type: FinancialOperationEntity.OperationType) -> Color {
        switch type {
        case .sale, .income: return .green
        case .refund: return .orange
        case .expense: return .red
        case .transfer: return .blue
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.currencySymbol = "₸"
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) ₸"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
