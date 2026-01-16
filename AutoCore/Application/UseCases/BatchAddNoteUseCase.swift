import Foundation

/// Use Case: Batch Add Note
/// Массовое добавление заметки к моторам
@MainActor
final class BatchAddNoteUseCase {
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
    
    /// Выполнить массовое добавление заметки
    /// - Parameters:
    ///   - motorIDs: Список ID моторов
    ///   - note: Текст заметки для добавления
    ///   - append: Если true, заметка добавляется к существующей, иначе заменяет
    /// - Returns: Результат операции
    func execute(motorIDs: [Int64], note: String, append: Bool = true) throws -> BatchOperationResult {
        // Проверка Recovery Mode
        try recoveryState?.assertNotInRecoveryMode()
        
        guard !motorIDs.isEmpty else {
            throw AppError.validationError(message: "Не выбраны моторы")
        }
        
        guard !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.validationError(message: "Заметка не может быть пустой")
        }
        
        let correlationID = UUIDv7.generateString()
        logger.info("Batch adding note to \(motorIDs.count) motors", correlationID: correlationID)
        
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
                
                // Добавляем или заменяем заметку
                if append && !motor.notes.isEmpty {
                    motor.notes = "\(motor.notes)\n\(note)"
                } else {
                    motor.notes = note
                }
                
                motor.updatedAt = Date()
                
                // Валидация
                try motor.validate()
                
                // Сохранение
                let savedMotor = try motorRepository.save(motor)
                successIDs.append(savedMotor.id)
                
                // Публикация события
                let event = MotorUpdatedEvent(
                    entityID: savedMotor.id,
                    occurredAt: Date(),
                    motorID: savedMotor.id,
                    changedFields: ["notes": savedMotor.notes]
                )
                eventBus.publish(event)
                
            } catch let error as DomainError {
                failedIDs.append(motorID)
                errors.append("Мотор \(motorID): \(error.localizedDescription)")
                logger.warning("Failed to add note to motor \(motorID)", correlationID: correlationID)
            } catch {
                failedIDs.append(motorID)
                errors.append("Мотор \(motorID): \(error.localizedDescription)")
                logger.warning("Failed to add note to motor \(motorID)", correlationID: correlationID)
            }
        }
        
        // Публикация batch события
        if !successIDs.isEmpty {
            let batchEvent = BatchMotorsNoteAddedEvent(
                entityID: 0,
                occurredAt: Date(),
                motorIDs: successIDs,
                note: note
            )
            eventBus.publish(batchEvent)
        }
        
        logger.info("Batch add note completed: \(successIDs.count) success, \(failedIDs.count) failed", correlationID: correlationID)
        
        return BatchOperationResult(
            successIDs: successIDs,
            failedIDs: failedIDs,
            errors: errors
        )
    }
}
