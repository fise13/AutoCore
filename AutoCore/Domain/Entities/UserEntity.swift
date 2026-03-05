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
    case apple = "apple"
    
    var displayName: String {
        switch self {
        case .email: return "Email"
        case .google: return "Google"
        case .apple: return "Apple ID"
        }
    }
}

/// User role in the system (Domain Layer)
/// Роль пользователя в приложении (определяет уровень доступа)
enum UserRole: String, Equatable, Codable {
    case accountant = "accountant"
    case admin = "admin"
    
    var displayName: String {
        switch self {
        case .accountant:
            return "Бухгалтер"
        case .admin:
            return "Администратор"
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
    let role: UserRole
    let companyId: String
    
    init(
        id: String,
        email: String,
        displayName: String?,
        provider: AuthProvider = .email,
        role: UserRole = .accountant,
        companyId: String = "default"
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.provider = provider
        self.role = role
        self.companyId = companyId
    }
}
