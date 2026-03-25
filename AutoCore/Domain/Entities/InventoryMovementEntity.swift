import Foundation

/// Domain entity for inventory movement history.
struct InventoryMovementEntity: Equatable, Identifiable {
    let id: String
    let companyId: String
    let itemId: String
    let type: MovementType
    let quantityDelta: Decimal
    let comment: String
    let createdAt: Date

    enum MovementType: String, Codable, CaseIterable {
        case income
        case expense
        case adjustment
    }

    func validate() throws {
        guard !companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.validationError(message: "companyId обязателен")
        }
        guard !itemId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.validationError(message: "itemId обязателен")
        }

        switch type {
        case .income:
            guard quantityDelta > 0 else {
                throw DomainError.validationError(message: "Для прихода quantityDelta должен быть > 0")
            }
        case .expense:
            guard quantityDelta < 0 else {
                throw DomainError.validationError(message: "Для списания quantityDelta должен быть < 0")
            }
        case .adjustment:
            guard quantityDelta != 0 else {
                throw DomainError.validationError(message: "Для корректировки quantityDelta не должен быть равен 0")
            }
        }
    }
}
