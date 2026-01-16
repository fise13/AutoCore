import Foundation

/// Use Case: Batch Sell Motors
/// Массовая продажа нескольких моторов
@MainActor
final class BatchSellMotorsUseCase {
    private let motorRepository: MotorRepository
    private let eventBus: EventBus
    private let logger: LoggingService
    private let recoveryState: RecoveryState?
    
    init(
        motorRepository: MotorRepository,
        eventBus: EventBus = .shared,
        logger: LoggingService = .shared,
        recoveryState: RecoveryState? = nil
    ) {
        self.motorRepository = motorRepository
        self.eventBus = eventBus
        self.logger = logger
        self.recoveryState = recoveryState
    }
    
    /// Выполнить массовую продажу
    /// - Parameters:
    ///   - motorIDs: Список ID моторов для продажи
    ///   - soldDate: Дата продажи (по умолчанию текущая)
    /// - Returns: Результат операции с перечнем успешно проданных моторов
    func execute(motorIDs: [Int64], soldDate: Date = Date()) throws -> BatchOperationResult {
        // Проверка Recovery Mode
        try recoveryState?.assertNotInRecoveryMode()
        
        guard !motorIDs.isEmpty else {
            throw AppError.validationError(message: "Не выбраны моторы для продажи")
        }
        
        let correlationID = UUIDv7.generateString()
        logger.info("Batch selling \(motorIDs.count) motors", correlationID: correlationID)
        
        var successIDs: [Int64] = []
        var failedIDs: [Int64] = []
        var errors: [String] = []
        
        // Выполняем операции в транзакции (если поддерживается)
        for motorID in motorIDs {
            do {
                guard var motor = try motorRepository.findByID(motorID) else {
                    failedIDs.append(motorID)
                    errors.append("Мотор \(motorID) не найден")
                    continue
                }
                
                // Domain Rule: продаем мотор
                try motor.sell(on: soldDate)
                
                // Сохранение
                let savedMotor = try motorRepository.save(motor)
                successIDs.append(savedMotor.id)
                
                // Публикация события для каждого мотора
                let event = MotorSoldEvent(
                    entityID: savedMotor.id,
                    occurredAt: Date(),
                    motorID: savedMotor.id,
                    soldDate: soldDate
                )
                eventBus.publish(event)
                
            } catch let error as DomainError {
                failedIDs.append(motorID)
                errors.append("Мотор \(motorID): \(error.localizedDescription)")
                logger.warning("Failed to sell motor \(motorID)", correlationID: correlationID)
            } catch {
                failedIDs.append(motorID)
                errors.append("Мотор \(motorID): \(error.localizedDescription)")
                logger.warning("Failed to sell motor \(motorID)", correlationID: correlationID)
            }
        }
        
        // Публикация batch события
        if !successIDs.isEmpty {
            let batchEvent = BatchMotorsSoldEvent(
                entityID: 0, // Batch операции не имеют конкретного entityID
                occurredAt: Date(),
                motorIDs: successIDs,
                soldDate: soldDate
            )
            eventBus.publish(batchEvent)
        }
        
        logger.info("Batch sell completed: \(successIDs.count) success, \(failedIDs.count) failed", correlationID: correlationID)
        
        return BatchOperationResult(
            successIDs: successIDs,
            failedIDs: failedIDs,
            errors: errors
        )
    }
}

/// Результат batch операции
struct BatchOperationResult {
    let successIDs: [Int64]
    let failedIDs: [Int64]
    let errors: [String]
    
    var isSuccess: Bool {
        !successIDs.isEmpty && failedIDs.isEmpty
    }
    
    var hasPartialSuccess: Bool {
        !successIDs.isEmpty && !failedIDs.isEmpty
    }
}
