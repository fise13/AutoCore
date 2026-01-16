import Foundation

/// Domain Layer Errors
enum DomainError: LocalizedError {
    case validationError(message: String)
    case logicError(message: String)
    case notFound(message: String)
    
    var errorDescription: String? {
        switch self {
        case .validationError(let message):
            return "Ошибка валидации: \(message)"
        case .logicError(let message):
            return "Ошибка логики: \(message)"
        case .notFound(let message):
            return "Не найдено: \(message)"
        }
    }
}
