import Foundation

/// Use Case: Process Outbox
/// Обрабатывает pending операции из outbox и отправляет их в Supabase
@MainActor
final class ProcessOutboxUseCase {
    private let supabaseSyncService: SupabaseSyncService
    private let logger: LoggingService
    
    init(
        supabaseSyncService: SupabaseSyncService,
        logger: LoggingService = .shared
    ) {
        self.supabaseSyncService = supabaseSyncService
        self.logger = logger
    }
    
    /// Выполнить обработку outbox
    func execute() async throws {
        let correlationID = UUIDv7.generateString()
        logger.info("Processing outbox", correlationID: correlationID)
        
        try await supabaseSyncService.processOutbox()
        
        logger.info("Outbox processed successfully", correlationID: correlationID)
    }
}
