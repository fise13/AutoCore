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

@MainActor
final class AuthViewModel: ObservableObject {
    // MARK: - Published Properties (минимум для UI)
    
    /// Текущее состояние аутентификации
    /// Единственное @Published свойство - используется напрямую в UI
    @Published var authState: AuthState = .unauthenticated
    
    /// Сообщение об ошибке (nil если ошибок нет)
    @Published private(set) var errorMessage: String?
    
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
    
    // MARK: - Initialization
    
    init(authService: AuthService) {
        self.authService = authService
        
        // Инициализируем текущее состояние
        if let currentUser = authService.currentUser {
            self.authState = .authenticated(currentUser)
        } else {
            self.authState = .unauthenticated
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
                    // Очищаем ошибку при успешной аутентификации или выходе
                    if case .authenticated = state {
                        self.errorMessage = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Вход с email и паролем
    func signIn(email: String, password: String) async {
        guard !isSigningIn else { return }
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Введите email и пароль"
            return
        }
        
        errorMessage = nil
        
        do {
            let user = try await authService.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            // Состояние обновится автоматически через authStateStream
        } catch let error as AuthError {
            errorMessage = error.localizedMessage
        } catch {
            errorMessage = "Ошибка входа: \(error.localizedDescription)"
        }
    }
    
    /// Вход через Google
    func signInWithGoogle() async {
        guard !isSigningIn else { return }
        
        errorMessage = nil
        
        do {
            let user = try await authService.signInWithGoogle()
            // Состояние обновится автоматически через authStateStream
        } catch let error as AuthError {
            errorMessage = error.localizedMessage
        } catch {
            errorMessage = "Ошибка входа: \(error.localizedDescription)"
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
}
