//
//  CloudKitAuthService.swift
//  AutoCore
//
//  Infrastructure: аутентификация через Sign in with Apple и роли в CloudKit
//

import Foundation
import AuthenticationServices
import CloudKit

/// Реализация AuthService: Sign in with Apple + роль из CloudKit
@MainActor
final class CloudKitAuthService: NSObject, AuthService {
    
    private let container: CKContainer
    private let privateDB: CKDatabase
    private let publicDB: CKDatabase
    
    private(set) var currentUser: UserEntity?
    private var authStateContinuation: AsyncStream<AuthState>.Continuation?
    
    var authStateStream: AsyncStream<AuthState> {
        AsyncStream { continuation in
            authStateContinuation = continuation
            if let user = currentUser {
                continuation.yield(.authenticated(user))
            } else {
                continuation.yield(.unauthenticated)
            }
            continuation.onTermination = { @Sendable _ in }
        }
    }
    
    override init() {
        self.container = CKContainer(identifier: "iCloud.fise.AutoCore")
        self.privateDB = container.privateCloudDatabase
        self.publicDB = container.publicCloudDatabase
        super.init()
        restoreSession()
    }
    
    // MARK: - AuthService (Apple ID-фокус)
    
    /// Вход по email/паролю не поддерживается для CloudKitAuthService
    func signIn(email: String, password: String) async throws -> UserEntity {
        throw AuthError.unknown("Вход по email и паролю недоступен для авторизации через Apple ID")
    }
    
    /// Вход через Google не поддерживается для CloudKitAuthService
    func signInWithGoogle() async throws -> UserEntity {
        throw AuthError.unknown("Вход через Google недоступен для авторизации через Apple ID")
    }
    
    /// Вход через Sign in with Apple
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> UserEntity {
        authStateContinuation?.yield(.authenticating)
        do {
            let user = try await userEntity(from: credential)
            currentUser = user
            saveSession(userId: user.id, email: user.email, displayName: user.displayName)
            authStateContinuation?.yield(.authenticated(user))
            return user
        } catch {
            authStateContinuation?.yield(.unauthenticated)
            throw error
        }
    }
    
    func updateProfile(displayName: String?) async throws {
        guard currentUser != nil else { throw AuthError.invalidCredentials }
        // Для Apple можно обновить только локальный кэш; CloudKit UserRole не хранит displayName
        if let id = UserDefaults.standard.string(forKey: "apple_user_id") {
            UserDefaults.standard.set(displayName, forKey: "apple_display_name_\(id)")
        }
        // Перезагрузить текущего пользователя с новым displayName
        if let id = currentUser?.id {
            let email = UserDefaults.standard.string(forKey: "apple_email_\(id)") ?? ""
            let (role, companyId) = try await fetchRole(userId: id, email: email.isEmpty ? nil : email)
            let name = displayName ?? UserDefaults.standard.string(forKey: "apple_display_name_\(id)")
            currentUser = UserEntity(id: id, email: email, displayName: name, provider: .apple, role: role, companyId: companyId)
            authStateContinuation?.yield(.authenticated(currentUser!))
        }
    }
    
    func signOut() throws {
        let userId = currentUser?.id
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "apple_user_id")
        if let id = userId {
            UserDefaults.standard.removeObject(forKey: "apple_email_\(id)")
            UserDefaults.standard.removeObject(forKey: "apple_display_name_\(id)")
        }
        authStateContinuation?.yield(.unauthenticated)
    }
    
    // MARK: - Private
    
    private func userEntity(from credential: ASAuthorizationAppleIDCredential) async throws -> UserEntity {
        let userId = credential.user
        let email = credential.email ?? UserDefaults.standard.string(forKey: "apple_email_\(userId)") ?? ""
        let fullName = credential.fullName
        let displayName: String? = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .nilIfEmpty
            ?? UserDefaults.standard.string(forKey: "apple_display_name_\(userId)")
        
        if !email.isEmpty {
            UserDefaults.standard.set(email, forKey: "apple_email_\(userId)")
        }
        if let name = displayName {
            UserDefaults.standard.set(name, forKey: "apple_display_name_\(userId)")
        }
        
        let (role, companyId) = try await fetchRole(userId: userId, email: email.isEmpty ? nil : email)
        return UserEntity(id: userId, email: email, displayName: displayName, provider: .apple, role: role, companyId: companyId)
    }
    
    /// Загружает роль и companyId из CloudKit. По умолчанию (.accountant, "default")
    private func fetchRole(userId: String, email: String?) async throws -> (UserRole, String) {
        // 1) По email в Public Database
        if let email = email, !email.isEmpty {
            let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let recordID = CKRecord.ID(recordName: normalizedEmail, zoneID: CKRecordZone.default().zoneID)
            do {
                let record = try await publicDB.record(for: recordID)
                if let roleRaw = record["role"] as? String, let role = UserRole(rawValue: roleRaw) {
                    let companyId = record["companyId"] as? String ?? "default"
                    return (role, companyId)
                }
            } catch let error as CKError where error.code == .unknownItem { }
            catch { }
        }
        // 2) По userId в Private Database
        let recordID = CKRecord.ID(recordName: "UserRole-\(userId)")
        do {
            let record = try await privateDB.record(for: recordID)
            if let roleRaw = record["role"] as? String, let role = UserRole(rawValue: roleRaw) {
                let companyId = record["companyId"] as? String ?? "default"
                return (role, companyId)
            }
        } catch let error as CKError where error.code == .unknownItem { }
        return (.accountant, "default")
    }
    
    private func saveSession(userId: String, email: String, displayName: String?) {
        UserDefaults.standard.set(userId, forKey: "apple_user_id")
        UserDefaults.standard.set(email, forKey: "apple_email_\(userId)")
        if let name = displayName {
            UserDefaults.standard.set(name, forKey: "apple_display_name_\(userId)")
        }
    }
    
    private func restoreSession() {
        guard let userId = UserDefaults.standard.string(forKey: "apple_user_id"), !userId.isEmpty else {
            authStateContinuation?.yield(.unauthenticated)
            return
        }
        Task {
            do {
                let email = UserDefaults.standard.string(forKey: "apple_email_\(userId)") ?? ""
                let (role, companyId) = try await fetchRole(userId: userId, email: email.isEmpty ? nil : email)
                let displayName = UserDefaults.standard.string(forKey: "apple_display_name_\(userId)")
                let user = UserEntity(id: userId, email: email, displayName: displayName, provider: .apple, role: role, companyId: companyId)
                await MainActor.run {
                    self.currentUser = user
                    self.authStateContinuation?.yield(.authenticated(user))
                }
            } catch {
                await MainActor.run {
                    self.currentUser = nil
                    self.authStateContinuation?.yield(.unauthenticated)
                }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
