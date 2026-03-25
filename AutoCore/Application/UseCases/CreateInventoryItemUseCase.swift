import Foundation

final class CreateInventoryItemUseCase {
    private let inventoryRepository: InventoryRepository
    private let movementRepository: InventoryMovementRepository?

    init(
        inventoryRepository: InventoryRepository,
        movementRepository: InventoryMovementRepository? = nil
    ) {
        self.inventoryRepository = inventoryRepository
        self.movementRepository = movementRepository
    }

    func execute(_ dto: CreateInventoryItemDTO) async throws -> InventoryItemEntity {
        var item = InventoryItemEntity(
            id: dto.id ?? UUID().uuidString,
            companyId: dto.companyId,
            name: dto.name,
            partNumber: dto.partNumber,
            category: dto.category,
            quantity: dto.quantity,
            buyPrice: dto.buyPrice,
            sellPrice: dto.sellPrice,
            createdAt: dto.createdAt ?? Date(),
            updatedAt: dto.createdAt ?? Date()
        )
        try item.validate()

        // Если quantity > 0 и есть репозиторий движений, фиксируем стартовый приход.
        if item.quantity > 0, let movementRepository {
            let movement = InventoryMovementEntity(
                id: UUID().uuidString,
                companyId: item.companyId,
                itemId: item.id,
                type: .income,
                quantityDelta: item.quantity,
                comment: dto.comment ?? "Начальный остаток",
                createdAt: dto.createdAt ?? Date()
            )
            try movement.validate()
            _ = try await movementRepository.save(movement)
        }

        return try await inventoryRepository.save(item)
    }
}

struct CreateInventoryItemDTO {
    let id: String?
    let companyId: String
    let name: String
    let partNumber: String
    let category: String
    let quantity: Decimal
    let buyPrice: Decimal
    let sellPrice: Decimal
    let comment: String?
    let createdAt: Date?

    init(
        id: String? = nil,
        companyId: String,
        name: String,
        partNumber: String,
        category: String,
        quantity: Decimal,
        buyPrice: Decimal,
        sellPrice: Decimal,
        comment: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.companyId = companyId
        self.name = name
        self.partNumber = partNumber
        self.category = category
        self.quantity = quantity
        self.buyPrice = buyPrice
        self.sellPrice = sellPrice
        self.comment = comment
        self.createdAt = createdAt
    }
}
