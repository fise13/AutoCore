import Foundation

/// Use Case: Create Income Operation (приход — внесение денег в кассу/Каспи)
@MainActor
final class CreateIncomeOperationUseCase {
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
        description: String = "",
        comment: String = ""
    ) throws -> FinancialOperationEntity {
        try recoveryState?.assertNotInRecoveryMode()
        
        let correlationID = UUIDv7.generateString()
        logger.info("Creating income operation: amount=\(amount), account=\(account.rawValue)", correlationID: correlationID)
        
        do {
            let operation = FinancialOperationEntity(
                id: 0,
                type: .income,
                amount: amount,
                paymentMethod: paymentMethod,
                cashReceived: nil,
                changeGiven: nil,
                account: account,
                relatedMotorID: nil,
                createdAt: Date(),
                createdByUser: currentUser,
                comment: comment,
                source: "Приход",
                details: description.isEmpty ? "Внесение средств" : description,
                category: nil,
                description: description.isEmpty ? "Внесение средств" : description
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
            
            logger.info("Income operation created successfully: \(savedOperation.id)", correlationID: correlationID)
            
            return savedOperation
        } catch let error as DomainError {
            logger.error("Failed to create income operation", error: error, correlationID: correlationID)
            throw AppError.from(error)
        } catch let error as AppError {
            logger.error("Failed to create income operation", error: error, correlationID: correlationID)
            throw error
        } catch {
            logger.error("Failed to create income operation", error: error, correlationID: correlationID)
            throw AppError.databaseError(message: error.localizedDescription)
        }
    }
}
