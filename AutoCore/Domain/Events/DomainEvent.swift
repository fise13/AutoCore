import Foundation

/// Base protocol for all Domain Events
protocol DomainEvent {
    var eventType: String { get }
    var entityType: String { get }
    var entityID: Int64 { get }
    var occurredAt: Date { get }
    var payload: [String: Any] { get }
}

/// Motor Created Event
struct MotorCreatedEvent: DomainEvent {
    let eventType = "MotorCreated"
    let entityType = "Motor"
    let entityID: Int64
    let occurredAt: Date
    let motorID: Int64
    let serialCode: String
    let engineID: Int64
    
    var payload: [String: Any] {
        [
            "motor_id": motorID,
            "serial_code": serialCode,
            "engine_id": engineID
        ]
    }
}

/// Motor Updated Event
struct MotorUpdatedEvent: DomainEvent {
    let eventType = "MotorUpdated"
    let entityType = "Motor"
    let entityID: Int64
    let occurredAt: Date
    let motorID: Int64
    let changedFields: [String: Any]
    
    var payload: [String: Any] {
        var p: [String: Any] = ["motor_id": motorID]
        p.merge(changedFields) { (_, new) in new }
        return p
    }
}

/// Motor Sold Event
struct MotorSoldEvent: DomainEvent {
    let eventType = "MotorSold"
    let entityType = "Motor"
    let entityID: Int64
    let occurredAt: Date
    let motorID: Int64
    let soldDate: Date
    
    var payload: [String: Any] {
        [
            "motor_id": motorID,
            "sold_date": ISO8601DateFormatter().string(from: soldDate)
        ]
    }
}

/// Motor Unsold Event
struct MotorUnsoldEvent: DomainEvent {
    let eventType = "MotorUnsold"
    let entityType = "Motor"
    let entityID: Int64
    let occurredAt: Date
    let motorID: Int64
    
    var payload: [String: Any] {
        ["motor_id": motorID]
    }
}

/// Motor Imported Event
struct MotorImportedEvent: DomainEvent {
    let eventType = "MotorImported"
    let entityType = "Motor"
    let entityID: Int64
    let occurredAt: Date
    let motorID: Int64
    let source: String
    
    var payload: [String: Any] {
        [
            "motor_id": motorID,
            "source": source
        ]
    }
}

/// Motor Deleted Event
struct MotorDeletedEvent: DomainEvent {
    let eventType = "MotorDeleted"
    let entityType = "Motor"
    let entityID: Int64
    let occurredAt: Date
    let motorID: Int64
    
    var payload: [String: Any] {
        ["motor_id": motorID]
    }
}
