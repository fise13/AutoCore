import Foundation

/// Use Case: Create Expense Operation
@MainActor
final class CreateExpenseOperationUseCase {
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
        account: FinancialOperationEntity.Account,
        category: String?,
        description: String,
        comment: String = ""
    ) throws -> FinancialOperationEntity {
        try recoveryState?.assertNotInRecoveryMode()
        
        let correlationID = UUIDv7.generateString()
        logger.info("Creating expense operation: amount=\(amount), category=\(category ?? "none")", correlationID: correlationID)
        
        do {
            let operation = FinancialOperationEntity(
                id: 0,
                type: .expense,
                amount: amount,
                paymentMethod: paymentMethod,
                cashReceived: nil,
                changeGiven: nil,
                account: account,
                relatedMotorID: nil,
                createdAt: Date(),
                createdByUser: currentUser,
                comment: comment,
                source: "Расход",
                details: description,
                category: category,
                description: description
            )
            
            try operation.validate()
            
            let savedOperation = try financialOperationRepository.save(operation)
            
            let event = FinancialOperationCreatedEvent(
                entityID: savedOperation.id,
                occurredAt: Date(),
                operationID: savedOperation.id,
                type: savedOperation.type,
                amount: savedOperation.amount,
                relatedMotorID: nil
            )
            eventBus.publish(event)
            
            logger.info("Expense operation created successfully: \(savedOperation.id)", correlationID: correlationID)
            
            return savedOperation
        } catch let error as DomainError {
            logger.error("Failed to create expense operation", error: error, correlationID: correlationID)
            throw AppError.from(error)
        } catch let error as AppError {
            logger.error("Failed to create expense operation", error: error, correlationID: correlationID)
            throw error
        } catch {
            logger.error("Failed to create expense operation", error: error, correlationID: correlationID)
            throw AppError.databaseError(message: error.localizedDescription)
        }
    }
}
