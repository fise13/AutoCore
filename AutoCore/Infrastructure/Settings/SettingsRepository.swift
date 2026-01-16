import Foundation

/// Settings Repository Interface
/// Определяет контракт для хранения настроек
protocol SettingsRepository {
    func loadSettings() throws -> AppSettings
    func saveSettings(_ settings: AppSettings) throws
}

/// Implementation: SQLite Settings Repository
/// Хранит настройки в таблице app_settings в SQLite
final class SQLiteSettingsRepository: SettingsRepository {
    private let database: DatabaseService
    private let logger: LoggingService
    
    init(database: DatabaseService, logger: LoggingService = .shared) {
        self.database = database
        self.logger = logger
        createSettingsTableIfNeeded()
    }
    
    func loadSettings() throws -> AppSettings {
        // Пытаемся загрузить из БД
        if let jsonString = try? database.getSettingsJSON(),
           let data = jsonString.data(using: .utf8) {
            let decoder = JSONDecoder()
            if let settings = try? decoder.decode(AppSettings.self, from: data) {
                return settings
            }
        }
        
        // Если не удалось загрузить, возвращаем настройки по умолчанию
        logger.warning("Failed to load settings from database, using defaults")
        return .default
    }
    
    func saveSettings(_ settings: AppSettings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(settings),
              let jsonString = String(data: data, encoding: .utf8) else {
            throw SettingsError.encodingFailed
        }
        
        try database.saveSettingsJSON(jsonString)
        logger.info("Settings saved to database")
    }
    
    // MARK: - Private
    
    private func createSettingsTableIfNeeded() {
        // Таблица создается через миграцию DatabaseService
        // Этот метод оставлен для совместимости, но не вызывается
    }
}

enum SettingsError: Error {
    case encodingFailed
    case decodingFailed
    case databaseError(String)
}
