import Foundation

/// Value Object: Engine Code
struct EngineCode: Hashable, Equatable {
    let value: String
    
    init(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            throw DomainError.validationError(message: "Код двигателя не может быть пустым")
        }
        self.value = trimmed
    }
    
    init(unvalidated value: String) {
        self.value = value.lowercased()
    }
    
    func validate() throws {
        guard !value.isEmpty else {
            throw DomainError.validationError(message: "Код двигателя не может быть пустым")
        }
    }
}
