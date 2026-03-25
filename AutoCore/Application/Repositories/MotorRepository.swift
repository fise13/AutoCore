import Foundation

/// Repository Interface for Motor Entity
protocol MotorRepository: AnyObject {
    /// Установить текущую компанию для фильтрации и сохранения (моторы привязаны к компании).
    func setCompanyId(_ companyId: String)
    func save(_ motor: MotorEntity) throws -> MotorEntity
    func findByID(_ id: Int64) throws -> MotorEntity?
    func findAll(filter: MotorFilter) throws -> [MotorEntity]
    func delete(_ id: Int64) throws
}

/// Motor Filter for queries
struct MotorFilter {
    var searchText: String = ""
    var availability: MotorAvailabilityFilter = .all
    var brandID: Int64? = nil
    var engineID: Int64? = nil
}

// Import MotorAvailabilityFilter from Models
// This type is defined in Models/MotorAvailability.swift
