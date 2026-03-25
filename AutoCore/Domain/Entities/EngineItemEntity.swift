import Foundation

/// MVP Domain Entity: Engine (inventory item).
/// Отдельная сущность от существующего EngineEntity (каталог брендов/кодов).
struct EngineItemEntity: Equatable, Identifiable {
    let id: String
    let companyId: String
    var engineNumber: String
    var model: String
    var volume: String
    var hasGearbox: Bool
    var buyPrice: Decimal
    var sellPrice: Decimal
    var status: EngineStatus
    let createdAt: Date
    var soldAt: Date?

    enum EngineStatus: String, Codable, CaseIterable {
        case stock
        case reserved
        case sold
        case repair
    }

    func validate() throws {
        let number = engineNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !number.isEmpty else {
            throw DomainError.validationError(message: "Номер двигателя обязателен")
        }

        let modelName = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelName.isEmpty else {
            throw DomainError.validationError(message: "Модель двигателя обязательна")
        }

        guard buyPrice >= 0 else {
            throw DomainError.validationError(message: "Закупочная цена не может быть отрицательной")
        }

        guard sellPrice >= 0 else {
            throw DomainError.validationError(message: "Цена продажи не может быть отрицательной")
        }
    }

    mutating func sell(on date: Date) throws {
        guard status != .sold else {
            throw DomainError.logicError(message: "Двигатель уже продан")
        }
        guard date >= createdAt else {
            throw DomainError.validationError(message: "Дата продажи не может быть раньше даты создания")
        }

        status = .sold
        soldAt = date
    }
}
