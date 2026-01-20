import Foundation

/// Use Case: Sell Motor with Financial Operation
/// Продаёт мотор и создаёт финансовую операцию в ОДНОЙ транзакции
@MainActor
final class SellMotorWithFinancialOperationUseCase {
    private let database: DatabaseService
    private let motorRepository: MotorRepository
    private let eventBus: EventBus
    private let logger: LoggingService
    private let recoveryState: RecoveryState?
    private let currentUser: String
    private let enqueueForSyncUseCase: EnqueueOperationForSyncUseCase?
    
    init(
        database: DatabaseService,
        motorRepository: MotorRepository,
        eventBus: EventBus = .shared,
        logger: LoggingService = .shared,
        recoveryState: RecoveryState? = nil,
        currentUser: String,
        enqueueForSyncUseCase: EnqueueOperationForSyncUseCase? = nil
    ) {
        self.database = database
        self.motorRepository = motorRepository
        self.eventBus = eventBus
        self.logger = logger
        self.recoveryState = recoveryState
        self.currentUser = currentUser
        self.enqueueForSyncUseCase = enqueueForSyncUseCase
    }
    
    func execute(
        motorID: Int64,
        soldDate: Date = Date(),
        saleAmount: Decimal,
        paymentMethod: FinancialOperationEntity.PaymentMethod,
        cashReceived: Decimal?,
        account: FinancialOperationEntity.Account,
        comment: String = ""
    ) async throws -> (motor: MotorEntity, operation: FinancialOperationEntity) {
        try recoveryState?.assertNotInRecoveryMode()
        
        let correlationID = UUIDv7.generateString()
        logger.info("Selling motor with financial operation: motorID=\(motorID), amount=\(saleAmount)", correlationID: correlationID)
        
        do {
            // Загружаем мотор
            guard var motor = try motorRepository.findByID(motorID) else {
                throw AppError.notFound(message: "Мотор с ID \(motorID) не найден")
            }
            
            // Domain Rule: продаем мотор
            try motor.sell(on: soldDate)
            
            // Вычисляем сдачу автоматически
            let changeGiven: Decimal?
            if let cashReceived = cashReceived, paymentMethod == .cash || paymentMethod == .mixed {
                changeGiven = FinancialOperationEntity.calculateChange(cashReceived: cashReceived, amount: saleAmount)
            } else {
                changeGiven = nil
            }
            
            // Валидация финансовой операции (создаём временную для валидации)
            let tempOperation = FinancialOperationEntity(
                id: 0,
                type: .sale,
                amount: saleAmount,
                paymentMethod: paymentMethod,
                cashReceived: cashReceived,
                changeGiven: changeGiven,
                account: account,
                relatedMotorID: motorID,
                createdAt: soldDate,
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
                if motor.id == 0 {
                    // Create new - используем unlocked версию
                    let motorID = try database.insertOrUpdateMotorUnlocked(
                        engineID: motor.engineID,
                        serialCode: motor.serialCode.value,
                        configuration: motor.configuration,
                        notes: motor.notes,
                        quantity: motor.quantity.value,
                        transmission: motor.transmission,
                        arrivalDate: motor.arrivalDate,
                        soldDate: motor.soldDate,
                        deletedAt: motor.deletedAt
                    )
                    // Загружаем сохранённый мотор через unlocked версию
                    guard let dbMotor = try database.fetchMotorByIDUnlocked(id: motorID) else {
                        throw AppError.databaseError(message: "Не удалось загрузить сохранённый мотор")
                    }
                    savedMotor = try MotorRepositoryImpl(database: database).mapToEntity(dbMotor)
                } else {
                    // Update existing - используем unlocked версию
                    try database.updateMotorUnlocked(
                        id: motor.id,
                        configuration: motor.configuration,
                        notes: motor.notes,
                        quantity: motor.quantity.value,
                        transmission: motor.transmission,
                        arrivalDate: motor.arrivalDate,
                        soldDate: motor.soldDate,
                        deletedAt: motor.deletedAt
                    )
                    // Загружаем обновлённый мотор через unlocked версию
                    guard let dbMotor = try database.fetchMotorByIDUnlocked(id: motor.id) else {
                        throw AppError.databaseError(message: "Не удалось загрузить обновлённый мотор")
                    }
                    savedMotor = try MotorRepositoryImpl(database: database).mapToEntity(dbMotor)
                }
                
                // Получаем информацию о моторе для истории
                let motorInfo = "Мотор #\(savedMotor.serialCode.value)"
                
                // Создаём финансовую операцию напрямую через database
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
                    source: "Продажа мотора",
                    details: motorInfo,
                    category: tempOperation.category,
                    description: tempOperation.description.isEmpty ? motorInfo : tempOperation.description
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
            
            // Публикация событий
            let motorEvent = MotorSoldEvent(
                entityID: savedMotor.id,
                occurredAt: Date(),
                motorID: savedMotor.id,
                soldDate: soldDate
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
            
            logger.info("Motor sold with financial operation successfully: motorID=\(motorID), operationID=\(savedOperation.id)", correlationID: correlationID)
            
            return (savedMotor, savedOperation)
        } catch let error as DomainError {
            logger.error("Failed to sell motor with financial operation", error: error, correlationID: correlationID)
            throw AppError.from(error)
        } catch let error as AppError {
            logger.error("Failed to sell motor with financial operation", error: error, correlationID: correlationID)
            throw error
        } catch {
            logger.error("Failed to sell motor with financial operation", error: error, correlationID: correlationID)
            throw AppError.databaseError(message: error.localizedDescription)
        }
    }
}
