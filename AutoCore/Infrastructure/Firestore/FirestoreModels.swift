//
//  FirestoreModels.swift
//  AutoCore
//
//  Firestore document models (Infrastructure layer)
//

import Foundation
import FirebaseFirestore

// MARK: - User

struct UserDocument {
    let id: String
    let name: String
    let email: String
    let companyId: String?
    let role: UserRole
    let createdAt: Date?
}

// MARK: - Company

struct CompanyDocument {
    let id: String
    let name: String
    let ownerId: String
    let createdAt: Date?
}

// MARK: - Task

enum TaskStatus: String, CaseIterable {
    case open
    case inProgress
    case done
    case cancelled
}

struct TaskDocument {
    let id: String
    let companyId: String
    let title: String
    let description: String
    let assignedTo: String?
    let status: TaskStatus
    let createdAt: Date?
}

// MARK: - Invite

struct InviteDocument {
    let id: String
    let code: String
    let companyId: String
    let role: UserRole
    let createdAt: Date?
    let expiresAt: Date
    let createdBy: String
    let used: Bool
}

// MARK: - Financial Operation

/// Firestore representation of a financial operation.
/// Храним нормализованные данные по операции для синхронизации между macOS и iOS.
struct FinancialOperationDocument {
    let id: String
    let companyId: String
    let type: FinancialOperationEntity.OperationType
    let amount: Decimal
    let paymentMethod: FinancialOperationEntity.PaymentMethod
    let cashReceived: Decimal?
    let changeGiven: Decimal?
    let account: FinancialOperationEntity.Account
    let relatedMotorID: Int64?
    let createdAt: Date
    let createdByUserId: String
    let comment: String
    let source: String
    let details: String
    let category: String?
    let description: String
}

// MARK: - MVP Engine / Operation / Account

struct EngineDocument {
    let id: String
    let companyId: String
    let engineNumber: String
    let model: String
    let volume: String
    let hasGearbox: Bool
    let buyPrice: Decimal
    let sellPrice: Decimal
    let status: EngineItemEntity.EngineStatus
    let createdAt: Date
    let soldAt: Date?
}

struct OperationDocument {
    let id: String
    let companyId: String
    let type: OperationEntity.OperationType
    let amount: Decimal
    let accountId: String
    let category: String?
    let comment: String
    let createdAt: Date
    let relatedEngineId: String?
}

struct AccountDocument {
    let id: String
    let companyId: String
    let name: String
    let type: AccountEntity.AccountType
    let balance: Decimal
}

struct InventoryItemDocument {
    let id: String
    let companyId: String
    let name: String
    let partNumber: String
    let category: String
    let quantity: Decimal
    let buyPrice: Decimal
    let sellPrice: Decimal
    let createdAt: Date
    let updatedAt: Date
}

struct InventoryMovementDocument {
    let id: String
    let companyId: String
    let itemId: String
    let type: InventoryMovementEntity.MovementType
    let quantityDelta: Decimal
    let comment: String
    let createdAt: Date
}


