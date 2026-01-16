import Foundation

struct ServiceRecord: Identifiable, Hashable {
    let id: Int64
    let serialCode: String
    let sheetName: String
    let category: String
    let notes: String
    let recordDate: Date
    let createdAt: Date
}
