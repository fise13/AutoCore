import Foundation

/// Domain Entity: Motor
/// Содержит бизнес-логику и правила валидации
struct MotorEntity {
    let id: Int64
    let engineID: Int64
    var serialCode: SerialCode
    var configuration: String
    var notes: String
    var quantity: Quantity
    var transmission: String
    var arrivalDate: Date
    var soldDate: Date?
    var deletedAt: Date?
    let createdAt: Date
    var updatedAt: Date
    
    /// Domain Rule: мотор не может быть продан дважды
    var isSold: Bool {
        soldDate != nil
    }
    
    /// Domain Rule: sold_date != null → статус продан
    var availability: AutoCore.MotorAvailability {
        soldDate == nil ? .available : .sold
    }
    
    /// Валидация: serial_code обязателен
    func validate() throws {
        guard !serialCode.value.isEmpty else {
            throw DomainError.validationError(message: "Серийный номер обязателен")
        }
        
        try quantity.validate()
    }
    
    /// Продать мотор
    mutating func sell(on date: Date) throws {
        guard !isSold else {
            throw DomainError.logicError(message: "Мотор уже продан")
        }
        
        guard date >= arrivalDate else {
            throw DomainError.validationError(message: "Дата продажи не может быть раньше даты прихода")
        }
        
        soldDate = date
        updatedAt = Date()
    }
    
    /// Вернуть мотор в продажу
    mutating func unsell() throws {
        guard isSold else {
            throw DomainError.logicError(message: "Мотор не был продан")
        }
        
        soldDate = nil
        updatedAt = Date()
    }
    
    /// Мягкое удаление мотора
    mutating func softDelete() {
        guard deletedAt == nil else {
            return // Уже удален
        }
        
        deletedAt = Date()
        updatedAt = Date()
    }
    
    /// Восстановление мотора
    mutating func restore() throws {
        guard deletedAt != nil else {
            throw DomainError.logicError(message: "Мотор не был удален")
        }
        
        deletedAt = nil
        updatedAt = Date()
    }
    
    /// Проверка, удален ли мотор
    var isDeleted: Bool {
        deletedAt != nil
    }
}

// Note: MotorAvailability and MotorAvailabilityFilter are defined in Models/MotorAvailability.swift
