import Foundation

/// Value Object: Serial Code
struct SerialCode: Hashable, Equatable {
    let value: String
    
    init(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validationError(message: "Серийный номер не может быть пустым")
        }
        self.value = trimmed
    }
    
    init(unvalidated value: String) {
        self.value = value
    }
}
