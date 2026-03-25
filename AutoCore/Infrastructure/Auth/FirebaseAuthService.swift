//
//  FirebaseAuthService.swift
//  AutoCore
//
//  Infrastructure Layer: Firebase Authentication
//

import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import AuthenticationServices
import GoogleSignIn
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class FirebaseAuthService: AuthService {
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    private(set) var currentUser: UserEntity?
    private var authStateContinuation: AsyncStream<AuthState>.Continuation?
    
    var authStateStream: AsyncStream<AuthState> {
        AsyncStream { continuation in
            self.authStateContinuation = continuation
            
            // Initial state
            if let user = self.currentUser {
                continuation.yield(.authenticated(user))
            } else if let firebaseUser = self.auth.currentUser {
                continuation.yield(.authenticating)
                Task {
                    do {
                        _ = try await self.loadUserEntity(for: firebaseUser)
                    } catch {
                        continuation.yield(.unauthenticated)
                    }
                }
            } else {
                continuation.yield(.unauthenticated)
            }
            
            // Listen to Auth state changes
            self.auth.addStateDidChangeListener { [weak self] _, user in
                guard let self else { return }
                Task { await self.handleAuthStateChange(user: user) }
            }
        }
    }
    
    // MARK: - Email/password
    
    func signIn(email: String, password: String) async throws -> UserEntity {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            return try await loadUserEntity(for: result.user)
        } catch {
            throw mapAuthError(error)
        }
    }
    
    func signUp(email: String, password: String) async throws -> UserEntity {
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            return try await loadUserEntity(for: result.user)
        } catch {
            throw mapAuthError(error)
        }
    }
    
    // MARK: - Sign in with Apple
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> UserEntity {
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.unknown("Не удалось получить токен Apple ID")
        }
        
        let firebaseCredential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: "", fullName: credential.fullName)
        
        do {
            let result = try await auth.signIn(with: firebaseCredential)
            return try await loadUserEntity(for: result.user)
        } catch {
            throw mapAuthError(error)
        }
    }
    
    // MARK: - Google
    
    func signInWithGoogle() async throws -> UserEntity {
        #if os(iOS)
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.unknown("Не найден Firebase Client ID")
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.unknown("Не удалось получить root view controller")
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        let user = result.user

        guard let idToken = user.idToken?.tokenString else {
            throw AuthError.unknown("Не удалось получить данные от Google")
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: user.accessToken.tokenString
        )

        let authResult = try await auth.signIn(with: credential)
        return try await loadUserEntity(for: authResult.user)
        #elseif os(macOS)
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.unknown("Не найден Firebase Client ID")
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let window = NSApplication.shared.keyWindow
            ?? NSApplication.shared.windows.first(where: { $0.isKeyWindow })
            ?? NSApplication.shared.windows.first(where: { $0.isVisible }) else {
            throw AuthError.unknown("Не удалось получить окно приложения")
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: window)
        let user = result.user

        guard let idToken = user.idToken?.tokenString else {
            throw AuthError.unknown("Не удалось получить данные от Google")
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: user.accessToken.tokenString
        )

        let authResult = try await auth.signIn(with: credential)
        return try await loadUserEntity(for: authResult.user)
        #else
        throw AuthError.unknown("Вход через Google поддерживается только на iOS и macOS")
        #endif
    }
    
    // MARK: - Profile
    
    func updateProfile(displayName: String?) async throws {
        guard let user = auth.currentUser else {
            throw AuthError.invalidCredentials
        }
        
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
        
        // Обновляем документ пользователя в Firestore
        let userRef = db.collection("users").document(user.uid)
        try await userRef.updateData(["name": displayName ?? ""])
        
        // Перезагружаем UserEntity
        _ = try await loadUserEntity(for: user)
    }
    
    // MARK: - Refresh
    
    func refreshCurrentUser() async throws {
        guard let user = auth.currentUser else { return }
        _ = try await user.getIDTokenResult(forcingRefresh: true)
        _ = try await loadUserEntity(for: user)
    }
    
    // MARK: - Sync companyId to Firestore
    
    /// Записывает companyId в users/{uid}, чтобы правила (userDoc().companyId) видели его.
    /// Для старых логинов и после онбординга поле может отсутствовать в документе.
    func syncCompanyIdToFirestoreIfNeeded(companyId: String) async throws {
        let trimmed = companyId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let uid = auth.currentUser?.uid else { return }
        let userRef = db.collection("users").document(uid)
        try await userRef.setData(["companyId": trimmed], merge: true)
    }
    
    // MARK: - Delete account
    
    func deleteAccount() async throws {
        guard let user = auth.currentUser else {
            throw AuthError.userNotFound
        }
        let uid = user.uid
        // 1. Удаляем Firestore users/{uid} (пока пользователь ещё аутентифицирован)
        try await db.collection("users").document(uid).delete()
        // 2. Удаляем Firebase Auth (требует недавнего входа)
        do {
            try await user.delete()
        } catch {
            let mapped = mapAuthError(error)
            if case .unknown(let msg) = mapped, msg.lowercased().contains("recent") {
                throw AuthError.requiresRecentLogin
            }
            throw mapped
        }
        currentUser = nil
        authStateContinuation?.yield(.unauthenticated)
    }
    
    // MARK: - Sign out
    
    func signOut() throws {
        try auth.signOut()
        currentUser = nil
        authStateContinuation?.yield(.unauthenticated)
    }
    
    // MARK: - Private helpers
    
    @discardableResult
    private func loadUserEntity(for user: FirebaseAuth.User) async throws -> UserEntity {
        let docRef = db.collection("users").document(user.uid)
        let snapshot = try await docRef.getDocument()
        
        var userDoc: UserDocument
        if let data = snapshot.data() {
            let name = (data["name"] as? String) ?? (user.displayName ?? "")
            let email = (data["email"] as? String) ?? (user.email ?? "")
            let companyId = data["companyId"] as? String
            let roleRaw = data["role"] as? String ?? UserRole.viewer.rawValue
            let role = UserRole(rawValue: roleRaw) ?? .viewer
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
            
            userDoc = UserDocument(
                id: snapshot.documentID,
                name: name,
                email: email,
                companyId: companyId,
                role: role,
                createdAt: createdAt
            )
        } else {
            // Новый пользователь: создаём документ без companyId. companyId появится после онбординга
            // (assignUserToCompany / joinCompany) или при синхронизации (syncCompanyIdToFirestoreIfNeeded).
            let name = user.displayName ?? ""
            let email = user.email ?? ""
            userDoc = UserDocument(
                id: user.uid,
                name: name,
                email: email,
                companyId: nil,
                role: .viewer,
                createdAt: nil
            )
            var data: [String: Any] = [
                "name": name,
                "email": email,
                "role": userDoc.role.rawValue,
                "createdAt": FieldValue.serverTimestamp()
            ]
            if let companyId = userDoc.companyId {
                data["companyId"] = companyId
            }
            try await docRef.setData(data)
        }
        
        let entity = UserEntity(
            id: user.uid,
            email: userDoc.email,
            displayName: userDoc.name.isEmpty ? nil : userDoc.name,
            provider: .apple,
            role: userDoc.role,
            companyId: userDoc.companyId ?? ""
        )
        currentUser = entity
        authStateContinuation?.yield(.authenticated(entity))
        return entity
    }
    
    private func handleAuthStateChange(user: FirebaseAuth.User?) async {
        if let user {
            do {
                _ = try await loadUserEntity(for: user)
            } catch {
                currentUser = nil
                authStateContinuation?.yield(.unauthenticated)
            }
        } else {
            currentUser = nil
            authStateContinuation?.yield(.unauthenticated)
        }
    }
    
    private func mapAuthError(_ error: Error) -> AuthError {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return .unknown(error.localizedDescription)
        }
        
        switch code {
        case .wrongPassword, .invalidEmail:
            return .invalidCredentials
        case .userNotFound:
            return .userNotFound
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .networkError:
            return .networkError(error.localizedDescription)
        case .userDisabled:
            return .unknown("Аккаунт отключен")
        case .requiresRecentLogin:
            return .requiresRecentLogin
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

