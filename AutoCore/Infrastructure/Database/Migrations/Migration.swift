import Foundation

/// Base protocol for database migrations
protocol Migration {
    var version: Int { get }
    var description: String { get }
    
    func up(database: DatabaseService) throws
    func down(database: DatabaseService) throws
}

/// Migration Manager
final class MigrationManager {
    private let database: DatabaseService
    private let migrations: [Migration]
    
    init(database: DatabaseService, migrations: [Migration]) {
        self.database = database
        self.migrations = migrations.sorted { $0.version < $1.version }
    }
    
    func migrate() throws {
        let currentVersion = try getCurrentVersion()
        let targetVersion = migrations.last?.version ?? 0
        
        guard currentVersion < targetVersion else {
            return // Already up to date
        }
        
        for migration in migrations where migration.version > currentVersion {
            try executeMigration(migration)
        }
    }
    
    private func getCurrentVersion() throws -> Int {
        // Проверяем существование таблицы schema_version
        let tableExists = try database.tableExists("schema_version")
        
        if !tableExists {
            // Создаем таблицу schema_version
            try database.executeSQL("""
                CREATE TABLE IF NOT EXISTS schema_version (
                    version INTEGER NOT NULL,
                    applied_at TEXT NOT NULL DEFAULT (datetime('now'))
                );
            """)
            return 0
        }
        
        let versionValue = try database.getSingleInt64(sql: "SELECT version FROM schema_version ORDER BY version DESC LIMIT 1;")
        return Int(versionValue)
    }
    
    private func executeMigration(_ migration: Migration) throws {
        // Каждая миграция выполняется в транзакции
        try database.inTransaction {
            try migration.up(database: database)
            
            // Обновляем версию схемы
            try database.executeSQL("DELETE FROM schema_version;")
            // Используем прямой SQL (без параметров для простоты)
            let versionSQL = "INSERT INTO schema_version (version, applied_at) VALUES (\(migration.version), datetime('now'));"
            try database.executeSQL(versionSQL)
        }
    }
}
