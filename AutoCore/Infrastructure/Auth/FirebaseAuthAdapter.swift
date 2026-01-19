//
//  FirebaseAuthAdapter.swift
//  AutoCore
//
//  Infrastructure Layer: Firebase Authentication Adapter
//  Единственная точка контакта с FirebaseAuth SDK
//  Инкапсулирует Firebase, маппит типы в Domain Entity
//

import Foundation
import FirebaseCore
import FirebaseAuth
import AppKit

/// Firebase Authentication Adapter
/// Реализует AuthService используя Firebase Authentication
/// Единственное место, где используется FirebaseAuth SDK
final class FirebaseAuthAdapter: NSObject, AuthService {
    
    private let auth: Auth
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    // AsyncStream для auth state (более эффективен чем Combine)
    private let authStateContinuation: AsyncStream<AuthState>.Continuation
    let authStateStream: AsyncStream<AuthState>
    
    override init() {
        // Убеждаемся, что FirebaseApp уже настроен
        guard FirebaseApp.app() != nil else {
            fatalError("FirebaseApp must be configured before creating FirebaseAuthAdapter. Call FirebaseApp.configure() in AutoCoreApp.init()")
        }
        
        self.auth = Auth.auth()
        
        // Создаем AsyncStream для auth state
        var continuation: AsyncStream<AuthState>.Continuation!
        self.authStateStream = AsyncStream { continuation = $0 }
        self.authStateContinuation = continuation
        
        super.init()
        
        // Инициализируем начальное состояние
        let initialState: AuthState
        if let firebaseUser = auth.currentUser {
            initialState = .authenticated(mapFirebaseUserToEntity(firebaseUser))
        } else {
            initialState = .unauthenticated
        }
        authStateContinuation.yield(initialState)
        
        // Начинаем наблюдение за изменениями состояния
        startObservingAuthState()
    }
    
    deinit {
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
        }
        authStateContinuation.finish()
    }
    
    // MARK: - AuthService Protocol
    
    var currentUser: UserEntity? {
        guard let firebaseUser = auth.currentUser else { return nil }
        return mapFirebaseUserToEntity(firebaseUser)
    }
    
    func signIn(email: String, password: String) async throws -> UserEntity {
        // Устанавливаем состояние authenticating
        authStateContinuation.yield(.authenticating)
        
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            let userEntity = mapFirebaseUserToEntity(result.user)
            // Состояние обновится автоматически через listener
            return userEntity
        } catch {
            // Возвращаемся в unauthenticated при ошибке
            authStateContinuation.yield(.unauthenticated)
            throw mapFirebaseError(error)
        }
    }
    
    func signInWithGoogle() async throws -> UserEntity {
        // TODO: Реализовать Google Sign-In для macOS
        // Для этого нужно добавить GoogleSignIn SDK
        throw AuthError.unknown("Google Sign-In для macOS требует дополнительной настройки")
    }
    
    func signOut() throws {
        do {
            try auth.signOut()
            // Состояние обновится автоматически через listener
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Private Helpers
    
    private func startObservingAuthState() {
        // Отписываемся от предыдущего listener, если есть
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
        }
        
        // Подписываемся на изменения состояния аутентификации
        authStateListener = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }
            
            let authState: AuthState
            if let firebaseUser = firebaseUser {
                authState = .authenticated(self.mapFirebaseUserToEntity(firebaseUser))
            } else {
                authState = .unauthenticated
            }
            
            // Отправляем новое состояние через AsyncStream
            self.authStateContinuation.yield(authState)
        }
    }
    
    /// Маппинг Firebase User → Domain UserEntity
    private func mapFirebaseUserToEntity(_ firebaseUser: User) -> UserEntity {
        // Определяем provider по metadata
        let provider: AuthProvider
        if let providerData = firebaseUser.providerData.first(where: { $0.providerID == "google.com" }) {
            provider = .google
        } else {
            provider = .email
        }
        
        return UserEntity(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            displayName: firebaseUser.displayName,
            provider: provider
        )
    }
    
    /// Маппинг Firebase Error → Domain AuthError
    private func mapFirebaseError(_ error: Error) -> AuthError {
        guard let authError = error as NSError? else {
            return .unknown(error.localizedDescription)
        }
        
        // Проверяем на ошибку keychain
        let errorMessage = authError.localizedDescription.lowercased()
        if errorMessage.contains("keychain") || errorMessage.contains("nslocalized") {
            return .unknown("Ошибка доступа к хранилищу учетных данных. Убедитесь, что приложение имеет необходимые разрешения.")
        }
        
        switch AuthErrorCode(rawValue: authError.code) {
        case .wrongPassword, .invalidEmail, .invalidCredential:
            return .invalidCredentials
        case .userNotFound:
            return .userNotFound
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .networkError:
            return .networkError(authError.localizedDescription)
        case .operationNotAllowed:
            return .unknown("Операция не разрешена. Проверьте настройки Firebase.")
        default:
            // Проверяем на отмену
            if authError.code == 17020 { // User cancelled
                return .cancelled
            }
            return .unknown(authError.localizedDescription)
        }
    }
}
