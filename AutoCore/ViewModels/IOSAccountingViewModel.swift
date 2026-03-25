//
//  IOSAccountingViewModel.swift
//  AutoCore
//
//  ViewModel бухгалтерии для iOS. Данные из Firestore: real-time listener + кэш для офлайна.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class IOSAccountingViewModel: ObservableObject {
    @Published private(set) var operations: [FinancialOperation] = []
    @Published private(set) var cashBalance: Decimal = 0
    @Published private(set) var kaspiBalance: Decimal = 0
    @Published private(set) var todaySales: Decimal = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    private let financialSync: FinancialSyncService
    private let companyId: String
    /// Email текущего пользователя для createdByUser при добавлении прихода/расхода.
    private let currentUserEmail: String
    
    init(companyId: String, financialSync: FinancialSyncService, currentUserEmail: String = "") {
        self.companyId = companyId
        self.financialSync = financialSync
        self.currentUserEmail = currentUserEmail.isEmpty ? "iOS" : currentUserEmail
    }
    
    /// Добавить приход (доступно бухгалтеру, владельцу, админу).
    func pushIncome(
        amount: Decimal,
        account: FinancialOperationEntity.Account,
        description: String,
        comment: String
    ) async throws {
        let entity = FinancialOperationEntity(
            id: 0,
            type: .income,
            amount: amount,
            paymentMethod: .transfer,
            cashReceived: nil,
            changeGiven: nil,
            account: account,
            relatedMotorID: nil,
            createdAt: Date(),
            createdByUser: currentUserEmail,
            comment: comment,
            source: "Приход",
            details: description.isEmpty ? "Внесение средств" : description,
            category: nil,
            description: description.isEmpty ? "Внесение средств" : description
        )
        try entity.validate()
        _ = try await financialSync.pushOperation(entity, companyId: companyId)
    }
    
    /// Добавить расход (доступно бухгалтеру, владельцу, админу).
    func pushExpense(
        amount: Decimal,
        account: FinancialOperationEntity.Account,
        category: String?,
        description: String,
        comment: String
    ) async throws {
        let entity = FinancialOperationEntity(
            id: 0,
            type: .expense,
            amount: amount,
            paymentMethod: .transfer,
            cashReceived: nil,
            changeGiven: nil,
            account: account,
            relatedMotorID: nil,
            createdAt: Date(),
            createdByUser: currentUserEmail,
            comment: comment,
            source: "Расход",
            details: description,
            category: category,
            description: description
        )
        try entity.validate()
        _ = try await financialSync.pushOperation(entity, companyId: companyId)
    }
    
    /// Подписка на изменения: кэш → обновления при изменении данных. Офлайн-доступ через Firestore persistence.
    func startObserving() async {
        guard !companyId.isEmpty else {
            operations = []
            cashBalance = 0
            kaspiBalance = 0
            todaySales = 0
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            for await entities in financialSync.observeOperations(companyId: companyId) {
                applyEntities(entities)
            }
        } catch {
            errorMessage = "Ошибка: \(error.localizedDescription)"
            LoggingService.shared.error("IOSAccountingViewModel observe failed", error: error)
        }
    }
    
    /// Принудительное обновление (pull-to-refresh). С listener данные уже актуальны, но запрос обновит кэш.
    func refreshAll() async {
        guard !companyId.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let entities = try await financialSync.pullOperations(companyId: companyId, since: nil)
            applyEntities(entities)
        } catch {
            errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
            LoggingService.shared.error("IOSAccountingViewModel refreshAll failed", error: error)
        }
    }
    
    private func applyEntities(_ entities: [FinancialOperationEntity]) {
        let mapped = entities.enumerated().map { index, entity in
            let stableId = Int64(truncatingIfNeeded: "\(entity.createdAt.timeIntervalSince1970)-\(entity.amount)-\(index)".hashValue)
            return FinancialOperation(
                id: stableId,
                type: entity.type,
                amount: entity.amount,
                paymentMethod: entity.paymentMethod,
                cashReceived: entity.cashReceived,
                changeGiven: entity.changeGiven,
                account: entity.account,
                relatedMotorID: entity.relatedMotorID,
                createdAt: entity.createdAt,
                createdByUser: entity.createdByUser,
                comment: entity.comment,
                source: entity.source,
                details: entity.details,
                category: entity.category,
                description: entity.description
            )
        }.sorted { $0.createdAt > $1.createdAt }
        operations = mapped
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let todayEntities = entities.filter {
            $0.type == .sale && $0.createdAt >= todayStart && $0.createdAt < todayEnd
        }
        todaySales = todayEntities.reduce(0) { $0 + $1.amount }
        cashBalance = entities
            .filter { $0.account == .cashbox }
            .reduce(Decimal(0)) { sum, op in
                switch op.type {
                case .sale, .income, .refund: return sum + op.amount
                case .expense, .transfer: return sum - op.amount
                }
            }
        kaspiBalance = entities
            .filter { $0.account == .kaspi }
            .reduce(Decimal(0)) { sum, op in
                switch op.type {
                case .sale, .income, .refund: return sum + op.amount
                case .expense, .transfer: return sum - op.amount
                }
            }

        #if os(iOS)
        let dailyTotals = dailyTotalsForLastWeek(from: entities)
        let todaySpending = todaySpendingByCategory(from: entities)
        WidgetDataWriter.write(cashBalance: cashBalance, kaspiBalance: kaspiBalance, dailyTotals: dailyTotals, todaySpending: todaySpending)
        #endif
    }

    #if os(iOS)
    private func todaySpendingByCategory(from entities: [FinancialOperationEntity]) -> TodaySpendingPayload? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let todayExpenses = entities.filter {
            $0.type == .expense && $0.createdAt >= todayStart && $0.createdAt < todayEnd
        }
        var food: Decimal = 0, transport: Decimal = 0, shopping: Decimal = 0, other: Decimal = 0
        for op in todayExpenses {
            let cat = (op.category ?? "").lowercased()
            let amount = op.amount
            if cat.contains("еда") || cat.contains("продукт") || cat.contains("питание") || cat.contains("обед") || cat.contains("ужин") || cat.contains("завтрак") || cat.contains("кафе") || cat.contains("ресторан") || cat.contains("food") {
                food += amount
            } else if cat.contains("транспорт") || cat.contains("такси") || cat.contains("топливо") || cat.contains("бензин") || cat.contains("transport") {
                transport += amount
            } else if cat.contains("покупк") || cat.contains("магазин") || cat.contains("shopping") {
                shopping += amount
            } else {
                other += amount
            }
        }
        return TodaySpendingPayload(
            food: NSDecimalNumber(decimal: food).doubleValue,
            transport: NSDecimalNumber(decimal: transport).doubleValue,
            shopping: NSDecimalNumber(decimal: shopping).doubleValue,
            other: NSDecimalNumber(decimal: other).doubleValue
        )
    }

    private func dailyTotalsForLastWeek(from entities: [FinancialOperationEntity]) -> [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
        return days.map { day in
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let dayOps = entities.filter { $0.createdAt >= day && $0.createdAt < next }
            let total = dayOps.reduce(Decimal(0)) { $0 + abs($1.amount) }
            return NSDecimalNumber(decimal: total).doubleValue
        }
    }
    #endif
}
