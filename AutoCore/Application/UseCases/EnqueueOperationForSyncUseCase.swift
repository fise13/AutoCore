import Foundation

/// Use Case: Enqueue Operation for Sync
/// Добавляет финансовую операцию в outbox для последующей синхронизации с Supabase
@MainActor
final class EnqueueOperationForSyncUseCase {
    private let database: DatabaseService
    private let logger: LoggingService
    
    init(
        database: DatabaseService,
        logger: LoggingService = .shared
    ) {
        self.database = database
        self.logger = logger
    }
    
    /// Выполнить добавление операции в outbox
    func execute(operation: FinancialOperationEntity) throws {
        let correlationID = UUIDv7.generateString()
        logger.info("Enqueueing operation \(operation.id) for sync", correlationID: correlationID)
        
        // Создаём DTO для Supabase
        let dto = FinancialOperationDTO(from: operation)
        
        // Кодируем в JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        let jsonData = try encoder.encode(dto)
        guard let payloadJSON = String(data: jsonData, encoding: .utf8) else {
            throw AppError.databaseError(message: "Failed to encode operation to JSON")
        }
        
        // Генерируем уникальный ID для outbox записи
        let outboxID = UUID().uuidString
        
        // Сохраняем в outbox (вне транзакции, так как операция уже сохранена)
        try database.insertOutboxOperation(
            id: outboxID,
            payloadJSON: payloadJSON,
            operationType: operation.type.rawValue
        )
        
        logger.info("Operation \(operation.id) enqueued for sync with outbox ID \(outboxID)", correlationID: correlationID)
    }
}
