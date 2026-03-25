import Foundation

protocol InventoryRepository {
    func save(_ item: InventoryItemEntity) async throws -> InventoryItemEntity
    func findByID(_ id: String) async throws -> InventoryItemEntity?
    func findAll(companyId: String, filter: InventoryFilter?) async throws -> [InventoryItemEntity]
    func delete(_ id: String) async throws
}

struct InventoryFilter {
    var searchText: String? = nil
    var category: String? = nil
}
