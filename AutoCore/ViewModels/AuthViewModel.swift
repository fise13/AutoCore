//
//  AuthViewModel.swift
//  AutoCore
//
//  Presentation Layer: Authentication ViewModel
//  Управляет состоянием аутентификации для UI
//  НЕ ЗНАЕТ про Firebase - работает только с AuthService protocol
//  Использует AsyncStream вместо Combine для лучшей производительности
//

import Foundation
import Combine
import SwiftUI
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {
    // MARK: - Published Properties (минимум для UI)
    
    /// Текущее состояние аутентификации
    /// Единственное @Published свойство - используется напрямую в UI
    @Published var authState: AuthState = .loading

    /// Показывает, что в данный момент идёт вход через Apple/Google (для блокировки UI)
    @Published private(set) var isProviderSigningIn = false

    /// Сообщение об ошибке (nil если ошибок нет)
    @Published private(set) var errorMessage: String?

    /// Доступна ли повторная попытка (для сетевых и временных ошибок)
    var canRetry: Bool { lastRetryAction != nil }
    
    // MARK: - Computed Properties (без @Published для производительности)
    
    /// Текущий авторизованный пользователь (если есть)
    var currentUser: UserEntity? {
        if case .authenticated(let user) = authState {
            return user
        }
        return nil
    }
    
    /// Флаг выполнения операции входа
    var isSigningIn: Bool {
        if case .authenticating = authState {
            return true
        }
        return false
    }
    
    // MARK: - Private Properties
    
    private let authService: AuthService
    private var authStateTask: Task<Void, Never>?
    private var lastRetryAction: (() async -> Void)?
    
    // MARK: - Initialization
    
    init(authService: AuthService) {
        self.authService = authService
        
        // На старте всегда показываем loading/splash до подтверждения состояния от Auth stream.
        if let currentUser = authService.currentUser {
            self.authState = .authenticated(currentUser)
        } else {
            self.authState = .loading
        }
        
        // Подписываемся на изменения состояния аутентификации через AsyncStream
        startObservingAuthState()
    }
    
    deinit {
        authStateTask?.cancel()
    }
    
    // MARK: - Private Methods
    
    private func startObservingAuthState() {
        authStateTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await state in authService.authStateStream {
                // Обновляем состояние на главном потоке
                await MainActor.run {
                    self.authState = state
                    if case .authenticated = state {
                        self.errorMessage = nil
                        self.lastRetryAction = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Вход через Google
    func signInWithGoogle() async {
        guard !isProviderSigningIn else { return }
        errorMessage = nil
        isProviderSigningIn = true
        lastRetryAction = { [weak self] in await self?.signInWithGoogle() }
        defer { isProviderSigningIn = false }
        do {
            _ = try await authService.signInWithGoogle()
        } catch let error as AuthError {
            if case .cancelled = error { errorMessage = nil } else { errorMessage = error.localizedMessage }
        } catch {
            errorMessage = "Ошибка входа через Google: \(error.localizedDescription)"
        }
    }
    
    /// Вход по email и паролю
    func signIn(email: String, password: String) async {
        errorMessage = nil
        let email = email, password = password
        lastRetryAction = { [weak self] in await self?.signIn(email: email, password: password) }
        do {
            _ = try await authService.signIn(email: email, password: password)
            // Состояние обновится автоматически через authStateStream
        } catch let error as AuthError {
            errorMessage = error.localizedMessage
        } catch {
            errorMessage = "Ошибка входа: \(error.localizedDescription)"
        }
    }
    
    /// Регистрация по email и паролю
    func signUp(email: String, password: String) async {
        errorMessage = nil
        let email = email, password = password
        lastRetryAction = { [weak self] in await self?.signUp(email: email, password: password) }
        do {
            _ = try await authService.signUp(email: email, password: password)
            // Состояние обновится автоматически через authStateStream
        } catch let error as AuthError {
            errorMessage = error.localizedMessage
        } catch {
            errorMessage = "Ошибка регистрации: \(error.localizedDescription)"
        }
    }
    
    /// Вход через Apple ID (Sign in with Apple)
    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async {
        guard !isProviderSigningIn else { return }
        errorMessage = nil
        isProviderSigningIn = true
        let nonce = rawNonce
        lastRetryAction = { [weak self] in await self?.handleAppleSignIn(credential: credential, rawNonce: nonce) }
        defer { isProviderSigningIn = false }
        do {
            _ = try await authService.signInWithApple(credential: credential, rawNonce: nonce)
        } catch let error as AuthError {
            errorMessage = error.localizedMessage
        } catch {
            errorMessage = "Ошибка входа через Apple ID: \(error.localizedDescription)"
        }
    }
    
    /// Выход из системы
    func signOut() {
        do {
            try authService.signOut()
            errorMessage = nil
            // Состояние обновится автоматически через authStateStream
        } catch let error as AuthError {
            errorMessage = error.localizedMessage
        } catch {
            errorMessage = "Ошибка выхода: \(error.localizedDescription)"
        }
    }
    
    /// Очистка сообщения об ошибке
    func clearError() {
        errorMessage = nil
    }

    /// Красиво отображает ошибку входа через Apple ID, без техничных кодов.
    func setAppleSignInError(_ error: Error) {
        if let appleError = error as? ASAuthorizationError {
            switch appleError.code {
            case .canceled:
                errorMessage = "Вход через Apple был отменён."
            case .failed, .unknown:
                errorMessage = "Не удалось выполнить вход через Apple. Попробуйте ещё раз."
            case .invalidResponse, .notHandled:
                errorMessage = "Ответ Apple недействителен. Попробуйте позже."
            case .notInteractive:
                errorMessage = "Вход через Apple недоступен в текущем режиме. Попробуйте открыть приложение напрямую."
            @unknown default:
                errorMessage = "Ошибка входа через Apple ID. Попробуйте ещё раз."
            }
        } else {
            errorMessage = "Ошибка входа через Apple ID: \(error.localizedDescription)"
        }
    }

    /// Повторить последнюю неудачную попытку входа/регистрации
    func retryLastAction() async {
        await lastRetryAction?()
    }

    /// Установка сообщения об ошибке из UI-слоя
    func setError(_ message: String) {
        errorMessage = message
    }

    /// Обновить текущего пользователя из бэкенда (после смены companyId/role в onboarding).
    func refreshCurrentUser() async {
        do {
            try await authService.refreshCurrentUser()
        } catch {
            errorMessage = "Ошибка обновления: \(error.localizedDescription)"
        }
    }
    
    /// Синхронизировать companyId в Firestore users/{uid}, чтобы правила видели актуальный профиль (в т.ч. для старых логинов).
    func syncCompanyIdToFirestoreIfNeeded(companyId: String) async {
        guard !companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try await authService.syncCompanyIdToFirestoreIfNeeded(companyId: companyId)
        } catch {
            // Не блокируем UI; склад/другие запросы могут потом синхронизировать при первом обращении.
        }
    }

    /// Удалить аккаунт пользователя (Firestore + Firebase Auth).
    func deleteAccount() async {
        do {
            try await authService.deleteAccount()
        } catch let error as AuthError {
            errorMessage = error.localizedMessage
        } catch {
            errorMessage = "Ошибка удаления: \(error.localizedDescription)"
        }
    }

    /// Обновление отображаемого имени пользователя (для провайдеров, которые это поддерживают).
    func updateProfile(displayName: String?) async {
        errorMessage = nil
        do {
            try await authService.updateProfile(displayName: displayName)
        } catch let error as AuthError {
            errorMessage = error.localizedMessage
        } catch {
            errorMessage = "Ошибка обновления профиля: \(error.localizedDescription)"
        }
    }
    
    /// Изменить пароль текущего email-аккаунта. Возвращает читаемое сообщение об ошибке (или nil, если успешно).
    func changePassword(currentPassword: String, newPassword: String) async -> String? {
        do {
            try await authService.changePassword(currentPassword: currentPassword, newPassword: newPassword)
            return nil
        } catch let error as AuthError {
            return error.localizedMessage
        } catch {
            return error.localizedDescription
        }
    }
    
    /// Отправить письмо для сброса пароля. Возвращает читаемое сообщение об ошибке (или nil, если письмо отправлено).
    func sendPasswordReset(email: String) async -> String? {
        do {
            try await authService.sendPasswordReset(email: email)
            return nil
        } catch let error as AuthError {
            return error.localizedMessage
        } catch {
            return error.localizedDescription
        }
    }
}
