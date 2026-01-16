import Foundation
import Combine

/// In-memory Event Bus for Domain Events
@MainActor
final class EventBus {
    static let shared = EventBus()
    
    private let subject = PassthroughSubject<DomainEvent, Never>()
    private var subscribers: [UUID: AnyCancellable] = [:]
    
    private init() {}
    
    /// Publish a domain event
    func publish(_ event: DomainEvent) {
        subject.send(event)
    }
    
    /// Subscribe to domain events
    func subscribe<T: DomainEvent>(
        to eventType: T.Type,
        handler: @escaping (T) -> Void
    ) -> UUID {
        let id = UUID()
        let cancellable = subject
            .compactMap { $0 as? T }
            .sink(receiveValue: handler)
        
        subscribers[id] = cancellable
        return id
    }
    
    /// Subscribe to all events
    func subscribeAll(handler: @escaping (DomainEvent) -> Void) -> UUID {
        let id = UUID()
        let cancellable = subject.sink(receiveValue: handler)
        subscribers[id] = cancellable
        return id
    }
    
    /// Unsubscribe
    func unsubscribe(_ id: UUID) {
        subscribers[id]?.cancel()
        subscribers.removeValue(forKey: id)
    }
}
