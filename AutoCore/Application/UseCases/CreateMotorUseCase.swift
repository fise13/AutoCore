import Foundation

/// Use Case: Create Motor
@MainActor
final class CreateMotorUseCase {
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
    
    func execute(_ dto: CreateMotorDTO) throws -> MotorEntity {
        let correlationID = UUID().uuidString
        logger.info("Creating motor: \(dto.serialCode)", correlationID: correlationID)
        
        do {
            // Создаем Domain Entity
            var motor = try MotorEntity(
                id: 0, // Будет установлен после сохранения
                engineID: dto.engineID,
                serialCode: try SerialCode(dto.serialCode),
                configuration: dto.configuration,
                notes: dto.notes,
                quantity: try Quantity(dto.quantity),
                transmission: dto.transmission,
                arrivalDate: dto.arrivalDate,
                soldDate: dto.soldDate,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // Валидация
            try motor.validate()
            
            // Сохранение через Repository
            let savedMotor = try motorRepository.save(motor)
            
            // Публикация события
            let event = MotorCreatedEvent(
                entityID: savedMotor.id,
                occurredAt: Date(),
                motorID: savedMotor.id,
                serialCode: savedMotor.serialCode.value,
                engineID: savedMotor.engineID
            )
            eventBus.publish(event)
            
            logger.info("Motor created successfully: \(savedMotor.id)", correlationID: correlationID)
            
            return savedMotor
        } catch let error as DomainError {
            logger.error("Failed to create motor", error: error, correlationID: correlationID)
            throw AppError.from(error)
        } catch {
            logger.error("Failed to create motor", error: error, correlationID: correlationID)
            throw AppError.databaseError(message: error.localizedDescription)
        }
    }
}

/// DTO for creating a motor
struct CreateMotorDTO {
    let engineID: Int64
    let serialCode: String
    let configuration: String
    let notes: String
    let quantity: Int
    let transmission: String
    let arrivalDate: Date
    let soldDate: Date?
}
