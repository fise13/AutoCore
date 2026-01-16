import Foundation

/// Value Object: Quantity
/// Domain Rule: quantity >= 1
struct Quantity: Hashable, Equatable {
    let value: Int
    
    init(_ value: Int) throws {
        guard value >= 1 else {
            throw DomainError.validationError(message: "Количество должно быть >= 1")
        }
        self.value = value
    }
    
    init(unvalidated value: Int) {
        self.value = max(1, value) // Защита от отрицательных значений
    }
    
    func validate() throws {
        guard value >= 1 else {
            throw DomainError.validationError(message: "Количество должно быть >= 1")
        }
    }
}
