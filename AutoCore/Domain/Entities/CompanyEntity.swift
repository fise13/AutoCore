import Foundation

/// MVP Domain Entity: company aggregate root for ownership boundaries.
struct CompanyEntity: Equatable, Identifiable {
    let id: String
    var name: String
    let ownerId: String
    let createdAt: Date?

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.validationError(message: "Название компании обязательно")
        }
        guard !ownerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.validationError(message: "ownerId обязателен")
        }
    }
}
