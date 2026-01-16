import Foundation

/// Audit Log Service
/// Автоматически логирует все Domain Events в audit_log таблицу
@MainActor
final class AuditLogService {
    private let database: DatabaseService
    private let logger: LoggingService
    private var subscriptionID: UUID?
    
    init(database: DatabaseService, logger: LoggingService = .shared) {
        self.database = database
        self.logger = logger
        
        // Подписываемся на все события
        subscriptionID = EventBus.shared.subscribeAll { [weak self] event in
            Task { @MainActor in
                self?.logEvent(event)
            }
        }
    }
    
    deinit {
        if let id = subscriptionID {
            Task { @MainActor in
                EventBus.shared.unsubscribe(id)
            }
        }
    }
    
    private func logEvent(_ event: DomainEvent) {
        do {
            try database.insertAuditLog(
                eventType: event.eventType,
                entityType: event.entityType,
                entityID: event.entityID,
                payload: event.payload
            )
        } catch {
            logger.error("Failed to write audit log", error: error)
        }
    }
}
