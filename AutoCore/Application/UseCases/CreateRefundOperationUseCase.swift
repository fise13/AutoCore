import Foundation

/// Use Case: Create Refund Operation
@MainActor
final class CreateRefundOperationUseCase {
    private let financialOperationRepository: FinancialOperationRepository
    private let eventBus: EventBus
    private let logger: LoggingService
    private let recoveryState: RecoveryState?
    private let currentUser: String
    private let enqueueForSyncUseCase: EnqueueOperationForSyncUseCase?
    
    init(
        financialOperationRepository: FinancialOperationRepository,
        eventBus: EventBus = .shared,
        logger: LoggingService = .shared,
        recoveryState: RecoveryState? = nil,
        currentUser: String,
        enqueueForSyncUseCase: EnqueueOperationForSyncUseCase? = nil
    ) {
        self.financialOperationRepository = financialOperationRepository
        self.eventBus = eventBus
        self.logger = logger
        self.recoveryState = recoveryState
        self.currentUser = currentUser
        self.enqueueForSyncUseCase = enqueueForSyncUseCase
    }
    
    func execute(
        amount: Decimal,
        paymentMethod: FinancialOperationEntity.PaymentMethod,
        cashReceived: Decimal?,
        account: FinancialOperationEntity.Account,
        relatedMotorID: Int64?,
        comment: String = ""
    ) throws -> FinancialOperationEntity {
        try recoveryState?.assertNotInRecoveryMode()
        
        let correlationID = UUIDv7.generateString()
        logger.info("Creating refund operation: amount=\(amount), motorID=\(relatedMotorID?.description ?? "nil")", correlationID: correlationID)
        
        do {
            let changeGiven: Decimal?
            if let cashReceived = cashReceived, paymentMethod == .cash || paymentMethod == .mixed {
                changeGiven = FinancialOperationEntity.calculateChange(cashReceived: cashReceived, amount: amount)
            } else {
                changeGiven = nil
            }
            
            var operation = FinancialOperationEntity(
                id: 0,
                type: .refund,
                amount: amount,
                paymentMethod: paymentMethod,
                cashReceived: cashReceived,
                changeGiven: changeGiven,
                account: account,
                relatedMotorID: relatedMotorID,
                createdAt: Date(),
                createdByUser: currentUser,
                comment: comment,
                source: "Возврат",
                details: relatedMotorID != nil ? "Мотор #\(relatedMotorID!)" : "",
                category: nil,
                description: relatedMotorID != nil ? "Возврат мотора #\(relatedMotorID!)" : "Возврат"
            )
            
            try operation.validate()
            
            let savedOperation = try financialOperationRepository.save(operation)
            
            // Добавляем в outbox для синхронизации с Supabase (асинхронно, не блокируем UI)
            if let enqueueUseCase = enqueueForSyncUseCase {
                Task.detached { [weak self] in
                    do {
                        try await Task { @MainActor in
                            try enqueueUseCase.execute(operation: savedOperation)
                        }.value
                    } catch {
                        self?.logger.error("Failed to enqueue operation for sync", error: error, correlationID: correlationID)
                        // Не пробрасываем ошибку - синхронизация не критична для работы приложения
                    }
                }
            }
            
            let event = FinancialOperationCreatedEvent(
                entityID: savedOperation.id,
                occurredAt: Date(),
                operationID: savedOperation.id,
                type: savedOperation.type,
                amount: savedOperation.amount,
                relatedMotorID: savedOperation.relatedMotorID
            )
            eventBus.publish(event)
            
            logger.info("Refund operation created successfully: \(savedOperation.id)", correlationID: correlationID)
            
            return savedOperation
        } catch let error as DomainError {
            logger.error("Failed to create refund operation", error: error, correlationID: correlationID)
            throw AppError.from(error)
        } catch let error as AppError {
            logger.error("Failed to create refund operation", error: error, correlationID: correlationID)
            throw error
        } catch {
            logger.error("Failed to create refund operation", error: error, correlationID: correlationID)
            throw AppError.databaseError(message: error.localizedDescription)
        }
    }
}
