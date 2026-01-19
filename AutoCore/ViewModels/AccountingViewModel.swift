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
                print("Ошибка загрузки данных бухгалтерии: \(error)")
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
                print("Ошибка загрузки операций: \(error)")
            }
        }
    }
}
