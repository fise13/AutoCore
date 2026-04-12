import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

struct AccountingView: View {
    #if os(macOS)
    static var controlBackgroundColor: Color { Color(NSColor.controlBackgroundColor) }
    #else
    static var controlBackgroundColor: Color { Color(UIColor.systemBackground) }
    #endif

    @StateObject private var viewModel: AccountingViewModel
    @State private var isShowingAddExpense = false
    @State private var isShowingExport = false
    @State private var operationToEdit: FinancialOperation?
    @State private var operationToDelete: FinancialOperation?
    @State private var showClearAccountingConfirm = false
    
    private let createExpenseUseCase: CreateExpenseOperationUseCase
    private let financialOperationRepository: FinancialOperationRepository
    let onSettings: () -> Void
    let onLogout: (() -> Void)?
    let currentUser: UserEntity?
    private let database: DatabaseService?
    private let syncCompanyId: String?
    
    init(
        financialOperationRepository: FinancialOperationRepository,
        currentUser: String,
        recoveryState: RecoveryState?,
        onSettings: @escaping () -> Void,
        onLogout: (() -> Void)?,
        userEntity: UserEntity?,
        database: DatabaseService? = nil,
        companyId: String? = nil
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
        self.database = database
        self.syncCompanyId = companyId
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
                CashboxView(viewModel: viewModel, onDeleteOperation: { operation in
                    viewModel.deleteOperation(operation)
                })
            }
            // Расходы
            else if selectedTab == 2 {
                ExpensesView(viewModel: viewModel, onDeleteOperation: { operation in
                    viewModel.deleteOperation(operation)
                })
            }
            // Операции
            else {
                OperationsView(viewModel: viewModel, onDeleteOperation: { operation in
                    viewModel.deleteOperation(operation)
                })
            }
            
            if let errorMessage = viewModel.errorMessage {
                Divider()
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
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

            if selectedTab == 3 {
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        operationToEdit = viewModel.selectedOperation()
                    } label: {
                        Label("Редактировать", systemImage: "pencil")
                    }
                    .disabled(viewModel.selectedOperation() == nil)

                    Button(role: .destructive) {
                        operationToDelete = viewModel.selectedOperation()
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                    .disabled(viewModel.selectedOperation() == nil)

                    Button(role: .destructive) {
                        showClearAccountingConfirm = true
                    } label: {
                        Label("Очистить бухгалтерию", systemImage: "trash.slash")
                    }
                }
            }
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
        .sheet(item: $operationToEdit) { operation in
            EditOperationSheet(operation: operation) { amount, account, category, description, comment in
                viewModel.updateOperation(
                    operation,
                    amount: amount,
                    account: account,
                    category: category,
                    description: description,
                    comment: comment
                )
                operationToEdit = nil
            }
        }
        .confirmationDialog(
            "Удалить операцию?",
            isPresented: Binding(
                get: { operationToDelete != nil },
                set: { if !$0 { operationToDelete = nil } }
            ),
            presenting: operationToDelete
        ) { operation in
            Button("Удалить", role: .destructive) {
                viewModel.deleteOperation(operation)
                operationToDelete = nil
            }
            Button("Отмена", role: .cancel) {
                operationToDelete = nil
            }
        } message: { operation in
            Text("Операция на сумму \(formatAmountForDialog(operation.amount)) будет удалена.")
        }
        .confirmationDialog("Очистить бухгалтерию?", isPresented: $showClearAccountingConfirm) {
            Button("Очистить", role: .destructive) {
                viewModel.deleteAllOperations(companyId: syncCompanyId)
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Будут удалены все операции бухгалтерии для текущей компании.")
        }
        #if os(macOS)
        .task(id: syncCompanyId) {
            guard let db = database, let cid = syncCompanyId, !cid.isEmpty else { return }
            let sync = FirestoreFinancialSyncService()
            let catalogSync = FirestoreCatalogSyncService()
            do {
                try await sync.pullAndMergeFinancialOperations(companyId: cid, database: db)
                await catalogSync.syncMotorSoldStatusesToLocal(companyId: cid, database: db)
                try await sync.pushLocalOperationsToFirestore(companyId: cid, database: db)
                await MainActor.run { viewModel.refreshAll() }
                NotificationCenter.default.post(name: .financialSyncMerged, object: nil)
            } catch {
                // начальная синхронизация не блокирует показ данных
            }
            for await entities in sync.observeOperations(companyId: cid) {
                guard !Task.isCancelled else { break }
                do {
                    try await sync.mergeEntitiesIntoDatabase(entities, companyId: cid, database: db)
                    await catalogSync.syncMotorSoldStatusesToLocal(companyId: cid, database: db)
                    await MainActor.run { viewModel.refreshAll() }
                    NotificationCenter.default.post(name: .financialSyncMerged, object: nil)
                } catch {
                    // observe merge не блокирует
                }
            }
        }
        #endif
    }
    
    private func performExport(config: FinancialExportConfig) {
        Task {
            do {
                let exportService = FinancialExportService(financialOperationRepository: financialOperationRepository)
                #if os(macOS)
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
                    await MainActor.run {
                        NSWorkspace.shared.open(fileURL)
                    }
                }
                #else
                let fileExtension = config.format == .excel ? "xlsx" : "pdf"
                let fileName = "Финансовый отчёт \(dateFormatter.string(from: Date())).\(fileExtension)"
                let tempDir = FileManager.default.temporaryDirectory
                let fileURL = tempDir.appendingPathComponent(fileName)
                if config.format == .excel {
                    _ = try await Task.detached {
                        try exportService.exportToExcel(config: config, to: fileURL)
                    }.value
                } else {
                    _ = try await Task.detached {
                        try exportService.exportToPDF(config: config, to: fileURL)
                    }.value
                }
                await MainActor.run {
                    isShowingExport = false
                    // iOS: файл сохранён во временную папку; можно показать share sheet через ExportSettingsView или оставить как есть
                }
                #endif
            } catch {
                print("Ошибка экспорта: \(error)")
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }

    private func formatAmountForDialog(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.currencySymbol = "₸"
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) ₸"
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
                .background(AccountingView.controlBackgroundColor)
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
        .background(AccountingView.controlBackgroundColor)
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
    let onDeleteOperation: (FinancialOperation) -> Void
    
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
            .background(AccountingView.controlBackgroundColor)
            .cornerRadius(8)
            .padding()
            
            // Список операций по кассе
            List {
                ForEach(viewModel.operations.filter { $0.account == .cashbox }) { operation in
                    OperationRow(operation: operation)
                        .contextMenu {
                            Button(role: .destructive) {
                                onDeleteOperation(operation)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                }
                .onDelete { offsets in
                    let cashOperations = viewModel.operations.filter { $0.account == .cashbox }
                    for index in offsets {
                        guard cashOperations.indices.contains(index) else { continue }
                        onDeleteOperation(cashOperations[index])
                    }
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
    let onDeleteOperation: (FinancialOperation) -> Void
    
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
                        .tag(operation.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedOperationID = operation.id
                        }
                        .contextMenu {
                            Button {
                                viewModel.selectedOperationID = operation.id
                            } label: {
                                Label("Выбрать", systemImage: "checkmark.circle")
                            }
                            Button(role: .destructive) {
                                onDeleteOperation(operation)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                }
                .onDelete { offsets in
                    for index in offsets {
                        guard viewModel.operations.indices.contains(index) else { continue }
                        onDeleteOperation(viewModel.operations[index])
                    }
                }
            }
            .listStyle(.inset)
        }
        .onAppear {
            viewModel.refreshOperations()
        }
        .onChange(of: viewModel.filterType) { _, _ in
            viewModel.refreshOperations()
        }
        .onChange(of: viewModel.filterAccount) { _, _ in
            viewModel.refreshOperations()
        }
    }
}

private struct EditOperationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let operation: FinancialOperation
    let onSave: (Decimal, FinancialOperationEntity.Account, String?, String, String) -> Void

    @State private var amount: String
    @State private var account: FinancialOperationEntity.Account
    @State private var category: String
    @State private var description: String
    @State private var comment: String

    init(
        operation: FinancialOperation,
        onSave: @escaping (Decimal, FinancialOperationEntity.Account, String?, String, String) -> Void
    ) {
        self.operation = operation
        self.onSave = onSave
        _amount = State(initialValue: NSDecimalNumber(decimal: operation.amount).stringValue)
        _account = State(initialValue: operation.account)
        _category = State(initialValue: operation.category ?? "")
        _description = State(initialValue: operation.description)
        _comment = State(initialValue: operation.comment)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Редактировать операцию")
                .font(.headline)

            TextField("Сумма", text: $amount)

            Picker("Счёт", selection: $account) {
                Text("Касса").tag(FinancialOperationEntity.Account.cashbox)
                Text("Каспи").tag(FinancialOperationEntity.Account.kaspi)
            }

            TextField("Категория (опционально)", text: $category)
            TextField("Описание", text: $description, axis: .vertical)
                .lineLimit(2...4)
            TextField("Комментарий", text: $comment, axis: .vertical)
                .lineLimit(2...4)

            HStack {
                Spacer()
                Button("Отмена") { dismiss() }
                Button("Сохранить") {
                    let parsedAmount = Decimal(string: amount) ?? operation.amount
                    onSave(
                        parsedAmount,
                        account,
                        category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category,
                        description,
                        comment
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled((Decimal(string: amount) ?? 0) <= 0 || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 420)
    }
}

struct ExpensesView: View {
    @ObservedObject var viewModel: AccountingViewModel
    let onDeleteOperation: (FinancialOperation) -> Void
    
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
            List {
                ForEach(viewModel.operations.filter { $0.type == .expense }) { operation in
                    OperationRow(operation: operation)
                        .contextMenu {
                            Button(role: .destructive) {
                                onDeleteOperation(operation)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                }
                .onDelete { offsets in
                    let expenseOperations = viewModel.operations.filter { $0.type == .expense }
                    for index in offsets {
                        guard expenseOperations.indices.contains(index) else { continue }
                        onDeleteOperation(expenseOperations[index])
                    }
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
                        .background(AccountingView.controlBackgroundColor)
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
        case .sale: return .green
        case .income: return .green
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
