import Foundation

/// Use Case: Calculate Cash Balance
@MainActor
final class CalculateCashBalanceUseCase {
    private let financialOperationRepository: FinancialOperationRepository
    
    init(financialOperationRepository: FinancialOperationRepository) {
        self.financialOperationRepository = financialOperationRepository
    }
    
    func execute(account: FinancialOperationEntity.Account, upToDate: Date? = nil) throws -> Decimal {
        return try financialOperationRepository.calculateCashBalance(account: account, upToDate: upToDate)
    }
}
