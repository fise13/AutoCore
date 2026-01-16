import Foundation

struct Motor: Identifiable, Hashable {
    let id: Int64
    let engineID: Int64
    let serialCode: String
    let configuration: String
    let notes: String
    let quantity: Int
    let transmission: String
    let arrivalDate: Date
    let soldDate: Date?
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    let brandName: String
    let engineCode: String

    var availability: MotorAvailability {
        soldDate == nil ? .available : .sold
    }
    
    var isDeleted: Bool {
        deletedAt != nil
    }
}
