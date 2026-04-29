import Foundation
import SwiftUI
import Combine

@MainActor
final class AccountingViewModel: ObservableObject {
    @Published private(set) var operations: [FinancialOperation] = []
    @Published private(set) var cashBalance: Decimal = 0
    @Published private(set) var kaspiBalance: Decimal = 0
    @Published private(set) var todaySales: Decimal = 0
    @Published private(set) var advancesReceived: Decimal = 0
    @Published private(set) var advancesPaid: Decimal = 0
    var advancesBalance: Decimal { advancesReceived - advancesPaid }
    @Published private(set) var advanceInsights: AdvanceInsights = .empty
    @Published private(set) var advanceOperationsAll: [FinancialOperation] = []
    @Published private(set) var isLoading = false

    private static let advanceKeywords = ["аванс", "предоплата", "prepayment", "advance", "задаток", "депозит"]

    private static func isAdvanceText(_ text: String) -> Bool {
        let lower = text.lowercased()
        return advanceKeywords.contains { lower.contains($0) }
    }

    struct AdvancePartyStat: Identifiable, Hashable {
        let name: String
        var operationsCount: Int
        var totalAmount: Decimal
        var id: String { name }
    }

    struct AdvanceInsights: Hashable {
        var totalAdvanceOperations: Int
        var uniqueReceivedParties: Int
        var uniquePaidParties: Int
        var averageReceived: Decimal
        var averagePaid: Decimal
        var topReceived: [AdvancePartyStat]
        var topPaid: [AdvancePartyStat]

        static let empty = AdvanceInsights(
            totalAdvanceOperations: 0,
            uniqueReceivedParties: 0,
            uniquePaidParties: 0,
            averageReceived: 0,
            averagePaid: 0,
            topReceived: [],
            topPaid: []
        )
    }

    enum AdvanceDirection: String, CaseIterable, Identifiable {
        case all = "Все"
        case received = "Получено"
        case paid = "Выдано"

        var id: String { rawValue }
    }
    
    @Published var filterType: FinancialOperationEntity.OperationType? = nil
    @Published var filterAccount: FinancialOperationEntity.Account? = nil
    @Published var filterFromDate: Date? = nil
    @Published var filterToDate: Date? = nil
    @Published var searchText: String = ""
    @Published var selectedOperationID: Int64?
    @Published var errorMessage: String?
    
    let financialOperationRepository: FinancialOperationRepository
    private let calculateCashBalanceUseCase: CalculateCashBalanceUseCase
    private let getOperationsUseCase: GetOperationsUseCase
    
    init(financialOperationRepository: FinancialOperationRepository) {
        self.financialOperationRepository = financialOperationRepository
        self.calculateCashBalanceUseCase = CalculateCashBalanceUseCase(financialOperationRepository: financialOperationRepository)
        self.getOperationsUseCase = GetOperationsUseCase(financialOperationRepository: financialOperationRepository)
        
        refreshAll()
    }
    
    func refreshAll() {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                // Загружаем балансы
                cashBalance = try calculateCashBalanceUseCase.execute(account: .cashbox)
                kaspiBalance = try calculateCashBalanceUseCase.execute(account: .kaspi)
                
                // Загружаем сегодняшние продажи
                let calendar = Calendar.current
                let todayStart = calendar.startOfDay(for: Date())
                let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!
                
                let todaySalesFilter = FinancialOperationFilter(
                    type: .sale,
                    account: nil,
                    relatedMotorID: nil,
                    fromDate: todayStart,
                    toDate: todayEnd,
                    limit: nil,
                    offset: nil
                )
                
                let todayOperations = try getOperationsUseCase.execute(filter: todaySalesFilter)
                todaySales = todayOperations.reduce(0) { $0 + $1.amount }

                // Считаем авансы из всех операций по ключевым словам
                let allOpsFilter = FinancialOperationFilter(
                    type: nil, account: nil, relatedMotorID: nil,
                    fromDate: nil, toDate: nil, limit: nil, offset: nil
                )
                let allOps = try getOperationsUseCase.execute(filter: allOpsFilter)
                let advanceOps = allOps.filter(Self.isAdvanceOperation)
                let received = advanceOps.filter { Self.isAdvanceReceived($0) }
                let paid = advanceOps.filter { Self.isAdvancePaid($0) }

                advancesReceived = received.reduce(0) { $0 + $1.amount }
                advancesPaid = paid.reduce(0) { $0 + $1.amount }
                advanceOperationsAll = advanceOps.map(Self.mapOperationEntity)
                    .sorted(by: { $0.createdAt > $1.createdAt })
                advanceInsights = Self.buildAdvanceInsights(received: received, paid: paid, allCount: advanceOps.count)

                // Загружаем операции с фильтрами
                refreshOperations()
            } catch {
                errorMessage = "Ошибка загрузки данных бухгалтерии: \(error.localizedDescription)"
            }
        }
    }
    
    func refreshOperations() {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                let filter = FinancialOperationFilter(
                    type: filterType,
                    account: filterAccount,
                    relatedMotorID: nil,
                    fromDate: filterFromDate,
                    toDate: filterToDate,
                    limit: 100,
                    offset: nil
                )
                
                let entities = try getOperationsUseCase.execute(filter: filter)
                var mappedOperations = entities.map(Self.mapOperationEntity)
                
                // Применяем поиск
                if !searchText.isEmpty {
                    let searchLower = searchText.lowercased()
                    mappedOperations = mappedOperations.filter { operation in
                        operation.description.lowercased().contains(searchLower) ||
                        (operation.category?.lowercased().contains(searchLower) ?? false) ||
                        operation.comment.lowercased().contains(searchLower) ||
                        operation.source.lowercased().contains(searchLower) ||
                        operation.details.lowercased().contains(searchLower) ||
                        Self.accountTitle(operation.account).lowercased().contains(searchLower) ||
                        Self.typeTitle(operation.type).lowercased().contains(searchLower) ||
                        NSDecimalNumber(decimal: operation.amount).stringValue.lowercased().contains(searchLower)
                    }
                }
                
                operations = mappedOperations
            } catch {
                errorMessage = "Ошибка загрузки операций: \(error.localizedDescription)"
            }
        }
    }

    func selectedOperation() -> FinancialOperation? {
        guard let selectedOperationID else { return nil }
        return operations.first(where: { $0.id == selectedOperationID })
    }

    func updateOperation(
        _ operation: FinancialOperation,
        amount: Decimal,
        account: FinancialOperationEntity.Account,
        category: String?,
        description: String,
        comment: String
    ) {
        Task {
            do {
                let entity = FinancialOperationEntity(
                    id: operation.id,
                    cloudDocumentId: operation.cloudDocumentId,
                    type: operation.type,
                    amount: amount,
                    paymentMethod: operation.paymentMethod,
                    cashReceived: operation.cashReceived,
                    changeGiven: operation.changeGiven,
                    account: account,
                    relatedMotorID: operation.relatedMotorID,
                    createdAt: operation.createdAt,
                    createdByUser: operation.createdByUser,
                    comment: comment,
                    source: operation.source,
                    details: description,
                    category: category,
                    description: description
                )
                _ = try financialOperationRepository.update(entity)
                refreshAll()
            } catch {
                errorMessage = "Не удалось обновить операцию: \(error.localizedDescription)"
            }
        }
    }

    func deleteOperation(_ operation: FinancialOperation) {
        Task {
            do {
                let entity = FinancialOperationEntity(
                    id: operation.id,
                    cloudDocumentId: operation.cloudDocumentId,
                    type: operation.type,
                    amount: operation.amount,
                    paymentMethod: operation.paymentMethod,
                    cashReceived: operation.cashReceived,
                    changeGiven: operation.changeGiven,
                    account: operation.account,
                    relatedMotorID: operation.relatedMotorID,
                    createdAt: operation.createdAt,
                    createdByUser: operation.createdByUser,
                    comment: operation.comment,
                    source: operation.source,
                    details: operation.details,
                    category: operation.category,
                    description: operation.description
                )
                try financialOperationRepository.delete(entity)
                refreshAll()
            } catch {
                errorMessage = "Не удалось удалить операцию: \(error.localizedDescription)"
            }
        }
    }

    func deleteAllOperations(companyId: String?) {
        Task {
            do {
                try financialOperationRepository.deleteAll(companyId: companyId)
                refreshAll()
            } catch {
                errorMessage = "Не удалось очистить бухгалтерию: \(error.localizedDescription)"
            }
        }
    }

    func createManualOperation(
        type: FinancialOperationEntity.OperationType,
        amount: Decimal,
        account: FinancialOperationEntity.Account,
        paymentMethod: FinancialOperationEntity.PaymentMethod,
        category: String?,
        description: String,
        comment: String,
        source: String,
        createdByUser: String
    ) {
        Task {
            do {
                let normalizedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedDescription.isEmpty else {
                    errorMessage = "Описание операции обязательно"
                    return
                }
                guard amount > 0 else {
                    errorMessage = "Сумма должна быть больше нуля"
                    return
                }
                let entity = FinancialOperationEntity(
                    id: 0,
                    type: type,
                    amount: amount,
                    paymentMethod: paymentMethod,
                    cashReceived: nil,
                    changeGiven: nil,
                    account: account,
                    relatedMotorID: nil,
                    createdAt: Date(),
                    createdByUser: createdByUser,
                    comment: comment,
                    source: source,
                    details: normalizedDescription,
                    category: category,
                    description: normalizedDescription
                )
                _ = try financialOperationRepository.save(entity)
                refreshAll()
            } catch {
                errorMessage = "Не удалось создать операцию: \(error.localizedDescription)"
            }
        }
    }

    func advanceOperations(direction: AdvanceDirection) -> [FinancialOperation] {
        switch direction {
        case .all:
            return advanceOperationsAll
        case .received:
            return advanceOperationsAll.filter { $0.type == .income || $0.type == .sale }
        case .paid:
            return advanceOperationsAll.filter { $0.type == .expense || $0.type == .refund }
        }
    }

    private static func isAdvanceOperation(_ op: FinancialOperationEntity) -> Bool {
        isAdvanceText(op.description)
            || isAdvanceText(op.category ?? "")
            || isAdvanceText(op.comment)
            || isAdvanceText(op.details)
            || isAdvanceText(op.source)
    }

    private static func isAdvanceReceived(_ op: FinancialOperationEntity) -> Bool {
        op.type == .income || op.type == .sale
    }

    private static func isAdvancePaid(_ op: FinancialOperationEntity) -> Bool {
        op.type == .expense || op.type == .refund
    }

    private static func mapOperationEntity(_ entity: FinancialOperationEntity) -> FinancialOperation {
        FinancialOperation(
            id: entity.id,
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
    }

    private static func accountTitle(_ account: FinancialOperationEntity.Account) -> String {
        switch account {
        case .cashbox: return "Касса"
        case .kaspi: return "Каспи"
        }
    }

    private static func typeTitle(_ type: FinancialOperationEntity.OperationType) -> String {
        switch type {
        case .sale: return "Продажа"
        case .income: return "Приход"
        case .refund: return "Возврат"
        case .expense: return "Расход"
        case .transfer: return "Перевод"
        }
    }

    private static func buildAdvanceInsights(
        received: [FinancialOperationEntity],
        paid: [FinancialOperationEntity],
        allCount: Int
    ) -> AdvanceInsights {
        let receivedStats = aggregateParties(received)
        let paidStats = aggregateParties(paid)
        let avgReceived = averageAmount(for: received)
        let avgPaid = averageAmount(for: paid)
        return AdvanceInsights(
            totalAdvanceOperations: allCount,
            uniqueReceivedParties: receivedStats.count,
            uniquePaidParties: paidStats.count,
            averageReceived: avgReceived,
            averagePaid: avgPaid,
            topReceived: Array(receivedStats.prefix(5)),
            topPaid: Array(paidStats.prefix(5))
        )
    }

    private static func aggregateParties(_ ops: [FinancialOperationEntity]) -> [AdvancePartyStat] {
        var map: [String: AdvancePartyStat] = [:]
        for op in ops {
            let party = detectCounterparty(op)
            var stat = map[party] ?? AdvancePartyStat(name: party, operationsCount: 0, totalAmount: 0)
            stat.operationsCount += 1
            stat.totalAmount += op.amount
            map[party] = stat
        }
        return map.values.sorted {
            if $0.totalAmount == $1.totalAmount {
                return $0.operationsCount > $1.operationsCount
            }
            return $0.totalAmount > $1.totalAmount
        }
    }

    private static func detectCounterparty(_ op: FinancialOperationEntity) -> String {
        let raw = [op.source, op.comment, op.details, op.description]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
        if raw.isEmpty { return "Не указан" }

        let separators = CharacterSet(charactersIn: ",;|")
        let firstChunk = raw.components(separatedBy: separators).first ?? raw
        var cleaned = firstChunk
            .replacingOccurrences(of: "аванс", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "предоплата", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "advance", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "prepayment", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "клиент", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "customer", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "от", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "для", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ":", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = String(cleaned.prefix(40))
        return cleaned.count < 2 ? "Не указан" : cleaned
    }

    private static func averageAmount(for ops: [FinancialOperationEntity]) -> Decimal {
        guard !ops.isEmpty else { return 0 }
        let sum = ops.reduce(Decimal.zero) { $0 + $1.amount }
        let ns = NSDecimalNumber(decimal: sum)
        return ns.dividing(by: NSDecimalNumber(value: ops.count)).decimalValue
    }
}
