import Foundation

enum MotorAvailability: String, CaseIterable, Identifiable {
    case available
    case sold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .available:
            return "В наличии"
        case .sold:
            return "Продан"
        }
    }
}

enum MotorAvailabilityFilter: String, CaseIterable, Identifiable {
    case all
    case available
    case sold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Все"
        case .available:
            return "В наличии"
        case .sold:
            return "Продан"
        }
    }
}
