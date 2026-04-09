//
//  IOSAccountingTabView.swift
//  AutoCore
//
//  Бухгалтерия на iPhone. Данные читаются напрямую из Firestore по companyId.
//
import SwiftUI
import UIKit

#if os(iOS)

struct IOSAccountingTabView: View {
    let database: DatabaseService
    let companyId: String
    /// Текущий пользователь; для бухгалтера/владельца/админа показываются кнопки Приход/Расход и сканер.
    let currentUser: UserEntity?
    
    @StateObject private var viewModel: IOSAccountingViewModel
    @State private var selectedFilter: FinancialOperationEntity.OperationType?
    @State private var showAddIncome = false
    @State private var showAddExpense = false
    @State private var showInvoiceScanner = false
    @State private var operationToEdit: FinancialOperation?
    
    init(database: DatabaseService, companyId: String, currentUser: UserEntity? = nil) {
        self.database = database
        self.companyId = companyId
        self.currentUser = currentUser
        _viewModel = StateObject(wrappedValue: IOSAccountingViewModel(
            companyId: companyId,
            financialSync: FirestoreFinancialSyncService(),
            currentUserEmail: currentUser?.email ?? ""
        ))
    }
    
    /// Бухгалтер, владелец, админ и сотрудник могут добавлять приход/расход.
    private var canAddOperations: Bool {
        guard let user = currentUser else { return false }
        switch user.role {
        case .owner, .admin, .accountant, .employee: return true
        case .viewer: return false
        }
    }

    /// Сканер накладных — только owner/admin/accountant.
    private var canUseInvoiceScanner: Bool {
        guard let user = currentUser else { return false }
        switch user.role {
        case .owner, .admin, .accountant: return true
        case .employee, .viewer: return false
        }
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
            ZStack {
                IOSScreenBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        flowlyHeaderSection
                        flowlyContentSection
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.isLoading && viewModel.operations.isEmpty {
                    ProgressView("Загрузка…")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 12)
                }
            }
            .refreshable {
                await viewModel.refreshAll()
            }
            .task {
                await viewModel.startObserving()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await viewModel.refreshAll() }
            }
            .toolbar {
                if canAddOperations {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            IOSHaptics.impact(.light)
                            showAddIncome = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(IOSPalette.positive)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(IOSPalette.positive.opacity(0.16))
                                        .overlay(
                                            Circle().stroke(IOSPalette.positive.opacity(0.35), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Добавить приход")

                        Button {
                            IOSHaptics.impact(.light)
                            showAddExpense = true
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(IOSPalette.negative)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(IOSPalette.negative.opacity(0.14))
                                        .overlay(
                                            Circle().stroke(IOSPalette.negative.opacity(0.30), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Добавить расход")

                        if canUseInvoiceScanner {
                            Button {
                                IOSHaptics.impact(.light)
                                showInvoiceScanner = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.viewfinder")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Скан")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(IOSPalette.accentGradient)
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Сканировать накладную")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddIncome) {
                IOSAddIncomeSheet(
                    companyId: companyId,
                    viewModel: viewModel,
                    onDismiss: { showAddIncome = false }
                )
            }
            .sheet(isPresented: $showAddExpense) {
                IOSAddExpenseSheet(
                    companyId: companyId,
                    viewModel: viewModel,
                    onDismiss: { showAddExpense = false }
                )
            }
            .sheet(isPresented: $showInvoiceScanner) {
                IOSInvoiceScanFlowView(
                    companyId: companyId,
                    currentUserEmail: currentUser?.email ?? "",
                    onDismiss: { showInvoiceScanner = false }
                )
            }
            .sheet(item: $operationToEdit) { op in
                IOSEditOperationSheet(
                    operation: op,
                    viewModel: viewModel,
                    onDismiss: { operationToEdit = nil }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var flowlyHeaderSection: some View {
        ZStack(alignment: .topLeading) {
            IOSPalette.headerGradient
                .frame(height: 220)
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 12) {
                Text("Операции")
                    .font(IOSDesign.Typography.title)
                    .foregroundStyle(.white)
                let total = viewModel.cashBalance + viewModel.kaspiBalance
                Text("\(currencyFormatter.string(from: total as NSDecimalNumber) ?? "0") ₸")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(IOSMotion.standard, value: total)
                HStack(spacing: 16) {
                    filterPill("Неделя")
                    filterPill("Месяц")
                    filterPill("Год")
                }
                IOSMiniBarChart(values: dailyTotalsForLastWeek(), accent: .white.opacity(0.9))
                    .frame(height: 80)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.x3)
            .padding(.top, 60)
            .padding(.bottom, Spacing.x3)
        }
    }

    private func filterPill(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.2)))
    }

    private func dailyTotalsForLastWeek() -> [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
        return days.map { day in
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let dayOps = viewModel.operations.filter { $0.createdAt >= day && $0.createdAt < next }
            let total = dayOps.reduce(Decimal(0)) { $0 + abs($1.amount) }
            return NSDecimalNumber(decimal: total).doubleValue
        }
    }

    private var flowlyContentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            HStack {
                Text("Операции по типу")
                    .font(IOSDesign.Typography.title)
                    .foregroundStyle(IOSPalette.textPrimary)
                Spacer()
            }
            .padding(.horizontal, Spacing.x3)
            .padding(.top, Spacing.x3)

            filterSection
                .iosAnimatedAppear(index: 0)

            IOSFlowlyCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Список операций")
                        .font(IOSDesign.Typography.subtitle.weight(.semibold))
                        .foregroundStyle(IOSPalette.textPrimary)

                    if viewModel.isLoading && filteredOperations.isEmpty {
                        VStack(spacing: Spacing.x2) {
                            ProgressView()
                                .tint(IOSPalette.flowlyBlue)
                            Text("Загрузка…")
                                .font(.subheadline)
                                .foregroundStyle(IOSPalette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.x3)
                    } else if filteredOperations.isEmpty {
                        VStack(spacing: Spacing.unit) {
                            Image(systemName: "tray")
                                .font(.system(size: 22))
                                .foregroundStyle(IOSPalette.textSecondary.opacity(0.7))
                            Text("Нет операций по выбранному фильтру")
                                .font(.subheadline)
                                .foregroundStyle(IOSPalette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.x2)
                    } else {
                        let ops = Array(filteredOperations.prefix(60))
                        VStack(spacing: 0) {
                            ForEach(Array(ops.enumerated()), id: \.element.id) { _, op in
                                IOSOperationRow(operation: op)
                                    .padding(.vertical, 10)
                                    .contextMenu {
                                        if canAddOperations, op.cloudDocumentId != nil {
                                            Button {
                                                operationToEdit = op
                                            } label: {
                                                Label("Редактировать", systemImage: "pencil")
                                            }
                                            Button(role: .destructive) {
                                                Task {
                                                    IOSHaptics.notification(.warning)
                                                    try? await viewModel.deleteOperation(op)
                                                }
                                            } label: {
                                                Label("Удалить", systemImage: "trash")
                                            }
                                        }
                                    }
                                if op.id != ops.last?.id {
                                    Divider().overlay(IOSPalette.separator)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.x3)
            .iosAnimatedAppear(index: 1)
        }
        .padding(.bottom, Spacing.x3)
    }

    private var filteredOperations: [FinancialOperation] {
        guard let selectedFilter else { return viewModel.operations }
        return viewModel.operations.filter { $0.type == selectedFilter }
    }

    private var filterSection: some View {
        IOSFlowlyCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Фильтры")
                    .font(IOSDesign.Typography.subtitle.weight(.semibold))
                    .foregroundStyle(IOSPalette.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(title: "Все", type: nil, icon: "line.3.horizontal.decrease.circle")
                        filterChip(title: "Продажи", type: .sale, icon: "arrow.up.right")
                        filterChip(title: "Приход", type: .income, icon: "plus")
                        filterChip(title: "Расход", type: .expense, icon: "minus")
                        filterChip(title: "Возврат", type: .refund, icon: "arrow.uturn.backward")
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.x3)
    }

    private func filterChip(title: String, type: FinancialOperationEntity.OperationType?, icon: String) -> some View {
        let isSelected = selectedFilter == type
        return Button {
            withAnimation(IOSMotion.standard) {
                selectedFilter = type
            }
        } label: {
            IOSTagChip(
                text: title,
                style: isSelected ? .accent : .neutral,
                systemImage: icon,
                isSelected: isSelected
            )
        }
        .buttonStyle(.plain)
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

struct IOSOperationRow: View {
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
        f.groupingSeparator = " "
        return f
    }()

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
            return IOSPalette.positive
        case .expense, .refund:
            return IOSPalette.negative
        case .transfer:
            return IOSPalette.textSecondary
        }
    }

    private var amountColor: Color {
        switch operation.type {
        case .sale, .income:
            return IOSPalette.positive
        case .expense, .refund:
            return IOSPalette.negative
        case .transfer:
            return IOSPalette.textSecondary
        }
    }

    private var accountLabel: String {
        operation.account == .cashbox ? "Касса" : "Каспи"
    }

    /// Основной текст: описание, источник или детали (для приходов — Мотор #ID)
    private var primaryDetailText: String? {
        if !operation.description.isEmpty { return operation.description }
        if !operation.details.isEmpty { return operation.details }
        if !operation.source.isEmpty { return operation.source }
        return nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                // Тип операции
                Text(operationTypeName(operation.type))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(IOSPalette.textPrimary)

                // Описание / источник / Мотор #ID
                if let text = primaryDetailText, !text.isEmpty {
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(IOSPalette.textPrimary)
                        .lineLimit(2)
                }

                // Категория (для расходов)
                if let cat = operation.category, !cat.isEmpty {
                    Text(cat)
                        .font(.caption)
                        .foregroundStyle(IOSPalette.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(IOSPalette.backgroundElevated)
                        .cornerRadius(4)
                }

                // Дата
                Text(dateFormatter.string(from: operation.createdAt))
                    .font(.caption)
                    .foregroundStyle(IOSPalette.textSecondary)

                // Пользователь
                if !operation.createdByUser.isEmpty {
                    Text(operation.createdByUser)
                        .font(.caption2)
                        .foregroundStyle(IOSPalette.textSecondary)
                        .lineLimit(1)
                }

                if !operation.comment.isEmpty {
                    Text(operation.comment)
                        .font(.caption)
                        .foregroundStyle(IOSPalette.textSecondary.opacity(0.9))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(amountFormatter.string(from: operation.amount as NSDecimalNumber) ?? "0") ₸")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amountColor)
                Text(accountLabel)
                    .font(.caption2)
                    .foregroundStyle(IOSPalette.textSecondary)
            }
        }
    }
}

#endif
