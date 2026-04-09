import Foundation
import SwiftUI
import Combine

@MainActor
final class AccountingViewModel: ObservableObject {
    @Published private(set) var operations: [FinancialOperation] = []
    @Published private(set) var cashBalance: Decimal = 0
    @Published private(set) var kaspiBalance: Decimal = 0
    @Published private(set) var todaySales: Decimal = 0
    @Published private(set) var isLoading = false
    
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
                var mappedOperations = entities.map { entity in
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
                
                // Применяем поиск
                if !searchText.isEmpty {
                    let searchLower = searchText.lowercased()
                    mappedOperations = mappedOperations.filter { operation in
                        operation.description.lowercased().contains(searchLower) ||
                        (operation.category?.lowercased().contains(searchLower) ?? false) ||
                        operation.comment.lowercased().contains(searchLower) ||
                        operation.source.lowercased().contains(searchLower)
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
}
