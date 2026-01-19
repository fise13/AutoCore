import Foundation

/// Repository Interface for Backup Entity
protocol BackupRepository {
    /// Создать бэкап
    func createBackup(databasePath: String, metadata: BackupEntity.Metadata) throws -> BackupEntity
    
    /// Получить список всех бэкапов
    func findAll() throws -> [BackupEntity]
    
    /// Найти бэкап по ID
    func findByID(_ id: String) throws -> BackupEntity?
    
    /// Удалить бэкап
    func delete(_ backup: BackupEntity) throws
    
    /// Распаковать бэкап во временную папку
    func extractToTemp(_ backup: BackupEntity) throws -> URL
    
    /// Получить путь к папке с бэкапами
    func getBackupsDirectory() throws -> URL
}
