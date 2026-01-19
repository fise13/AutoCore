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

/// Batch Motors Sold Event
struct BatchMotorsSoldEvent: DomainEvent {
    let eventType = "BatchMotorsSold"
    let entityType = "Motor"
    let entityID: Int64
    let occurredAt: Date
    let motorIDs: [Int64]
    let soldDate: Date
    
    var payload: [String: Any] {
        [
            "motor_ids": motorIDs,
            "count": motorIDs.count,
            "sold_date": ISO8601DateFormatter().string(from: soldDate)
        ]
    }
}

/// Batch Motors Unsold Event
struct BatchMotorsUnsoldEvent: DomainEvent {
    let eventType = "BatchMotorsUnsold"
    let entityType = "Motor"
    let entityID: Int64
    let occurredAt: Date
    let motorIDs: [Int64]
    
    var payload: [String: Any] {
        [
            "motor_ids": motorIDs,
            "count": motorIDs.count
        ]
    }
}

/// Batch Motors Note Added Event
struct BatchMotorsNoteAddedEvent: DomainEvent {
    let eventType = "BatchMotorsNoteAdded"
    let entityType = "Motor"
    let entityID: Int64
    let occurredAt: Date
    let motorIDs: [Int64]
    let note: String
    
    var payload: [String: Any] {
        [
            "motor_ids": motorIDs,
            "count": motorIDs.count,
            "note": note
        ]
    }
}

/// Motor Soft Deleted Event
struct MotorSoftDeletedEvent: DomainEvent {
    let eventType = "MotorSoftDeleted"
    let entityType = "Motor"
    let entityID: Int64
    let occurredAt: Date
    let motorID: Int64
    
    var payload: [String: Any] {
        ["motor_id": motorID]
    }
}

/// Motor Restored Event
struct MotorRestoredEvent: DomainEvent {
    let eventType = "MotorRestored"
    let entityType = "Motor"
    let entityID: Int64
    let occurredAt: Date
    let motorID: Int64
    
    var payload: [String: Any] {
        ["motor_id": motorID]
    }
}

/// Financial Operation Created Event
struct FinancialOperationCreatedEvent: DomainEvent {
    let eventType = "FinancialOperationCreated"
    let entityType = "FinancialOperation"
    let entityID: Int64
    let occurredAt: Date
    let operationID: Int64
    let type: FinancialOperationEntity.OperationType
    let amount: Decimal
    let relatedMotorID: Int64?
    
    var payload: [String: Any] {
        var p: [String: Any] = [
            "operation_id": operationID,
            "type": type.rawValue,
            "amount": String(describing: amount)
        ]
        if let motorID = relatedMotorID {
            p["related_motor_id"] = motorID
        }
        return p
    }
}
