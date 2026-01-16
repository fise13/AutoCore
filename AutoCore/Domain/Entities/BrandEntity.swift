import Foundation

/// Domain Entity: Brand
struct BrandEntity {
    let id: Int64
    var name: String
    
    func validate() throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validationError(message: "Имя бренда не может быть пустым")
        }
    }
}
