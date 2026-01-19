import Foundation

/// DTO для строки таблицы моторов - все данные предварительно отформатированы
struct MotorRowDTO: Identifiable, Equatable {
    let id: Int64
    let serialCode: String
    let configuration: String
    let notes: String
    let quantity: String
    let transmission: String
    let arrivalDate: String
    let soldDate: String
    let isSold: Bool
    
    /// Преобразование Motor в DTO с предварительным форматированием
    static func from(motor: Motor, dateFormatter: DateFormatter) -> MotorRowDTO {
        MotorRowDTO(
            id: motor.id,
            serialCode: motor.serialCode,
            configuration: motor.configuration,
            notes: motor.notes,
            quantity: "\(motor.quantity)",
            transmission: motor.transmission,
            arrivalDate: dateFormatter.string(from: motor.arrivalDate),
            soldDate: motor.soldDate.map { dateFormatter.string(from: $0) } ?? "",
            isSold: motor.availability == .sold
        )
    }
}
