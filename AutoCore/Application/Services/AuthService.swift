//
//  AuthService.swift
//  AutoCore
//
//  Application Layer: Authentication Service
//  Определяет контракт для аутентификации пользователей
//  Использует AsyncStream вместо Combine для лучшей производительности
//

import Foundation
import AuthenticationServices

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
    case requiresRecentLogin
    case unknown(String)
    
    var localizedMessage: String {
        switch self {
        case .invalidCredentials:
            return "Неверный email или пароль"
        case .networkError:
            return "Не удалось подключиться. Проверьте интернет и попробуйте снова."
        case .userNotFound:
            return "Пользователь не найден"
        case .emailAlreadyInUse:
            return "Email уже используется"
        case .weakPassword:
            return "Пароль слишком слабый"
        case .cancelled:
            return "Вход отменен"
        case .requiresRecentLogin:
            return "Для удаления аккаунта выйдите и войдите снова, затем повторите попытку."
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
    
    /// Регистрация с email и паролем
    func signUp(email: String, password: String) async throws -> UserEntity
    
    /// Вход через Apple ID (Sign in with Apple)
    /// - Parameter credential: ASAuthorizationAppleIDCredential из SignInWithAppleButton
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> UserEntity
    
    /// Вход через Google
    /// - Returns: Async throwing результат операции
    func signInWithGoogle() async throws -> UserEntity
    
    /// Обновление профиля пользователя (например, displayName) для провайдеров, которые это поддерживают.
    /// Реализация по умолчанию может быть no-op или кидать ошибку.
    func updateProfile(displayName: String?) async throws
    
    /// Обновить текущего пользователя из бэкенда (например, после смены companyId/role).
    func refreshCurrentUser() async throws
    
    /// Синхронизировать companyId в документ users/{uid} в Firestore (merge).
    /// Нужно, чтобы правила видели userDoc().companyId; для старых логинов поле может отсутствовать.
    func syncCompanyIdToFirestoreIfNeeded(companyId: String) async throws
    
    /// Удалить аккаунт пользователя (Firestore users/{uid} + Firebase Auth). Требуется недавний вход.
    func deleteAccount() async throws
    
    /// Выход из системы
    func signOut() throws
}

// MARK: - Default Implementations

extension AuthService {
    /// Реализация по умолчанию для Sign in with Apple — провайдер может не поддерживать этот тип входа.
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> UserEntity {
        throw AuthError.unknown("Вход через Apple ID не поддерживается для текущего способа аутентификации")
    }
    
    /// Реализация по умолчанию для обновления профиля — провайдер может не поддерживать обновление профиля.
    func updateProfile(displayName: String?) async throws {
        throw AuthError.unknown("Обновление профиля недоступно для текущего способа аутентификации")
    }
    
    func refreshCurrentUser() async throws {
        // No-op по умолчанию
    }
    
    func syncCompanyIdToFirestoreIfNeeded(companyId: String) async throws {
        // No-op по умолчанию
    }
    
    func deleteAccount() async throws {
        throw AuthError.unknown("Удаление аккаунта недоступно")
    }
}
