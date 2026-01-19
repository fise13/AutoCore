//
//  UserEntity.swift
//  AutoCore
//
//  Domain Entity: User
//  Представляет авторизованного пользователя в системе
//  НЕ ЗНАЕТ про Firebase или другие внешние библиотеки
//

import Foundation

/// Auth Provider (Domain Layer)
/// Провайдер аутентификации пользователя
enum AuthProvider: String, Equatable, Codable {
    case email = "email"
    case google = "google"
    
    var displayName: String {
        switch self {
        case .email: return "Email"
        case .google: return "Google"
        }
    }
}

/// Domain Entity: User
/// Представляет пользователя в системе
struct UserEntity: Equatable {
    let id: String
    let email: String
    let displayName: String?
    let provider: AuthProvider
    
    init(id: String, email: String, displayName: String?, provider: AuthProvider = .email) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.provider = provider
    }
}
