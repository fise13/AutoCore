import Foundation

/// MVP Domain Entity: Financial operation for company accounting.
struct OperationEntity: Equatable, Identifiable {
    let id: String
    let companyId: String
    let type: OperationType
    let amount: Decimal
    let accountId: String
    let category: String?
    let comment: String
    let createdAt: Date
    let relatedEngineId: String?

    enum OperationType: String, Codable, CaseIterable {
        case income
        case expense
        case transfer
    }

    func validate() throws {
        guard !companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.validationError(message: "companyId обязателен")
        }

        guard !accountId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.validationError(message: "accountId обязателен")
        }

        guard amount > 0 else {
            throw DomainError.validationError(message: "Сумма операции должна быть больше нуля")
        }
    }
}
