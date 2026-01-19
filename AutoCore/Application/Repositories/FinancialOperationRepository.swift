import Foundation

/// Repository Interface for Financial Operation Entity
protocol FinancialOperationRepository {
    func save(_ operation: FinancialOperationEntity) throws -> FinancialOperationEntity
    func findByID(_ id: Int64) throws -> FinancialOperationEntity?
    func findAll(filter: FinancialOperationFilter) throws -> [FinancialOperationEntity]
    func calculateCashBalance(account: FinancialOperationEntity.Account, upToDate: Date?) throws -> Decimal
}

/// Financial Operation Filter for queries
struct FinancialOperationFilter {
    var type: FinancialOperationEntity.OperationType? = nil
    var account: FinancialOperationEntity.Account? = nil
    var relatedMotorID: Int64? = nil
    var fromDate: Date? = nil
    var toDate: Date? = nil
    var limit: Int? = nil
    var offset: Int? = nil
}
