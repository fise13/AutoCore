import Foundation

final class RemoveInventoryUseCase {
    private let inventoryRepository: InventoryRepository
    private let movementRepository: InventoryMovementRepository

    init(
        inventoryRepository: InventoryRepository,
        movementRepository: InventoryMovementRepository
    ) {
        self.inventoryRepository = inventoryRepository
        self.movementRepository = movementRepository
    }

    @discardableResult
    func execute(_ dto: RemoveInventoryDTO) async throws -> (item: InventoryItemEntity, movement: InventoryMovementEntity) {
        guard var item = try await inventoryRepository.findByID(dto.itemId) else {
            throw AppError.notFound(message: "Товар с ID \(dto.itemId) не найден")
        }
        guard item.companyId == dto.companyId else {
            throw AppError.logicError(message: "Товар принадлежит другой компании")
        }
        guard dto.quantity > 0 else {
            throw AppError.validationError(message: "Количество списания должно быть больше нуля")
        }
        guard item.quantity >= dto.quantity else {
            throw AppError.logicError(message: "Недостаточно товара на складе")
        }

        let movement = InventoryMovementEntity(
            id: UUID().uuidString,
            companyId: dto.companyId,
            itemId: dto.itemId,
            type: .expense,
            quantityDelta: -dto.quantity,
            comment: dto.comment,
            createdAt: dto.createdAt ?? Date()
        )
        try movement.validate()

        try item.applyMovement(type: .expense, quantityDelta: -dto.quantity)
        try item.validate()

        let savedItem = try await inventoryRepository.save(item)
        let savedMovement = try await movementRepository.save(movement)
        return (savedItem, savedMovement)
    }
}

struct RemoveInventoryDTO {
    let companyId: String
    let itemId: String
    let quantity: Decimal
    let comment: String
    let createdAt: Date?

    init(
        companyId: String,
        itemId: String,
        quantity: Decimal,
        comment: String = "",
        createdAt: Date? = nil
    ) {
        self.companyId = companyId
        self.itemId = itemId
        self.quantity = quantity
        self.comment = comment
        self.createdAt = createdAt
    }
}
