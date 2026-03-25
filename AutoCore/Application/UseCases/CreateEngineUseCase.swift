import Foundation

/// Use Case: create engine inventory item for a company.
final class CreateEngineUseCase {
    private let engineRepository: EngineRepository

    init(engineRepository: EngineRepository) {
        self.engineRepository = engineRepository
    }

    func execute(_ dto: CreateEngineDTO) async throws -> EngineItemEntity {
        var engine = EngineItemEntity(
            id: dto.id ?? UUID().uuidString,
            companyId: dto.companyId,
            engineNumber: dto.engineNumber,
            model: dto.model,
            volume: dto.volume,
            hasGearbox: dto.hasGearbox,
            buyPrice: dto.buyPrice,
            sellPrice: dto.sellPrice,
            status: .stock,
            createdAt: dto.createdAt ?? Date(),
            soldAt: nil
        )

        try engine.validate()
        // Стартовая сущность всегда в статусе stock.
        engine.status = .stock
        return try await engineRepository.save(engine)
    }
}

struct CreateEngineDTO {
    let id: String?
    let companyId: String
    let engineNumber: String
    let model: String
    let volume: String
    let hasGearbox: Bool
    let buyPrice: Decimal
    let sellPrice: Decimal
    let createdAt: Date?

    init(
        id: String? = nil,
        companyId: String,
        engineNumber: String,
        model: String,
        volume: String,
        hasGearbox: Bool,
        buyPrice: Decimal,
        sellPrice: Decimal,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.companyId = companyId
        self.engineNumber = engineNumber
        self.model = model
        self.volume = volume
        self.hasGearbox = hasGearbox
        self.buyPrice = buyPrice
        self.sellPrice = sellPrice
        self.createdAt = createdAt
    }
}
