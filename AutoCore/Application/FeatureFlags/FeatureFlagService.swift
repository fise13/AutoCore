import Foundation
import Combine

/// Feature Flag Service
/// Управляет включением/выключением функциональности без изменения кода
@MainActor
final class FeatureFlagService: ObservableObject {
    private let database: DatabaseService
    @Published private var flags: [String: Bool] = [:] // @Published для обновления UI
    private var isInitialized = false
    
    /// Стандартные feature flags
    enum Flag: String, CaseIterable {
        case batchOperations = "batch_operations"
        case experimentalFilters = "experimental_filters"
        case newImport = "new_import"
        case softDelete = "soft_delete"
        case inlineActions = "inline_actions"
        
        /// Значение по умолчанию
        var defaultValue: Bool {
            switch self {
            case .batchOperations:
                return true
            case .experimentalFilters:
                return false
            case .newImport:
                return false
            case .softDelete:
                return true
            case .inlineActions:
                return true
            }
        }
        
        /// Описание фичи
        var description: String {
            switch self {
            case .batchOperations:
                return "Массовые операции над моторами"
            case .experimentalFilters:
                return "Экспериментальные фильтры"
            case .newImport:
                return "Новый импорт Excel"
            case .softDelete:
                return "Мягкое удаление моторов"
            case .inlineActions:
                return "Действия в таблице моторов"
            }
        }
    }
    
    init(database: DatabaseService) {
        self.database = database
        Task { @MainActor in
            try? await self.loadFlags()
        }
    }
    
    /// Загрузка флагов из БД
    func loadFlags() async throws {
        guard !isInitialized else { return }
        
        // Загружаем флаги из БД
        let database = self.database
        let storedFlags = try await Task.detached {
            return try database.fetchFeatureFlags()
        }.value
        
        // Инициализируем все флаги значениями по умолчанию
        for flag in Flag.allCases {
            flags[flag.rawValue] = flag.defaultValue
        }
        
        // Перезаписываем значениями из БД
        for (key, value) in storedFlags {
            flags[key] = value
        }
        
        isInitialized = true
    }
    
    func isEnabled(_ flag: Flag) -> Bool {
        let storedValue = flags[flag.rawValue]
        return storedValue ?? flag.defaultValue
    }

    func setEnabled(_ flag: Flag, enabled: Bool) throws {
        flags[flag.rawValue] = enabled
        try database.saveFeatureFlag(name: flag.rawValue, enabled: enabled)
    }
    
    /// Получить все флаги
    func getAllFlags() -> [Flag: Bool] {
        var result: [Flag: Bool] = [:]
        for flag in Flag.allCases {
            result[flag] = isEnabled(flag)
        }
        return result
    }
}
