import Foundation

/// Use Case: Update Motor
@MainActor
final class UpdateMotorUseCase {
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
    
    func execute(motorID: Int64, _ dto: UpdateMotorDTO) throws -> MotorEntity {
        // Проверка Recovery Mode
        try recoveryState?.assertNotInRecoveryMode()
        
        let correlationID = UUIDv7.generateString()
        logger.info("Updating motor: \(motorID)", correlationID: correlationID)
        
        do {
            // Загружаем мотор
            guard var motor = try motorRepository.findByID(motorID) else {
                throw AppError.notFound(message: "Мотор с ID \(motorID) не найден")
            }
            
            // Обновляем поля
            var changedFields: [String: Any] = [:]
            
            if let serialCode = dto.serialCode {
                motor.serialCode = try SerialCode(serialCode)
                changedFields["serial_code"] = serialCode
            }
            
            if let configuration = dto.configuration {
                motor.configuration = configuration
                changedFields["configuration"] = configuration
            }
            
            if let notes = dto.notes {
                motor.notes = notes
                changedFields["notes"] = notes
            }
            
            if let quantity = dto.quantity {
                motor.quantity = try Quantity(quantity)
                changedFields["quantity"] = quantity
            }
            
            if let transmission = dto.transmission {
                motor.transmission = transmission
                changedFields["transmission"] = transmission
            }
            
            if let arrivalDate = dto.arrivalDate {
                motor.arrivalDate = arrivalDate
                changedFields["arrival_date"] = ISO8601DateFormatter().string(from: arrivalDate)
            }
            
            motor.updatedAt = Date()
            
            // Валидация
            try motor.validate()
            
            // Сохранение
            let savedMotor = try motorRepository.save(motor)
            
            // Публикация события
            if !changedFields.isEmpty {
                let event = MotorUpdatedEvent(
                    entityID: savedMotor.id,
                    occurredAt: Date(),
                    motorID: savedMotor.id,
                    changedFields: changedFields
                )
                eventBus.publish(event)
            }
            
            logger.info("Motor updated successfully: \(motorID)", correlationID: correlationID)
            
            return savedMotor
        } catch let error as DomainError {
            logger.error("Failed to update motor", error: error, correlationID: correlationID)
            throw AppError.from(error)
        } catch let error as AppError {
            logger.error("Failed to update motor", error: error, correlationID: correlationID)
            throw error
        } catch {
            logger.error("Failed to update motor", error: error, correlationID: correlationID)
            throw AppError.databaseError(message: error.localizedDescription)
        }
    }
}

/// DTO for updating a motor
struct UpdateMotorDTO {
    let serialCode: String?
    let configuration: String?
    let notes: String?
    let quantity: Int?
    let transmission: String?
    let arrivalDate: Date?
}
