import Foundation

/// Repository interface for MVP Engine inventory entity.
protocol EngineRepository {
    func save(_ engine: EngineItemEntity) async throws -> EngineItemEntity
    func findByID(_ id: String) async throws -> EngineItemEntity?
    func findAll(companyId: String, filter: EngineFilter?) async throws -> [EngineItemEntity]
}

struct EngineFilter {
    var status: EngineItemEntity.EngineStatus? = nil
    var searchText: String? = nil
}
