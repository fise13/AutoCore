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
            // Операции нельзя редактировать - только создавать
            throw AppError.validationError(message: "Финансовые операции нельзя редактировать")
        }
        
        let saved = try findByID(operationID) ?? operation
        
        // Асинхронный пуш в Firestore (если сервис доступен и companyId задан)
        if let financialSync = financialSync, !companyId.isEmpty {
            Task { @MainActor in
                do {
                    _ = try await financialSync.pushOperation(saved, companyId: companyId)
                } catch {
                    LoggingService.shared.error("Firestore PUSH error in FinancialOperationRepositoryImpl.save", error: error)
                }
            }
        }
        
        return saved
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
