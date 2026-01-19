import Foundation

/// Use Case: Get Financial Operations
@MainActor
final class GetOperationsUseCase {
    private let financialOperationRepository: FinancialOperationRepository
    
    init(financialOperationRepository: FinancialOperationRepository) {
        self.financialOperationRepository = financialOperationRepository
    }
    
    func execute(filter: FinancialOperationFilter) throws -> [FinancialOperationEntity] {
        return try financialOperationRepository.findAll(filter: filter)
    }
}
