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
    @State private var isShowingAddOperation = false
    @State private var isShowingExport = false
    @State private var isShowingAnalysis = false
    @State private var isShowingAccountingSetup = false
    @State private var operationToEdit: FinancialOperation?
    @State private var operationToDelete: FinancialOperation?
    @State private var showClearAccountingConfirm = false
    
    private let financialOperationRepository: FinancialOperationRepository
    private let currentUserLogin: String
    private let settingsService: SettingsService?
    let onSettings: () -> Void
    let onAccountSettings: (() -> Void)?
    let onLogout: (() -> Void)?
    let currentUser: UserEntity?
    private let database: DatabaseService?
    private let syncCompanyId: String?
    
    init(
        financialOperationRepository: FinancialOperationRepository,
        settingsService: SettingsService? = nil,
        currentUser: String,
        recoveryState: RecoveryState?,
        onSettings: @escaping () -> Void,
        onAccountSettings: (() -> Void)? = nil,
        onLogout: (() -> Void)?,
        userEntity: UserEntity?,
        database: DatabaseService? = nil,
        companyId: String? = nil
    ) {
        _viewModel = StateObject(wrappedValue: AccountingViewModel(financialOperationRepository: financialOperationRepository))
        self.financialOperationRepository = financialOperationRepository
        self.currentUserLogin = currentUser
        self.settingsService = settingsService
        self.onSettings = onSettings
        self.onAccountSettings = onAccountSettings
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
            else if selectedTab == 3 {
                OperationsView(viewModel: viewModel, onDeleteOperation: { operation in
                    viewModel.deleteOperation(operation)
                })
            } else {
                AdvancesDetailsView(viewModel: viewModel, onDeleteOperation: { operation in
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
            AccountingToolbar(
                selectedTab: selectedTab,
                onSelectedTabChange: { selectedTab = $0 },
                searchText: viewModel.searchText,
                onSearchTextChange: { newText in
                    viewModel.searchText = newText
                    viewModel.refreshOperations()
                },
                onAddOperation: {
                    isShowingAddOperation = true
                },
                onExport: {
                    isShowingExport = true
                },
                onAnalyze: {
                    isShowingAnalysis = true
                },
                onSettings: onSettings,
                onAccountSettings: onAccountSettings ?? onSettings,
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
        .sheet(isPresented: $isShowingAddOperation) {
            AddFinancialOperationView(
                viewModel: viewModel,
                defaultCreatedByUser: currentUserLogin
            )
        }
        .sheet(isPresented: $isShowingAccountingSetup) {
            AccountingInitialSetupSheet(settingsService: settingsService)
        }
        .sheet(isPresented: $isShowingExport) {
            FinancialExportView(
                isPresented: $isShowingExport,
                onExport: { config in
                    performExport(config: config)
                }
            )
        }
        .sheet(isPresented: $isShowingAnalysis) {
            AccountingAnalysisView()
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
        .onAppear {
            if let settingsService, settingsService.settings.accounting.isConfigured == false {
                isShowingAccountingSetup = true
            }
        }
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

private struct AccountingInitialSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let settingsService: SettingsService?
    @State private var employeesText: String = ""
    @State private var specificsText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Сотрудники") {
                    Text("Укажите через запятую или с новой строки.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $employeesText)
                        .frame(minHeight: 120)
                }
                Section("Специфика бухгалтерии") {
                    Text("Например: аванс, логистика, поставщики, зарплата.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $specificsText)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Первичная настройка бухгалтерии")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Позже") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard let settingsService else { return }
                let accounting = settingsService.settings.accounting
                employeesText = accounting.employees.joined(separator: "\n")
                specificsText = accounting.specifics.joined(separator: "\n")
            }
        }
        .frame(minWidth: 560, minHeight: 520)
    }

    private func save() {
        guard let settingsService else { return }
        let employees = parseList(employeesText)
        let specifics = parseList(specificsText)
        var accounting = settingsService.settings.accounting
        accounting.employees = employees
        accounting.specifics = specifics
        accounting.isConfigured = true
        settingsService.updateAccounting(accounting)
    }

    private func parseList(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",;\n")
        let values = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var uniq: [String] = []
        for item in values {
            if !uniq.contains(where: { $0.caseInsensitiveCompare(item) == .orderedSame }) {
                uniq.append(item)
            }
        }
        return uniq
    }
}

struct AccountingOverviewView: View {
    @ObservedObject var viewModel: AccountingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
#if os(macOS)
                AccountingOverviewAppKitHeader(
                    cashBalance: formatCurrency(viewModel.cashBalance),
                    kaspiBalance: formatCurrency(viewModel.kaspiBalance),
                    salesToday: formatCurrency(viewModel.todaySales)
                )
                .frame(height: 170)
                .padding(.horizontal)
#else
                // ── Балансы ──────────────────────────────────────────────
                HStack(spacing: 16) {
                    BalanceCard(title: "Касса",  amount: viewModel.cashBalance,  color: .green)
                    BalanceCard(title: "Каспи",  amount: viewModel.kaspiBalance, color: .blue)
                }
                .padding(.horizontal)

                // ── Сегодняшние продажи ──────────────────────────────────
                OverviewMetricCard(
                    title: "Сегодняшние продажи",
                    value: formatCurrency(viewModel.todaySales),
                    icon: "cart.fill",
                    color: Color.accentColor
                )
                .padding(.horizontal)
#endif

                // ── Авансы ───────────────────────────────────────────────
                AdvancesOverviewCard(viewModel: viewModel)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencyCode = "KZT"; f.currencySymbol = "₸"
        return f.string(from: amount as NSDecimalNumber) ?? "\(amount) ₸"
    }
}

#if os(macOS)
private struct AccountingOverviewAppKitHeader: NSViewRepresentable {
    let cashBalance: String
    let kaspiBalance: String
    let salesToday: String

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.88).cgColor

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        stack.addArrangedSubview(metricCard(title: "Касса", value: cashBalance, tint: .systemGreen))
        stack.addArrangedSubview(metricCard(title: "Каспи", value: kaspiBalance, tint: .systemBlue))
        stack.addArrangedSubview(metricCard(title: "Продажи сегодня", value: salesToday, tint: .controlAccentColor))

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let stack = nsView.subviews.first(where: { $0 is NSStackView }) as? NSStackView else { return }
        updateMetricView(stack, index: 0, value: cashBalance)
        updateMetricView(stack, index: 1, value: kaspiBalance)
        updateMetricView(stack, index: 2, value: salesToday)
    }

    private func metricCard(title: String, value: String, tint: NSColor) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 10
        card.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = .systemFont(ofSize: 22, weight: .bold)
        valueLabel.textColor = tint
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(titleLabel)
        card.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),

            valueLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            valueLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])

        return card
    }

    private func updateMetricView(_ stack: NSStackView, index: Int, value: String) {
        guard stack.arrangedSubviews.indices.contains(index) else { return }
        let card = stack.arrangedSubviews[index]
        guard let valueLabel = card.subviews.compactMap({ $0 as? NSTextField }).last else { return }
        if valueLabel.stringValue != value {
            valueLabel.stringValue = value
        }
    }
}
#endif

/// Card showing the three advance totals (received / paid / balance).
struct AdvancesOverviewCard: View {
    @ObservedObject var viewModel: AccountingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Авансы", systemImage: "banknote.fill")
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 0) {
                advanceMetric(
                    title: "Получено",
                    amount: viewModel.advancesReceived,
                    color: .green
                )
                Divider().frame(height: 40)
                advanceMetric(
                    title: "Выдано",
                    amount: viewModel.advancesPaid,
                    color: .orange
                )
                Divider().frame(height: 40)
                advanceMetric(
                    title: "Баланс",
                    amount: viewModel.advancesBalance,
                    color: viewModel.advancesBalance >= 0 ? .green : .red
                )
            }

            Divider()

            HStack(spacing: 12) {
                miniStat(
                    title: "Операций",
                    value: "\(viewModel.advanceInsights.totalAdvanceOperations)"
                )
                miniStat(
                    title: "Людей (получено)",
                    value: "\(viewModel.advanceInsights.uniqueReceivedParties)"
                )
                miniStat(
                    title: "Людей (выдано)",
                    value: "\(viewModel.advanceInsights.uniquePaidParties)"
                )
            }

            HStack(spacing: 12) {
                miniStat(
                    title: "Средний входящий",
                    value: formatCurrency(viewModel.advanceInsights.averageReceived)
                )
                miniStat(
                    title: "Средний исходящий",
                    value: formatCurrency(viewModel.advanceInsights.averagePaid)
                )
            }

            if !viewModel.advanceInsights.topReceived.isEmpty || !viewModel.advanceInsights.topPaid.isEmpty {
                Divider()

                HStack(alignment: .top, spacing: 16) {
                    partyTopList(
                        title: "Топ получателей/клиентов",
                        items: viewModel.advanceInsights.topReceived,
                        color: .green
                    )
                    partyTopList(
                        title: "Топ выданных авансов",
                        items: viewModel.advanceInsights.topPaid,
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(AccountingView.controlBackgroundColor)
        .cornerRadius(10)
    }

    private func miniStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }

    private func partyTopList(
        title: String,
        items: [AccountingViewModel.AdvancePartyStat],
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(items.prefix(5)) { item in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text("\(item.operationsCount) оп.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatCurrency(item.totalAmount))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func advanceMetric(title: String, amount: Decimal, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formatCurrency(amount))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencyCode = "KZT"; f.currencySymbol = "₸"
        f.maximumFractionDigits = 0
        return f.string(from: amount as NSDecimalNumber) ?? "\(amount) ₸"
    }
}

private struct AdvancesDetailsView: View {
    @ObservedObject var viewModel: AccountingViewModel
    let onDeleteOperation: (FinancialOperation) -> Void
    @State private var direction: AccountingViewModel.AdvanceDirection = .all

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Тип аванса", selection: $direction) {
                    ForEach(AccountingViewModel.AdvanceDirection.allCases) { d in
                        Text(d.rawValue).tag(d)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)

                Text("Показываются операции, где в описании/категории/комментарии есть признаки аванса.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            List {
                ForEach(viewModel.advanceOperations(direction: direction)) { operation in
                    OperationRow(operation: operation)
                        .contextMenu {
                            Button(role: .destructive) {
                                onDeleteOperation(operation)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.inset)
        }
        .onAppear {
            viewModel.refreshAll()
        }
    }
}

/// Generic one-metric card used in the overview.
private struct OverviewMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding()
        .background(AccountingView.controlBackgroundColor)
        .cornerRadius(10)
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
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Касса")
                        .font(.headline)
                    Text("Текущий баланс")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(formatCurrency(viewModel.cashBalance))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.green)
            }
            .padding()
            .background(AccountingView.controlBackgroundColor)
            .cornerRadius(8)
            .padding(.horizontal)

            HStack(spacing: 12) {
                metricCard(title: "Операций", value: "\(viewModel.operations.filter { $0.account == .cashbox }.count)", color: .blue)
                metricCard(
                    title: "Сегодня",
                    value: formatCurrency(viewModel.operations.filter {
                        $0.account == .cashbox && Calendar.current.isDateInToday($0.createdAt)
                    }.reduce(Decimal.zero) { $0 + $1.amount }),
                    color: .purple
                )
            }
            .padding(.horizontal)
            
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

    private func metricCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AccountingView.controlBackgroundColor)
        .cornerRadius(8)
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

            HStack(spacing: 10) {
                quickChip(title: "Всего", value: "\(viewModel.operations.count)", color: .secondary)
                quickChip(
                    title: "Приход",
                    value: "\(viewModel.operations.filter { $0.type == .income || $0.type == .sale }.count)",
                    color: .green
                )
                quickChip(
                    title: "Расход",
                    value: "\(viewModel.operations.filter { $0.type == .expense || $0.type == .refund }.count)",
                    color: .red
                )
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            
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

    private func quickChip(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.caption.bold()).foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AccountingView.controlBackgroundColor)
        .cornerRadius(8)
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

private struct AddFinancialOperationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AccountingViewModel
    let defaultCreatedByUser: String

    @State private var type: FinancialOperationEntity.OperationType = .expense
    @State private var amount: String = ""
    @State private var account: FinancialOperationEntity.Account = .cashbox
    @State private var paymentMethod: FinancialOperationEntity.PaymentMethod = .cash
    @State private var category: String = ""
    @State private var description: String = ""
    @State private var comment: String = ""
    @State private var markAsAdvance = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Тип операции")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Тип", selection: $type) {
                                Text("Расход").tag(FinancialOperationEntity.OperationType.expense)
                                Text("Приход").tag(FinancialOperationEntity.OperationType.income)
                                Text("Возврат").tag(FinancialOperationEntity.OperationType.refund)
                                Text("Перевод").tag(FinancialOperationEntity.OperationType.transfer)
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Сумма")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                TextField("0", text: $amount)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 30, weight: .semibold))
                                Text("₸")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Счёт и способ оплаты")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Счёт", selection: $account) {
                                Text("Касса").tag(FinancialOperationEntity.Account.cashbox)
                                Text("Каспи").tag(FinancialOperationEntity.Account.kaspi)
                            }
                            .pickerStyle(.segmented)
                            Picker("Способ", selection: $paymentMethod) {
                                Text("Наличные").tag(FinancialOperationEntity.PaymentMethod.cash)
                                Text("Перевод").tag(FinancialOperationEntity.PaymentMethod.transfer)
                                Text("Смешанный").tag(FinancialOperationEntity.PaymentMethod.mixed)
                            }
                            .pickerStyle(.segmented)
                            .disabled(type == .transfer)
                        }
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Детали")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Категория (опционально)", text: $category)
                                .textFieldStyle(.roundedBorder)
                            TextField("Описание", text: $description, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.roundedBorder)
                            Toggle("Пометить как аванс", isOn: $markAsAdvance)
                                .toggleStyle(.switch)
                            TextField("Комментарий", text: $comment, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    if let errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.caption)
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(8)
                    }

                    HStack {
                        Spacer()
                        Button("Отмена") { dismiss() }
                        Button("Сохранить") { createOperation() }
                            .buttonStyle(.borderedProminent)
                            .disabled(!isValid)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Новая операция")
            .onChange(of: type) { _, newType in
                if newType == .transfer {
                    paymentMethod = .transfer
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 560)
    }

    private var isValid: Bool {
        guard let amountValue = Decimal(string: amount), amountValue > 0 else { return false }
        return !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func createOperation() {
        guard let amountValue = Decimal(string: amount), amountValue > 0 else {
            errorMessage = "Введите корректную сумму"
            return
        }
        let baseDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseDescription.isEmpty else {
            errorMessage = "Описание обязательно"
            return
        }

        let finalDescription = markAsAdvance && !baseDescription.lowercased().contains("аванс")
            ? "Аванс: \(baseDescription)"
            : baseDescription
        let finalComment = markAsAdvance && !comment.lowercased().contains("аванс")
            ? [comment.trimmingCharacters(in: .whitespacesAndNewlines), "аванс"]
                .filter { !$0.isEmpty }
                .joined(separator: " • ")
            : comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCategory = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : category.trimmingCharacters(in: .whitespacesAndNewlines)

        viewModel.createManualOperation(
            type: type,
            amount: amountValue,
            account: account,
            paymentMethod: type == .transfer ? .transfer : paymentMethod,
            category: finalCategory,
            description: finalDescription,
            comment: finalComment,
            source: sourceTitle(for: type),
            createdByUser: defaultCreatedByUser
        )
        dismiss()
    }

    private func sourceTitle(for type: FinancialOperationEntity.OperationType) -> String {
        switch type {
        case .expense: return "Ручной расход"
        case .income: return "Ручной приход"
        case .refund: return "Ручной возврат"
        case .sale: return "Ручная продажа"
        case .transfer: return "Ручной перевод"
        }
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
