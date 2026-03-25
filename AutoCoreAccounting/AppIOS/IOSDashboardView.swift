import SwiftUI
import UIKit

#if os(iOS)

/// Главный экран бухгалтера: сводка по деньгам и быстрый доступ к операциям.
/// Данные читаются напрямую из Firestore по companyId. Flowly-стиль.
struct IOSDashboardView: View {
    let database: DatabaseService
    let companyId: String
    let currentUser: UserEntity?
    var onViewAllOperations: (() -> Void)? = nil

    @StateObject private var viewModel: IOSAccountingViewModel
    @State private var showAddIncome = false
    @State private var showAddExpense = false

    init(database: DatabaseService, companyId: String, currentUser: UserEntity? = nil, onViewAllOperations: (() -> Void)? = nil) {
        self.database = database
        self.companyId = companyId
        self.currentUser = currentUser
        self.onViewAllOperations = onViewAllOperations
        _viewModel = StateObject(wrappedValue: IOSAccountingViewModel(
            companyId: companyId,
            financialSync: FirestoreFinancialSyncService(),
            currentUserEmail: currentUser?.email ?? ""
        ))
    }

    private var canAddOperations: Bool {
        guard let user = currentUser else { return false }
        switch user.role {
        case .owner, .admin, .accountant, .employee: return true
        case .viewer: return false
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
                            showAddIncome = true
                        } label: {
                            Label("Приход", systemImage: "plus.circle")
                        }
                        Button {
                            showAddExpense = true
                        } label: {
                            Label("Расход", systemImage: "minus.circle")
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
        }
    }

    private var flowlyHeaderSection: some View {
        ZStack(alignment: .topLeading) {
            IOSPalette.flowlyBlue
                .frame(height: 200)
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 12) {
                Text("Денежная позиция")
                    .font(IOSDesign.Typography.subtitle)
                    .foregroundStyle(.white.opacity(0.9))
                    .iosAnimatedAppear(index: 0)
                Text("\(currencyFormatter.string(from: viewModel.cashBalance as NSDecimalNumber) ?? "0") ₸")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(IOSMotion.standard, value: viewModel.cashBalance)
                    .iosAnimatedAppear(index: 1)
                let total = viewModel.cashBalance + viewModel.kaspiBalance
                let progress = total > 0 ? NSDecimalNumber(decimal: viewModel.cashBalance / total).doubleValue : 0.5
                VStack(alignment: .leading, spacing: 6) {
                    IOSProgressBar(progress: progress, fillColor: IOSPalette.positive)
                        .frame(height: 8)
                        .animation(IOSMotion.standard, value: progress)
                    HStack {
                        Text("Kaspi: \(currencyFormatter.string(from: viewModel.kaspiBalance as NSDecimalNumber) ?? "0") ₸")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.x3)
            .padding(.top, 60)
            .padding(.bottom, Spacing.x3)
        }
    }

    private var flowlyContentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            HStack {
                Text("Бюджеты категорий")
                    .font(IOSDesign.Typography.title)
                    .foregroundStyle(IOSPalette.textPrimary)
                Spacer()
            }
            .padding(.horizontal, Spacing.x3)
            .padding(.top, Spacing.x3)

            HStack(spacing: Spacing.unit) {
                IOSCategoryCard(
                    title: "Касса",
                    value: "\(currencyFormatter.string(from: viewModel.cashBalance as NSDecimalNumber) ?? "0") ₸",
                    subtitle: nil,
                    icon: "banknote.fill",
                    pastelColor: IOSPalette.houseOrange
                )
                .iosAnimatedAppear(index: 2)
                IOSCategoryCard(
                    title: "Kaspi",
                    value: "\(currencyFormatter.string(from: viewModel.kaspiBalance as NSDecimalNumber) ?? "0") ₸",
                    subtitle: nil,
                    icon: "creditcard.fill",
                    pastelColor: IOSPalette.travelBlue
                )
                .iosAnimatedAppear(index: 3)
            }
            .padding(.horizontal, Spacing.x3)

            IOSFlowlyCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Динамика операций")
                        .font(IOSDesign.Typography.body.weight(.semibold))
                        .foregroundStyle(IOSPalette.textPrimary)
                    Text("Последние 7 дней")
                        .font(.caption)
                        .foregroundStyle(IOSPalette.textSecondary)
                    IOSMiniBarChart(values: dailyTotalsForLastWeek(), accent: IOSPalette.flowlyBlue)
                        .frame(height: 100)
                }
            }
            .padding(.horizontal, Spacing.x3)
            .iosAnimatedAppear(index: 4)

            HStack {
                Text("Последние операции")
                    .font(IOSDesign.Typography.title)
                    .foregroundStyle(IOSPalette.textPrimary)
                Spacer()
                if let onViewAll = onViewAllOperations {
                    Button(action: onViewAll) {
                        Text("View All")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(IOSPalette.flowlyBlue)
                    }
                }
            }
            .padding(.horizontal, Spacing.x3)
            .iosAnimatedAppear(index: 5)

            if viewModel.isLoading && viewModel.operations.isEmpty {
                IOSFlowlyCard {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(IOSPalette.flowlyBlue)
                        Text("Загрузка…")
                            .font(IOSDesign.Typography.subtitle)
                            .foregroundStyle(IOSPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.x2)
                }
                .padding(.horizontal, Spacing.x3)
            } else if viewModel.operations.isEmpty {
                IOSFlowlyCard {
                    Text("Пока нет операций")
                        .font(IOSDesign.Typography.subtitle)
                        .foregroundStyle(IOSPalette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.x2)
                }
                .padding(.horizontal, Spacing.x3)
            } else {
                let recentOps = Array(viewModel.operations.prefix(5))
                IOSFlowlyCard {
                    VStack(spacing: 0) {
                        ForEach(Array(recentOps.enumerated()), id: \.element.id) { index, op in
                            IOSOperationRow(operation: op)
                                .padding(.vertical, 10)
                                .iosAnimatedAppear(index: index, delayPerItem: 0.05)
                            if op.id != recentOps.last?.id {
                                Divider()
                                    .overlay(IOSPalette.border)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.x3)
                .iosAnimatedAppear(index: 6)
            }
        }
        .padding(.bottom, Spacing.x3)
    }

    private func dailyTotalsForLastWeek() -> [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
        return days.map { day in
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let dayOps = viewModel.operations.filter { $0.createdAt >= day && $0.createdAt < next }
            let total = dayOps.reduce(Decimal(0)) { $0 + absDecimal($1.amount) }
            return NSDecimalNumber(decimal: total).doubleValue
        }
    }

    private func absDecimal(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }
}

#endif

