import Foundation

/// MVP Domain Entity: account balance.
struct AccountEntity: Equatable, Identifiable {
    let id: String
    let companyId: String
    var name: String
    let type: AccountType
    var balance: Decimal

    enum AccountType: String, Codable, CaseIterable {
        case cash
        case kaspi
        case bank
    }

    func validate() throws {
        guard !companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.validationError(message: "companyId обязателен")
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.validationError(message: "Название счета обязательно")
        }
    }

    mutating func apply(operationType: OperationEntity.OperationType, amount: Decimal) throws {
        guard amount > 0 else {
            throw DomainError.validationError(message: "Сумма должна быть больше нуля")
        }

        switch operationType {
        case .income:
            balance += amount
        case .expense:
            balance -= amount
        case .transfer:
            balance -= amount
        }
    }
}
