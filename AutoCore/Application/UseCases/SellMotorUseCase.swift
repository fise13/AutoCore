import Foundation

/// Use Case: Sell Motor
@MainActor
final class SellMotorUseCase {
    private let motorRepository: MotorRepository
    private let eventBus: EventBus
    private let logger: LoggingService
    
    init(
        motorRepository: MotorRepository,
        eventBus: EventBus = .shared,
        logger: LoggingService = .shared
    ) {
        self.motorRepository = motorRepository
        self.eventBus = eventBus
        self.logger = logger
    }
    
    func execute(motorID: Int64, soldDate: Date = Date()) throws -> MotorEntity {
        let correlationID = UUID().uuidString
        logger.info("Selling motor: \(motorID)", correlationID: correlationID)
        
        do {
            // Загружаем мотор
            guard var motor = try motorRepository.findByID(motorID) else {
                throw AppError.notFound(message: "Мотор с ID \(motorID) не найден")
            }
            
            // Domain Rule: продаем мотор
            try motor.sell(on: soldDate)
            
            // Сохранение
            let savedMotor = try motorRepository.save(motor)
            
            // Публикация события
            let event = MotorSoldEvent(
                entityID: savedMotor.id,
                occurredAt: Date(),
                motorID: savedMotor.id,
                soldDate: soldDate
            )
            eventBus.publish(event)
            
            logger.info("Motor sold successfully: \(motorID)", correlationID: correlationID)
            
            return savedMotor
        } catch let error as DomainError {
            logger.error("Failed to sell motor", error: error, correlationID: correlationID)
            throw AppError.from(error)
        } catch let error as AppError {
            logger.error("Failed to sell motor", error: error, correlationID: correlationID)
            throw error
        } catch {
            logger.error("Failed to sell motor", error: error, correlationID: correlationID)
            throw AppError.databaseError(message: error.localizedDescription)
        }
    }
}
