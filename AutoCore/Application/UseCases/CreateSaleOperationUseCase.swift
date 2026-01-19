import Foundation

/// Use Case: Create Sale Operation
@MainActor
final class CreateSaleOperationUseCase {
    private let financialOperationRepository: FinancialOperationRepository
    private let eventBus: EventBus
    private let logger: LoggingService
    private let recoveryState: RecoveryState?
    private let currentUser: String
    
    init(
        financialOperationRepository: FinancialOperationRepository,
        eventBus: EventBus = .shared,
        logger: LoggingService = .shared,
        recoveryState: RecoveryState? = nil,
        currentUser: String
    ) {
        self.financialOperationRepository = financialOperationRepository
        self.eventBus = eventBus
        self.logger = logger
        self.recoveryState = recoveryState
        self.currentUser = currentUser
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
        logger.info("Creating sale operation: amount=\(amount), motorID=\(relatedMotorID?.description ?? "nil")", correlationID: correlationID)
        
        do {
            // Вычисляем сдачу автоматически
            let changeGiven: Decimal?
            if let cashReceived = cashReceived, paymentMethod == .cash || paymentMethod == .mixed {
                changeGiven = FinancialOperationEntity.calculateChange(cashReceived: cashReceived, amount: amount)
            } else {
                changeGiven = nil
            }
            
            var operation = FinancialOperationEntity(
                id: 0,
                type: .sale,
                amount: amount,
                paymentMethod: paymentMethod,
                cashReceived: cashReceived,
                changeGiven: changeGiven,
                account: account,
                relatedMotorID: relatedMotorID,
                createdAt: Date(),
                createdByUser: currentUser,
                comment: comment,
                source: "Продажа",
                details: relatedMotorID != nil ? "Мотор #\(relatedMotorID!)" : "",
                category: nil,
                description: relatedMotorID != nil ? "Продажа мотора #\(relatedMotorID!)" : "Продажа"
            )
            
            // Валидация
            try operation.validate()
            
            // Сохранение
            let savedOperation = try financialOperationRepository.save(operation)
            
            // Публикация события
            let event = FinancialOperationCreatedEvent(
                entityID: savedOperation.id,
                occurredAt: Date(),
                operationID: savedOperation.id,
                type: savedOperation.type,
                amount: savedOperation.amount,
                relatedMotorID: savedOperation.relatedMotorID
            )
            eventBus.publish(event)
            
            logger.info("Sale operation created successfully: \(savedOperation.id)", correlationID: correlationID)
            
            return savedOperation
        } catch let error as DomainError {
            logger.error("Failed to create sale operation", error: error, correlationID: correlationID)
            throw AppError.from(error)
        } catch let error as AppError {
            logger.error("Failed to create sale operation", error: error, correlationID: correlationID)
            throw error
        } catch {
            logger.error("Failed to create sale operation", error: error, correlationID: correlationID)
            throw AppError.databaseError(message: error.localizedDescription)
        }
    }
}
