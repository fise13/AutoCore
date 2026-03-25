import Foundation

protocol InventoryMovementRepository {
    func save(_ movement: InventoryMovementEntity) async throws -> InventoryMovementEntity
    func findByID(_ id: String) async throws -> InventoryMovementEntity?
    func findAll(companyId: String, filter: InventoryMovementFilter?) async throws -> [InventoryMovementEntity]
}

struct InventoryMovementFilter {
    var itemId: String? = nil
    var fromDate: Date? = nil
    var toDate: Date? = nil
    var limit: Int? = nil
}
