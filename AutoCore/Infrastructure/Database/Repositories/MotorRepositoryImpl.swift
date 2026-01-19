import Foundation

/// Infrastructure implementation of MotorRepository
final class MotorRepositoryImpl: MotorRepository {
    private let database: DatabaseService
    
    init(database: DatabaseService) {
        self.database = database
    }
    
    func save(_ motor: MotorEntity) throws -> MotorEntity {
        if motor.id == 0 {
            // Create new
            let motorID = try database.insertOrUpdateMotor(
                engineID: motor.engineID,
                serialCode: motor.serialCode.value,
                configuration: motor.configuration,
                notes: motor.notes,
                quantity: motor.quantity.value,
                transmission: motor.transmission,
                arrivalDate: motor.arrivalDate,
                soldDate: motor.soldDate,
                deletedAt: motor.deletedAt
            )
            
            return try findByID(motorID) ?? motor
        } else {
            // Update existing - updateMotor requires all fields (not engineID/serialCode)
            try database.updateMotor(
                id: motor.id,
                configuration: motor.configuration,
                notes: motor.notes,
                quantity: motor.quantity.value,
                transmission: motor.transmission,
                arrivalDate: motor.arrivalDate,
                soldDate: motor.soldDate,
                deletedAt: motor.deletedAt
            )
            
            return try findByID(motor.id) ?? motor
        }
    }
    
    func findByID(_ id: Int64) throws -> MotorEntity? {
        var dbFilter = DatabaseService.MotorFilter()
        dbFilter.includeDeleted = true // Для поиска по ID нужно включать удаленные
        // Fetch all motors and filter by ID in memory
        // This is not optimal but works for now
        let motors = try database.fetchMotors(filter: dbFilter)
        
        guard let motor = motors.first(where: { $0.id == id }) else {
            return nil
        }
        
        return try mapToEntity(motor)
    }
    
    func findAll(filter: MotorFilter) throws -> [MotorEntity] {
        // Convert Application MotorFilter to DatabaseService.MotorFilter
        var dbFilter = DatabaseService.MotorFilter()
        dbFilter.searchText = filter.searchText
        dbFilter.availability = filter.availability
        dbFilter.brandID = filter.brandID
        dbFilter.engineID = filter.engineID
        
        let motors = try database.fetchMotors(filter: dbFilter)
        return try motors.map { try mapToEntity($0) }
    }
    
    func delete(_ id: Int64) throws {
        try database.deleteMotor(id: id)
    }
    
    func mapToEntity(_ motor: Motor) throws -> MotorEntity {
        return MotorEntity(
            id: motor.id,
            engineID: motor.engineID,
            serialCode: try SerialCode(motor.serialCode),
            configuration: motor.configuration,
            notes: motor.notes,
            quantity: try Quantity(motor.quantity),
            transmission: motor.transmission,
            arrivalDate: motor.arrivalDate,
            soldDate: motor.soldDate,
            deletedAt: motor.deletedAt,
            createdAt: motor.createdAt,
            updatedAt: motor.updatedAt
        )
    }
}
