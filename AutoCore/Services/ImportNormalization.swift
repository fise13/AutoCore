import Foundation

enum ImportNormalization {
    static func normalizeEngineCode(_ value: String) -> String {
        value
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .lowercased()
    }

    static func inferBrand(fromEngineCode code: String) -> String? {
        let prefix = code.prefix(2).lowercased()
        if prefix == "ej" || prefix == "fb" || prefix == "fa" || prefix == "ee" {
            return "Subaru"
        }
        return nil
    }

    static func normalizeHeader(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
    }

    static func parseDateString(_ value: String) -> Date? {
        let formats = [
            "dd.MM.yyyy",
            "d.MM.yyyy",
            "d.M.yyyy",
            "yyyy-MM-dd",
            "MM/dd/yyyy"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "ru_RU")
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    static func dateFromExcelSerial(_ value: Double) -> Date? {
        guard value > 0 else { return nil }
        let baseComponents = DateComponents(calendar: Calendar(identifier: .gregorian), year: 1899, month: 12, day: 30)
        guard let baseDate = baseComponents.date else { return nil }
        return baseDate.addingTimeInterval(value * 86400)
    }
}
