import Foundation

/// Конфигурация экспорта финансовых операций
struct FinancialExportConfig {
    /// Формат экспорта
    enum ExportFormat {
        case excel
        case pdf
    }
    
    /// Диапазон дат
    var dateRange: DateInterval?
    
    /// Включённые типы операций
    var includedOperationTypes: Set<FinancialOperationEntity.OperationType>
    
    /// Группировка операций
    enum GroupBy {
        case none
        case type
        case account
    }
    
    var groupBy: GroupBy = .none
    
    /// Разбивать по листам (для Excel)
    var splitBySheets: Bool = true
    
    /// Включать сводку
    var includeSummary: Bool = true
    
    /// Формат экспорта
    var format: ExportFormat = .excel
    
    /// Включать все операции по умолчанию
    init() {
        self.includedOperationTypes = [.sale, .refund, .expense, .transfer]
        self.dateRange = nil
    }
    
    /// Проверка валидности конфигурации
    func validate() throws {
        guard !includedOperationTypes.isEmpty else {
            throw FinancialExportError.invalidConfiguration(message: "Необходимо выбрать хотя бы один тип операции")
        }
        
        if let range = dateRange {
            guard range.duration > 0 else {
                throw FinancialExportError.invalidConfiguration(message: "Неверный диапазон дат")
            }
        }
    }
}

enum FinancialExportError: LocalizedError {
    case invalidConfiguration(message: String)
    case unableToCreateFile
    case noData
    case exportFailed(message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return "Ошибка конфигурации: \(message)"
        case .unableToCreateFile:
            return "Не удалось создать файл"
        case .noData:
            return "Нет данных для экспорта"
        case .exportFailed(let message):
            return "Ошибка экспорта: \(message)"
        }
    }
}
