//
//  AuthService.swift
//  AutoCore
//
//  Application Layer: Authentication Service
//  Определяет контракт для аутентификации пользователей
//  Использует AsyncStream вместо Combine для лучшей производительности
//

import Foundation

/// Результат операции аутентификации
enum AuthResult {
    case success(UserEntity)
    case failure(AuthError)
}

/// Ошибки аутентификации (Domain-уровень, не Firebase-specific)
enum AuthError: Error, Equatable {
    case invalidCredentials
    case networkError(String)
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case cancelled
    case notSupported(String)
    case unknown(String)
    
    var localizedMessage: String {
        switch self {
        case .invalidCredentials:
            return "Неверный email или пароль"
        case .networkError(let message):
            return "Ошибка сети: \(message)"
        case .userNotFound:
            return "Пользователь не найден"
        case .emailAlreadyInUse:
            return "Email уже используется"
        case .weakPassword:
            return "Пароль слишком слабый"
        case .cancelled:
            return "Вход отменен"
        case .notSupported(let message):
            return message
        case .unknown(let message):
            return message
        }
    }
}

/// Состояние аутентификации
enum AuthState: Equatable {
    case unauthenticated
    case authenticating
    case authenticated(UserEntity)
}

/// Authentication Service Protocol (Application Layer)
/// Определяет контракт для аутентификации пользователей
/// НЕ зависит от Firebase - может быть заменен на другой провайдер
protocol AuthService: AnyObject {
    /// Текущий авторизованный пользователь (если есть)
    var currentUser: UserEntity? { get }
    
    /// AsyncStream для наблюдения за изменениями состояния аутентификации
    /// Более эффективен чем Combine для изолированных обновлений
    var authStateStream: AsyncStream<AuthState> { get }
    
    /// Вход с email и паролем
    /// - Parameters:
    ///   - email: Email пользователя
    ///   - password: Пароль пользователя
    /// - Returns: Async throwing результат операции
    func signIn(email: String, password: String) async throws -> UserEntity
    
    /// Вход через Google
    /// - Returns: Async throwing результат операции
    func signInWithGoogle() async throws -> UserEntity
    
    /// Выход из системы
    func signOut() throws
}
