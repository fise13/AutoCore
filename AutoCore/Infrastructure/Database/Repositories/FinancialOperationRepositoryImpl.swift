import Foundation

/// Infrastructure implementation of FinancialOperationRepository
final class FinancialOperationRepositoryImpl: FinancialOperationRepository {
    private let database: DatabaseService
    private let financialSync: FinancialSyncService?
    private let companyId: String
    
    init(
        database: DatabaseService,
        companyId: String = "default",
        financialSync: FinancialSyncService? = nil
    ) {
        self.database = database
        self.companyId = companyId
        self.financialSync = financialSync ?? FirestoreFinancialSyncService()
    }
    
    func save(_ operation: FinancialOperationEntity) throws -> FinancialOperationEntity {
        let operationID: Int64
        
        if operation.id == 0 {
            // Create new
            operationID = try database.insertFinancialOperation(
                type: operation.type.rawValue,
                amount: operation.amount,
                paymentMethod: operation.paymentMethod.rawValue,
                cashReceived: operation.cashReceived,
                changeGiven: operation.changeGiven,
                account: operation.account.rawValue,
                relatedMotorID: operation.relatedMotorID,
                createdAt: operation.createdAt,
                createdByUser: operation.createdByUser,
                comment: operation.comment,
                source: operation.source,
                details: operation.details,
                category: operation.category,
                description: operation.description,
                companyId: companyId
            )
        } else {
            return try update(operation)
        }
        
        let saved = try findByID(operationID) ?? operation
        
        // Асинхронный пуш в Firestore (если сервис доступен и companyId задан)
        if let financialSync = financialSync, !companyId.isEmpty {
            Task {
                do {
                    let cloudId = try await financialSync.pushOperation(saved, companyId: companyId)
                    if !cloudId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        try database.setFinancialOperationCloudDocumentId(id: saved.id, cloudDocumentId: cloudId)
                    }
                } catch {
                    LoggingService.shared.error("Firestore PUSH error in FinancialOperationRepositoryImpl.save", error: error)
                }
            }
        }
        
        return saved
    }

    func update(_ operation: FinancialOperationEntity) throws -> FinancialOperationEntity {
        guard operation.id > 0 else {
            throw AppError.validationError(message: "Нельзя обновить операцию без id")
        }
        try database.updateFinancialOperation(
            id: operation.id,
            amount: operation.amount,
            account: operation.account.rawValue,
            category: operation.category,
            description: operation.description,
            comment: operation.comment
        )
        let updated = try findByID(operation.id) ?? operation
        if let financialSync = financialSync, !companyId.isEmpty {
            Task {
                guard let cloudId = updated.cloudDocumentId, !cloudId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    LoggingService.shared.info("Firestore UPDATE skipped: operation id=\(updated.id) has no cloudDocumentId yet")
                    return
                }
                do {
                    try await financialSync.updateOperation(
                        documentId: cloudId,
                        companyId: companyId,
                        fields: [
                            "amount": NSDecimalNumber(decimal: updated.amount).doubleValue,
                            "account": updated.account.rawValue,
                            "category": updated.category ?? "",
                            "description": updated.description,
                            "details": updated.description,
                            "comment": updated.comment
                        ]
                    )
                } catch {
                    LoggingService.shared.error("Firestore UPDATE error in FinancialOperationRepositoryImpl.update", error: error)
                }
            }
        }
        return updated
    }

    func delete(_ operation: FinancialOperationEntity) throws {
        guard operation.id > 0 else {
            throw AppError.validationError(message: "Нельзя удалить операцию без id")
        }
        try database.deleteFinancialOperation(id: operation.id)
        if let financialSync = financialSync, !companyId.isEmpty {
            Task {
                do {
                    try await financialSync.deleteOperation(operation, companyId: companyId)
                } catch {
                    LoggingService.shared.error("Firestore DELETE error in FinancialOperationRepositoryImpl.delete", error: error)
                }
            }
        }
    }

    func deleteAll(companyId: String?) throws {
        let cid = companyId ?? self.companyId
        try database.clearFinancialOperations(companyId: cid)
        if let financialSync = financialSync, !cid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task { @MainActor in
                do {
                    let cloudOps = try await financialSync.pullOperations(companyId: cid, since: nil)
                    for op in cloudOps {
                        guard let docId = op.cloudDocumentId else { continue }
                        do {
                            try await financialSync.deleteOperation(documentId: docId, companyId: cid)
                        } catch {
                            LoggingService.shared.error("Firestore DELETE ALL: failed to remove docId=\(docId)", error: error)
                        }
                    }
                } catch {
                    LoggingService.shared.error("Firestore DELETE ALL: pull failed", error: error)
                }
            }
        }
    }
    
    func findByID(_ id: Int64) throws -> FinancialOperationEntity? {
        let cid = companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : companyId
        guard let dbOperation = try database.fetchFinancialOperation(id: id, companyId: cid) else {
            return nil
        }

        return try mapToEntity(dbOperation)
    }
    
    func findAll(filter: FinancialOperationFilter) throws -> [FinancialOperationEntity] {
        var dbFilter = DatabaseService.FinancialOperationFilter()
        dbFilter.type = filter.type
        dbFilter.account = filter.account
        dbFilter.relatedMotorID = filter.relatedMotorID
        dbFilter.fromDate = filter.fromDate
        dbFilter.toDate = filter.toDate
        dbFilter.limit = filter.limit
        dbFilter.offset = filter.offset
        let cid = companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "default" : companyId
        dbFilter.companyId = cid
        
        let operations = try database.fetchFinancialOperations(filter: dbFilter)
        return try operations.map { try mapToEntity($0) }
    }
    
    func calculateCashBalance(account: FinancialOperationEntity.Account, upToDate: Date?) throws -> Decimal {
        let cid = companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : companyId
        return try database.calculateCashBalance(account: account.rawValue, upToDate: upToDate, companyId: cid)
    }
    
    private func mapToEntity(_ operation: DatabaseService.FinancialOperation) throws -> FinancialOperationEntity {
        guard let type = FinancialOperationEntity.OperationType(rawValue: operation.type),
              let paymentMethod = FinancialOperationEntity.PaymentMethod(rawValue: operation.paymentMethod),
              let account = FinancialOperationEntity.Account(rawValue: operation.account) else {
            throw AppError.validationError(message: "Неверный формат данных финансовой операции")
        }
        
        return FinancialOperationEntity(
            id: operation.id,
            cloudDocumentId: operation.cloudDocumentId,
            type: type,
            amount: operation.amount,
            paymentMethod: paymentMethod,
            cashReceived: operation.cashReceived,
            changeGiven: operation.changeGiven,
            account: account,
            relatedMotorID: operation.relatedMotorID,
            createdAt: operation.createdAt,
            createdByUser: operation.createdByUser,
            comment: operation.comment,
            source: operation.source,
            details: operation.details,
            category: operation.category,
            description: operation.description
        )
    }
}
