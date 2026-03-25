import Foundation

/// Use Case: Unsell Motor with Financial Operation (Refund)
/// Возвращает мотор в наличие и создаёт финансовую операцию возврата в ОДНОЙ транзакции
@MainActor
final class UnsellMotorWithFinancialOperationUseCase {
    private let database: DatabaseService
    private let motorRepository: MotorRepository
    private let eventBus: EventBus
    private let logger: LoggingService
    private let recoveryState: RecoveryState?
    private let currentUser: String
    private let companyId: String
    
    init(
        database: DatabaseService,
        motorRepository: MotorRepository,
        eventBus: EventBus = .shared,
        logger: LoggingService = .shared,
        recoveryState: RecoveryState? = nil,
        currentUser: String,
        companyId: String
    ) {
        self.database = database
        self.motorRepository = motorRepository
        self.eventBus = eventBus
        self.logger = logger
        self.recoveryState = recoveryState
        self.currentUser = currentUser
        self.companyId = companyId
    }
    
    func execute(
        motorID: Int64,
        refundAmount: Decimal,
        paymentMethod: FinancialOperationEntity.PaymentMethod,
        cashReceived: Decimal?,
        account: FinancialOperationEntity.Account,
        comment: String = ""
    ) async throws -> (motor: MotorEntity, operation: FinancialOperationEntity) {
        try recoveryState?.assertNotInRecoveryMode()
        
        let correlationID = UUIDv7.generateString()
        logger.info("Unselling motor with refund operation: motorID=\(motorID), amount=\(refundAmount)", correlationID: correlationID)
        
        do {
            // Загружаем мотор
            guard var motor = try motorRepository.findByID(motorID) else {
                throw AppError.notFound(message: "Мотор с ID \(motorID) не найден")
            }
            
            guard motor.isSold else {
                throw AppError.logicError(message: "Мотор не был продан")
            }
            
            // Domain Rule: возвращаем мотор в наличие
            try motor.unsell()
            
            // Вычисляем сдачу автоматически
            let changeGiven: Decimal?
            if let cashReceived = cashReceived, paymentMethod == .cash || paymentMethod == .mixed {
                changeGiven = FinancialOperationEntity.calculateChange(cashReceived: cashReceived, amount: refundAmount)
            } else {
                changeGiven = nil
            }
            
            // Валидация финансовой операции (создаём временную для валидации)
            let tempOperation = FinancialOperationEntity(
                id: 0,
                type: .refund,
                amount: refundAmount,
                paymentMethod: paymentMethod,
                cashReceived: cashReceived,
                changeGiven: changeGiven,
                account: account,
                relatedMotorID: motorID,
                createdAt: Date(),
                createdByUser: currentUser,
                comment: comment,
                source: "",
                details: "",
                category: nil,
                description: ""
            )
            try tempOperation.validate()
            
            // Выполняем обе операции в одной транзакции через DatabaseService
            var savedMotor: MotorEntity!
            var savedOperation: FinancialOperationEntity!
            
            try database.inTransaction {
                // Сохраняем мотор напрямую через database (unlocked версия для использования внутри транзакции)
                try database.updateMotorUnlocked(
                    id: motor.id,
                    configuration: motor.configuration,
                    notes: motor.notes,
                    quantity: motor.quantity.value,
                    transmission: motor.transmission,
                    arrivalDate: motor.arrivalDate,
                    soldDate: nil, // Возврат в наличие
                    deletedAt: motor.deletedAt
                )
                
                // Загружаем обновлённый мотор через unlocked версию
                guard let dbMotor = try database.fetchMotorByIDUnlocked(id: motor.id) else {
                    throw AppError.databaseError(message: "Не удалось загрузить обновлённый мотор")
                }
                savedMotor = try MotorRepositoryImpl(database: database).mapToEntity(dbMotor)
                
                // Получаем информацию о моторе для истории
                let motorInfo = "Мотор #\(savedMotor.serialCode.value)"
                
                // Создаём финансовую операцию возврата напрямую через database
                let operationID = try database.insertFinancialOperationUnlocked(
                    type: tempOperation.type.rawValue,
                    amount: tempOperation.amount,
                    paymentMethod: tempOperation.paymentMethod.rawValue,
                    cashReceived: tempOperation.cashReceived,
                    changeGiven: tempOperation.changeGiven,
                    account: tempOperation.account.rawValue,
                    relatedMotorID: tempOperation.relatedMotorID,
                    createdAt: tempOperation.createdAt,
                    createdByUser: tempOperation.createdByUser,
                    comment: tempOperation.comment,
                    source: "Возврат мотора",
                    details: motorInfo,
                    category: tempOperation.category,
                    description: tempOperation.description.isEmpty ? motorInfo : tempOperation.description,
                    companyId: self.companyId
                )
                
                // Загружаем созданную операцию через unlocked версию
                guard let dbOperation = try database.fetchFinancialOperationUnlocked(id: operationID) else {
                    throw AppError.databaseError(message: "Не удалось загрузить созданную финансовую операцию")
                }
                
                // Маппим в Entity
                guard let type = FinancialOperationEntity.OperationType(rawValue: dbOperation.type),
                      let paymentMethod = FinancialOperationEntity.PaymentMethod(rawValue: dbOperation.paymentMethod),
                      let account = FinancialOperationEntity.Account(rawValue: dbOperation.account) else {
                    throw AppError.validationError(message: "Неверный формат данных финансовой операции")
                }
                
                savedOperation = FinancialOperationEntity(
                    id: dbOperation.id,
                    type: type,
                    amount: dbOperation.amount,
                    paymentMethod: paymentMethod,
                    cashReceived: dbOperation.cashReceived,
                    changeGiven: dbOperation.changeGiven,
                    account: account,
                    relatedMotorID: dbOperation.relatedMotorID,
                    createdAt: dbOperation.createdAt,
                    createdByUser: dbOperation.createdByUser,
                    comment: dbOperation.comment,
                    source: dbOperation.source,
                    details: dbOperation.details,
                    category: dbOperation.category,
                    description: dbOperation.description
                )
            }
            
            // Публикация событий
            let motorEvent = MotorUnsoldEvent(
                entityID: savedMotor.id,
                occurredAt: Date(),
                motorID: savedMotor.id
            )
            eventBus.publish(motorEvent)
            
            let operationEvent = FinancialOperationCreatedEvent(
                entityID: savedOperation.id,
                occurredAt: Date(),
                operationID: savedOperation.id,
                type: savedOperation.type,
                amount: savedOperation.amount,
                relatedMotorID: savedOperation.relatedMotorID
            )
            eventBus.publish(operationEvent)
            
            // Пушим операцию возврата в Firestore для синхронизации с iOS.
            let financialSync = FirestoreFinancialSyncService()
            Task { @MainActor in
                do {
                    _ = try await financialSync.pushOperation(savedOperation, companyId: companyId)
                } catch {
                    logger.error("Firestore PUSH error in UnsellMotorWithFinancialOperationUseCase", error: error)
                }
            }
            
            logger.info("Motor unsold with refund operation successfully: motorID=\(motorID), operationID=\(savedOperation.id)", correlationID: correlationID)
            
            return (savedMotor, savedOperation)
        } catch let error as DomainError {
            logger.error("Failed to unsell motor with refund operation", error: error, correlationID: correlationID)
            throw AppError.from(error)
        } catch let error as AppError {
            logger.error("Failed to unsell motor with refund operation", error: error, correlationID: correlationID)
            throw error
        } catch {
            logger.error("Failed to unsell motor with refund operation", error: error, correlationID: correlationID)
            throw AppError.databaseError(message: error.localizedDescription)
        }
    }
}
