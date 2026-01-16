import Foundation

// Модель для ручного маппинга колонок Excel
struct ColumnMapping: Identifiable, Hashable {
    let id = UUID()
    let columnIndex: Int // Индекс колонки (0, 1, 2...)
    let columnLetter: String // Буква колонки (A, B, C...)
    let headerValue: String? // Значение заголовка, если есть
    let previewValues: [String] // Preview первых значений для отображения
    
    // Для основных листов - назначение из фиксированного списка
    var engineFieldMapping: EngineFieldMapping?
    
    // Для специфичных листов - пользовательское имя поля
    var customFieldName: String?
    
    var isIgnored: Bool {
        engineFieldMapping == nil && customFieldName == nil
    }
    
    var displayName: String {
        if let header = headerValue, !header.isEmpty {
            return "\(columnLetter) — \(header)"
        }
        return columnLetter
    }
}

// Фиксированные поля для основных листов (двигатели)
enum EngineFieldMapping: String, CaseIterable, Identifiable {
    case serialCode = "serial_code"
    case configuration = "configuration"
    case notes = "notes"
    case quantity = "quantity"
    case transmission = "transmission"
    case arrivalDate = "arrival_date"
    case soldDate = "sold_date"
    case ignore = "ignore"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .serialCode:
            return "НОМЕР ДВИГАТЕЛЯ"
        case .configuration:
            return "Комплектация"
        case .notes:
            return "Особые отметки"
        case .quantity:
            return "Количество"
        case .transmission:
            return "Коробка"
        case .arrivalDate:
            return "Дата прихода"
        case .soldDate:
            return "Дата продажи"
        case .ignore:
            return "Игнорировать"
        }
    }
    
    var isRequired: Bool {
        self == .serialCode
    }
}

// Модель для маппинга колонок листа
struct SheetColumnMapping: Identifiable, Hashable {
    let id = UUID()
    let sheetID: UUID // ID SheetImportConfig
    var columnMappings: [ColumnMapping]
    var headerRowIndex: Int? // Индекс строки с заголовками (если есть)
    
    // Проверка валидности для основных листов
    func isValidForEngines() -> Bool {
        // serial_code обязателен
        return columnMappings.contains { mapping in
            mapping.engineFieldMapping == .serialCode
        }
    }
    
    // Для специфичных листов - нет обязательных полей
    func isValidForSpecific() -> Bool {
        return true
    }
}
