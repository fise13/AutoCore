import Foundation

/// Application Layer Errors
enum AppError: LocalizedError {
    case validationError(message: String)
    case databaseError(message: String)
    case importError(message: String)
    case exportError(message: String)
    case logicError(message: String)
    case notFound(message: String)
    case syncError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .validationError(let message):
            return message
        case .databaseError(let message):
            return "Ошибка базы данных: \(message)"
        case .importError(let message):
            return "Ошибка импорта: \(message)"
        case .exportError(let message):
            return "Ошибка экспорта: \(message)"
        case .logicError(let message):
            return "Ошибка логики: \(message)"
        case .notFound(let message):
            return "Не найдено: \(message)"
        case .syncError(let message):
            return message
        }
    }
    
    /// Преобразование Domain Error в App Error
    static func from(_ domainError: DomainError) -> AppError {
        switch domainError {
        case .validationError(let message):
            return .validationError(message: message)
        case .logicError(let message):
            return .logicError(message: message)
        case .notFound(let message):
            return .notFound(message: message)
        }
    }
    
    /// User-facing error message
    var userFacingMessage: String {
        errorDescription ?? "Произошла неизвестная ошибка"
    }
}
