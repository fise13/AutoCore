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
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formats: [(String, String)] = [
            ("dd.MM.yyyy", "ru_RU"),
            ("d.MM.yyyy", "ru_RU"),
            ("d.M.yyyy", "ru_RU"),
            ("dd.MM.yy", "ru_RU"),
            ("d.M.yy", "ru_RU"),
            ("dd/MM/yyyy", "en_GB"),
            ("d/M/yyyy", "en_GB"),
            ("dd/MM/yy", "en_GB"),
            ("dd-MM-yyyy", "ru_RU"),
            ("d-M-yyyy", "ru_RU"),
            ("yyyy-MM-dd", "en_US_POSIX"),
            ("MM/dd/yyyy", "en_US")
        ]
        for (format, loc) in formats {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: loc)
            formatter.timeZone = TimeZone.current
            if let date = formatter.date(from: trimmed) {
                return normalizeToLocalCalendarDay(date)
            }
        }
        return nil
    }

    /// Календарный день в локальной зоне (00:00 локально). Устраняет сдвиг «на день» из‑за хранения как UTC-полуночи.
    static func normalizeToLocalCalendarDay(_ date: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return cal.date(from: c) ?? date
    }

    /// Excel/OOXML (система 1900): serial **1,0** = 1 января 1900, дробь — доля суток.
    /// Ранее опирались на 30.12.1899 + n — в результате **все** даты оказывались на 1 день раньше.
    static func dateFromExcelSerial(_ value: Double) -> Date? {
        guard value > 0 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        guard let epochJan1_1900 = cal.date(from: DateComponents(year: 1900, month: 1, day: 1)) else { return nil }
        // (value − 1) суток от полуночи 01.01.1900 в локальной зоне, как в Excel для современных serial.
        let t = epochJan1_1900.addingTimeInterval((value - 1.0) * 86_400)
        return normalizeToLocalCalendarDay(t)
    }
}
