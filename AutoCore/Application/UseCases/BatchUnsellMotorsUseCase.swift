import Foundation

/// Use Case: Batch Unsell Motors
/// Массовый возврат моторов в наличие
@MainActor
final class BatchUnsellMotorsUseCase {
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
    
    /// Выполнить массовый возврат в наличие
    /// - Parameter motorIDs: Список ID моторов для возврата
    /// - Returns: Результат операции
    func execute(motorIDs: [Int64]) throws -> BatchOperationResult {
        // Проверка Recovery Mode
        try recoveryState?.assertNotInRecoveryMode()
        
        guard !motorIDs.isEmpty else {
            throw AppError.validationError(message: "Не выбраны моторы для возврата")
        }
        
        let correlationID = UUIDv7.generateString()
        logger.info("Batch unselling \(motorIDs.count) motors", correlationID: correlationID)
        
        var successIDs: [Int64] = []
        var failedIDs: [Int64] = []
        var errors: [String] = []
        
        for motorID in motorIDs {
            do {
                guard var motor = try motorRepository.findByID(motorID) else {
                    failedIDs.append(motorID)
                    errors.append("Мотор \(motorID) не найден")
                    continue
                }
                
                // Domain Rule: возвращаем мотор
                try motor.unsell()
                
                // Сохранение
                let savedMotor = try motorRepository.save(motor)
                successIDs.append(savedMotor.id)
                
                // Публикация события для каждого мотора
                let event = MotorUnsoldEvent(
                    entityID: savedMotor.id,
                    occurredAt: Date(),
                    motorID: savedMotor.id
                )
                eventBus.publish(event)
                
            } catch let error as DomainError {
                failedIDs.append(motorID)
                errors.append("Мотор \(motorID): \(error.localizedDescription)")
                logger.warning("Failed to unsell motor \(motorID)", correlationID: correlationID)
            } catch {
                failedIDs.append(motorID)
                errors.append("Мотор \(motorID): \(error.localizedDescription)")
                logger.warning("Failed to unsell motor \(motorID)", correlationID: correlationID)
            }
        }
        
        // Публикация batch события
        if !successIDs.isEmpty {
            let batchEvent = BatchMotorsUnsoldEvent(
                entityID: 0,
                occurredAt: Date(),
                motorIDs: successIDs
            )
            eventBus.publish(batchEvent)
        }
        
        logger.info("Batch unsell completed: \(successIDs.count) success, \(failedIDs.count) failed", correlationID: correlationID)
        
        return BatchOperationResult(
            successIDs: successIDs,
            failedIDs: failedIDs,
            errors: errors
        )
    }
}
