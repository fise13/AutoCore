//
//  IOSAccountingViewModel.swift
//  AutoCore
//
//  ViewModel бухгалтерии для iOS. Данные из Firestore: real-time listener + кэш для офлайна.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class IOSAccountingViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var operations: [FinancialOperation] = []
    @Published private(set) var cashBalance: Decimal = 0
    @Published private(set) var kaspiBalance: Decimal = 0
    @Published private(set) var todaySales: Decimal = 0
    @Published private(set) var todayExpenses: Decimal = 0
    @Published private(set) var isLoading = false
    @Published private(set) var syncState: SyncState = .idle
    @Published var errorMessage: String?

    enum SyncState: Equatable {
        case idle
        case syncing
        case synced
        case offline
        case error(String)
    }

    // MARK: - Computed Properties

    var totalBalance: Decimal { cashBalance + kaspiBalance }

    var todayOperationCount: Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        return operations.filter { $0.createdAt >= todayStart }.count
    }

    var weeklyIncome: Decimal {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return operations
            .filter { ($0.type == .sale || $0.type == .income) && $0.createdAt >= weekAgo }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    var weeklyExpense: Decimal {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return operations
            .filter { $0.type == .expense && $0.createdAt >= weekAgo }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    // MARK: - Private

    private let financialSync: FinancialSyncService
    private let companyId: String
    private let currentUserEmail: String
    private var observeTask: Task<Void, Never>?
    
    init(companyId: String, financialSync: FinancialSyncService, currentUserEmail: String = "") {
        self.companyId = companyId
        self.financialSync = financialSync
        self.currentUserEmail = currentUserEmail.isEmpty ? "iOS" : currentUserEmail
    }
    
    // MARK: - Push Operations

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
        syncState = .syncing
        do {
            try await ensureFinancialWriteAccess()
            _ = try await financialSync.pushOperation(entity, companyId: companyId)
            syncState = .synced
        } catch {
            let message = readableSyncError(error, fallback: "Ошибка сохранения прихода")
            syncState = .error(message)
            throw NSError(domain: "IOSAccountingViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
    
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
        syncState = .syncing
        do {
            try await ensureFinancialWriteAccess()
            _ = try await financialSync.pushOperation(entity, companyId: companyId)
            syncState = .synced
        } catch {
            let message = readableSyncError(error, fallback: "Ошибка сохранения расхода")
            syncState = .error(message)
            throw NSError(domain: "IOSAccountingViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    // MARK: - Observe & Refresh

    func startObserving() async {
        observeTask?.cancel()

        guard !companyId.isEmpty else {
            operations = []
            cashBalance = 0
            kaspiBalance = 0
            todaySales = 0
            todayExpenses = 0
            return
        }
        isLoading = true
        syncState = .syncing
        errorMessage = nil
        defer { isLoading = false }
        do {
            for await entities in financialSync.observeOperations(companyId: companyId) {
                applyEntities(entities)
                syncState = .synced
            }
        } catch {
            errorMessage = "Ошибка: \(error.localizedDescription)"
            syncState = .error(error.localizedDescription)
            LoggingService.shared.error("IOSAccountingViewModel observe failed", error: error)
        }
    }
    
    func refreshAll() async {
        guard !companyId.isEmpty else { return }
        isLoading = true
        syncState = .syncing
        errorMessage = nil
        defer { isLoading = false }
        do {
            let entities = try await financialSync.pullOperations(companyId: companyId, since: nil)
            applyEntities(entities)
            syncState = .synced
        } catch {
            errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
            syncState = .error(error.localizedDescription)
            LoggingService.shared.error("IOSAccountingViewModel refreshAll failed", error: error)
        }
    }

    func deleteOperation(_ operation: FinancialOperation) async throws {
        guard let documentId = operation.cloudDocumentId else {
            throw NSError(
                domain: "IOSAccountingViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Эта операция не может быть удалена: отсутствует cloud id."]
            )
        }
        syncState = .syncing
        do {
            try await ensureFinancialWriteAccess()
            try await financialSync.deleteOperation(documentId: documentId, companyId: companyId)
            syncState = .synced
        } catch {
            syncState = .error("Ошибка удаления")
            throw error
        }
        await refreshAll()
    }

    func updateOperation(
        _ operation: FinancialOperation,
        newAmount: Decimal,
        newAccount: FinancialOperationEntity.Account,
        newCategory: String?,
        newDescription: String,
        newComment: String
    ) async throws {
        guard let documentId = operation.cloudDocumentId else {
            throw NSError(domain: "IOSAccountingViewModel", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Нет cloud id для обновления"])
        }
        var fields: [String: Any] = [
            "amount": NSDecimalNumber(decimal: newAmount).doubleValue,
            "account": newAccount.rawValue,
            "description": newDescription,
            "details": newDescription,
            "comment": newComment
        ]
        if let cat = newCategory, !cat.isEmpty {
            fields["category"] = cat
        }
        syncState = .syncing
        do {
            try await ensureFinancialWriteAccess()
            try await financialSync.updateOperation(documentId: documentId, companyId: companyId, fields: fields)
            syncState = .synced
        } catch {
            syncState = .error("Ошибка редактирования")
            throw error
        }
    }

    func dismissError() {
        errorMessage = nil
        if case .error = syncState {
            syncState = .synced
        }
    }

    // MARK: - Private

    private func applyEntities(_ entities: [FinancialOperationEntity]) {
        let mapped = entities.enumerated().map { index, entity in
            let stableId = Int64(truncatingIfNeeded: "\(entity.createdAt.timeIntervalSince1970)-\(entity.amount)-\(index)".hashValue)
            return FinancialOperation(
                id: stableId,
                cloudDocumentId: entity.cloudDocumentId,
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

        let todayEntities = entities.filter { $0.createdAt >= todayStart && $0.createdAt < todayEnd }
        todaySales = todayEntities.filter { $0.type == .sale }.reduce(0) { $0 + $1.amount }
        todayExpenses = todayEntities.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }

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

    private func ensureFinancialWriteAccess() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "IOSAccountingViewModel",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Вы не авторизованы. Войдите в аккаунт заново."]
            )
        }
        _ = try await user.getIDTokenResult(forcingRefresh: true)

        let trimmedCompanyId = companyId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCompanyId.isEmpty else {
            throw NSError(
                domain: "IOSAccountingViewModel",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Не определена компания. Создайте или выберите компанию перед добавлением операции."]
            )
        }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        let userSnapshot = try await userRef.getDocument(source: .server)
        let currentDocCompanyId = (userSnapshot.data()?["companyId"] as? String) ?? ""
        if currentDocCompanyId != trimmedCompanyId {
            try await userRef.setData(["companyId": trimmedCompanyId], merge: true)
        }
    }

    private func readableSyncError(_ error: Error, fallback: String) -> String {
        let ns = error as NSError
        if ns.domain == FirestoreErrorDomain && ns.code == FirestoreErrorCode.permissionDenied.rawValue {
            return "Недостаточно прав для записи операции. Проверьте роль пользователя и companyId в Firebase."
        }
        let raw = error.localizedDescription
        if raw.localizedCaseInsensitiveContains("permission") || raw.localizedCaseInsensitiveContains("insufficient") {
            return "Недостаточно прав для записи операции. Проверьте роль пользователя и companyId в Firebase."
        }
        if raw.localizedCaseInsensitiveContains("network") {
            return "Проблема с сетью. Проверьте интернет и повторите попытку."
        }
        return fallback + ": " + raw
    }

    #if os(iOS)
    private func todaySpendingByCategory(from entities: [FinancialOperationEntity]) -> TodaySpendingPayload? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let todayExpenseEntities = entities.filter {
            $0.type == .expense && $0.createdAt >= todayStart && $0.createdAt < todayEnd
        }
        var food: Decimal = 0, transport: Decimal = 0, shopping: Decimal = 0, other: Decimal = 0
        for op in todayExpenseEntities {
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
