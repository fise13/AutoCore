import SwiftUI
import UIKit

#if os(iOS)

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
                IOSHaptics.impact(.light)
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
                            Label("Приход", systemImage: "plus.circle")
                        }
                        Button {
                            IOSHaptics.impact(.light)
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

    // MARK: - Header

    private var flowlyHeaderSection: some View {
        ZStack(alignment: .topLeading) {
            IOSPalette.headerGradient
                .frame(height: 220)
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Денежная позиция")
                        .font(IOSDesign.Typography.subtitle)
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    syncStatusBadge
                }
                .iosAnimatedAppear(index: 0)

                Text("\(currencyFormatter.string(from: viewModel.totalBalance as NSDecimalNumber) ?? "0") ₸")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(IOSMotion.standard, value: viewModel.totalBalance)
                    .iosAnimatedAppear(index: 1)
                    .accessibilityLabel("Общий баланс \(currencyFormatter.string(from: viewModel.totalBalance as NSDecimalNumber) ?? "0") тенге")

                let total = viewModel.totalBalance
                let progress = total > 0 ? NSDecimalNumber(decimal: viewModel.cashBalance / total).doubleValue : 0.5
                VStack(alignment: .leading, spacing: 6) {
                    IOSProgressBar(progress: progress, trackColor: .white.opacity(0.2), fillColor: .white.opacity(0.9))
                        .frame(height: 6)
                        .animation(IOSMotion.standard, value: progress)
                    HStack {
                        balanceLabel("Касса", value: viewModel.cashBalance)
                        Spacer()
                        balanceLabel("Kaspi", value: viewModel.kaspiBalance)
                    }
                }
                .iosAnimatedAppear(index: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.x3)
            .padding(.top, 60)
            .padding(.bottom, Spacing.x3)
        }
    }

    private func balanceLabel(_ title: String, value: Decimal) -> some View {
        HStack(spacing: 4) {
            Text("\(title):")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            Text("\(currencyFormatter.string(from: value as NSDecimalNumber) ?? "0") ₸")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))
        }
    }

    @ViewBuilder
    private var syncStatusBadge: some View {
        switch viewModel.syncState {
        case .syncing:
            HStack(spacing: 4) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.6)
                Text("Обновление")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.15)))
        case .offline:
            HStack(spacing: 4) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 10, weight: .medium))
                Text("Офлайн")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.15)))
        case .error:
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        default:
            EmptyView()
        }
    }

    // MARK: - Content

    private var flowlyContentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            if let errorMsg = viewModel.errorMessage {
                IOSStatusBanner(type: .error, message: errorMsg, onDismiss: { viewModel.dismissError() })
                    .padding(.horizontal, Spacing.x3)
                    .padding(.top, Spacing.x2)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            todayStatsSection
            balanceCardsSection
            chartSection
            recentOperationsSection
        }
        .padding(.bottom, Spacing.x3)
    }

    // MARK: - Today Stats

    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            IOSSectionHeader(title: "Сегодня", subtitle: todayDateString())
                .iosAnimatedAppear(index: 3)

            HStack(spacing: Spacing.unit) {
                IOSStatCard(
                    title: "Продажи",
                    value: "\(currencyFormatter.string(from: viewModel.todaySales as NSDecimalNumber) ?? "0") ₸",
                    subtitle: nil,
                    accentColor: IOSPalette.positive
                )
                IOSStatCard(
                    title: "Расходы",
                    value: "\(currencyFormatter.string(from: viewModel.todayExpenses as NSDecimalNumber) ?? "0") ₸",
                    subtitle: nil,
                    accentColor: IOSPalette.negative
                )
            }
            .padding(.horizontal, Spacing.x3)
            .iosAnimatedAppear(index: 4)
        }
        .padding(.top, Spacing.x3)
    }

    // MARK: - Balance Cards

    private var balanceCardsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            IOSSectionHeader(title: "Счета")

            HStack(spacing: Spacing.unit) {
                IOSCategoryCard(
                    title: "Касса",
                    value: "\(currencyFormatter.string(from: viewModel.cashBalance as NSDecimalNumber) ?? "0") ₸",
                    subtitle: nil,
                    icon: "banknote.fill",
                    pastelColor: IOSPalette.houseOrange
                )
                .iosAnimatedAppear(index: 5)
                IOSCategoryCard(
                    title: "Kaspi",
                    value: "\(currencyFormatter.string(from: viewModel.kaspiBalance as NSDecimalNumber) ?? "0") ₸",
                    subtitle: nil,
                    icon: "creditcard.fill",
                    pastelColor: IOSPalette.travelBlue
                )
                .iosAnimatedAppear(index: 6)
            }
            .padding(.horizontal, Spacing.x3)
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        IOSChartCard(
            title: "Динамика операций",
            subtitle: "Последние 7 дней",
            values: dailyTotalsForLastWeek(),
            accent: IOSPalette.chartBar
        )
        .padding(.horizontal, Spacing.x3)
        .iosAnimatedAppear(index: 7)
    }

    // MARK: - Recent Operations

    private var recentOperationsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            HStack {
                Text("Последние операции")
                    .font(IOSDesign.Typography.title2)
                    .foregroundStyle(IOSPalette.textPrimary)
                Spacer()
                if let onViewAll = onViewAllOperations {
                    Button(action: {
                        IOSHaptics.selection()
                        onViewAll()
                    }) {
                        Text("Все")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(IOSPalette.flowlyBlue)
                    }
                }
            }
            .padding(.horizontal, Spacing.x3)
            .iosAnimatedAppear(index: 8)

            if viewModel.isLoading && viewModel.operations.isEmpty {
                VStack(spacing: 12) {
                    IOSSkeletonCard(lineCount: 2)
                    IOSSkeletonCard(lineCount: 2)
                    IOSSkeletonCard(lineCount: 2)
                }
                .padding(.horizontal, Spacing.x3)
            } else if viewModel.operations.isEmpty {
                IOSFlowlyCard {
                    IOSEmptyStateView(
                        icon: "tray",
                        title: "Пока нет операций",
                        message: "Добавьте первый приход или расход",
                        actionTitle: canAddOperations ? "Добавить приход" : nil,
                        action: canAddOperations ? { showAddIncome = true } : nil
                    )
                }
                .padding(.horizontal, Spacing.x3)
            } else {
                let recentOps = Array(viewModel.operations.prefix(5))
                IOSFlowlyCard {
                    VStack(spacing: 0) {
                        ForEach(Array(recentOps.enumerated()), id: \.element.id) { _, op in
                            IOSOperationRow(operation: op)
                                .padding(.vertical, 10)
                            if op.id != recentOps.last?.id {
                                Divider()
                                    .overlay(IOSPalette.separator)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.x3)
                .iosAnimatedAppear(index: 9)
            }
        }
    }

    // MARK: - Helpers

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

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, EEEE"
        return formatter.string(from: Date())
    }
}

#endif
