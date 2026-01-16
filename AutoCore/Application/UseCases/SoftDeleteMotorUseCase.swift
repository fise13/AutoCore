import Foundation

/// Use Case: Soft Delete Motor
/// Мягкое удаление мотора (устанавливает deleted_at)
@MainActor
final class SoftDeleteMotorUseCase {
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
    
    func execute(motorID: Int64) throws -> MotorEntity {
        // Проверка Recovery Mode
        try recoveryState?.assertNotInRecoveryMode()
        
        let correlationID = UUIDv7.generateString()
        logger.info("Soft deleting motor: \(motorID)", correlationID: correlationID)
        
        do {
            // Загружаем мотор
            guard var motor = try motorRepository.findByID(motorID) else {
                throw AppError.notFound(message: "Мотор с ID \(motorID) не найден")
            }
            
            // Domain Rule: мягкое удаление
            motor.softDelete()
            
            // Сохранение
            let savedMotor = try motorRepository.save(motor)
            
            // Публикация события
            let event = MotorSoftDeletedEvent(
                entityID: savedMotor.id,
                occurredAt: Date(),
                motorID: savedMotor.id
            )
            eventBus.publish(event)
            
            logger.info("Motor soft deleted successfully: \(motorID)", correlationID: correlationID)
            
            return savedMotor
        } catch let error as DomainError {
            logger.error("Failed to soft delete motor", error: error, correlationID: correlationID)
            throw AppError.from(error)
        } catch let error as AppError {
            logger.error("Failed to soft delete motor", error: error, correlationID: correlationID)
            throw error
        } catch {
            logger.error("Failed to soft delete motor", error: error, correlationID: correlationID)
            throw AppError.databaseError(message: error.localizedDescription)
        }
    }
}
