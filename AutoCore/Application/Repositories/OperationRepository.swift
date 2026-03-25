import Foundation

/// Repository interface for MVP financial operations.
protocol OperationRepository {
    func save(_ operation: OperationEntity) async throws -> OperationEntity
    func findByID(_ id: String) async throws -> OperationEntity?
    func findAll(companyId: String, filter: OperationFilter?) async throws -> [OperationEntity]
}

struct OperationFilter {
    var type: OperationEntity.OperationType? = nil
    var accountId: String? = nil
    var fromDate: Date? = nil
    var toDate: Date? = nil
    var limit: Int? = nil
}
