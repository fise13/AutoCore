import Foundation

/// Domain entity for warehouse item.
struct InventoryItemEntity: Equatable, Identifiable {
    let id: String
    let companyId: String
    var name: String
    var partNumber: String
    var category: String
    var quantity: Decimal
    var buyPrice: Decimal
    var sellPrice: Decimal
    let createdAt: Date
    var updatedAt: Date

    func validate() throws {
        guard !companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.validationError(message: "companyId обязателен")
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.validationError(message: "Название товара обязательно")
        }
        guard !partNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.validationError(message: "Артикул обязателен")
        }
        guard quantity >= 0 else {
            throw DomainError.validationError(message: "Количество не может быть отрицательным")
        }
        guard buyPrice >= 0 else {
            throw DomainError.validationError(message: "Закупочная цена не может быть отрицательной")
        }
        guard sellPrice >= 0 else {
            throw DomainError.validationError(message: "Цена продажи не может быть отрицательной")
        }
    }

    mutating func applyMovement(type: InventoryMovementEntity.MovementType, quantityDelta: Decimal) throws {
        switch type {
        case .income:
            guard quantityDelta > 0 else {
                throw DomainError.validationError(message: "Для прихода quantityDelta должен быть > 0")
            }
            quantity += quantityDelta
        case .expense:
            guard quantityDelta < 0 else {
                throw DomainError.validationError(message: "Для списания quantityDelta должен быть < 0")
            }
            let nextValue = quantity + quantityDelta
            guard nextValue >= 0 else {
                throw DomainError.logicError(message: "Недостаточно товара на складе")
            }
            quantity = nextValue
        case .adjustment:
            let nextValue = quantity + quantityDelta
            guard nextValue >= 0 else {
                throw DomainError.logicError(message: "Корректировка приводит к отрицательному остатку")
            }
            quantity = nextValue
        }

        updatedAt = Date()
    }
}
