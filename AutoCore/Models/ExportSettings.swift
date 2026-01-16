import Foundation

/// Настройки экспорта в Excel
struct ExportSettings: Codable {
    // Проданные моторы
    var includeSoldMotors: Bool = false
    
    // Моторы в наличии
    var includeAvailableMotors: Bool = true
    
    // Структура листов
    var sheetStructure: SheetStructure = .separateByEngine
    
    // Выбранные специфичные категории (ID категорий)
    var selectedSpecificCategoryIDs: Set<Int64> = []
    
    // Форматирование
    var includeFormatting: Bool = true
    
    // Учитывать текущие фильтры
    var respectCurrentFilters: Bool = true
    
    enum SheetStructure: String, Codable, CaseIterable {
        case separateByEngine = "separate"
        case singleSheet = "single"
        
        var title: String {
            switch self {
            case .separateByEngine:
                return "Отдельные листы по двигателям"
            case .singleSheet:
                return "Один общий лист"
            }
        }
    }
    
    /// Загрузить настройки из UserDefaults
    static func load() -> ExportSettings {
        guard let data = UserDefaults.standard.data(forKey: "ExportSettings"),
              let settings = try? JSONDecoder().decode(ExportSettings.self, from: data) else {
            return ExportSettings() // Настройки по умолчанию
        }
        return settings
    }
    
    /// Сохранить настройки в UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "ExportSettings")
        }
    }
}
