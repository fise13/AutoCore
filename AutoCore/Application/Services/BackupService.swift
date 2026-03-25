import Foundation
import Combine

/// Backup Service
/// Управляет автоматическими и ручными бэкапами базы данных
@MainActor
final class BackupService: ObservableObject {
    private let database: DatabaseService
    private let logger: LoggingService
    private var lastBackupDate: Date?
    private var backupTimer: Timer?
    
    /// Максимальное количество бэкапов (по умолчанию 30)
    var maxBackups: Int = 30
    
    /// Интервал автоматического бэкапа (по умолчанию 24 часа)
    var autoBackupInterval: TimeInterval = 24 * 60 * 60
    
    @Published private(set) var lastBackup: Date?
    @Published private(set) var backups: [BackupInfo] = []
    
    struct BackupInfo: Identifiable {
        let id: String
        let path: String
        let date: Date
        let size: Int64
        
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        var formattedSize: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size)
        }
    }
    
    init(database: DatabaseService, logger: LoggingService = .shared) {
        self.database = database
        self.logger = logger
        loadBackups()
        startAutoBackupTimer()
    }
    
    deinit {
        backupTimer?.invalidate()
    }
    
    /// Создать бэкап
    func createBackup() throws -> BackupInfo {
        let correlationID = UUIDv7.generateString()
        logger.info("Creating backup", correlationID: correlationID)
        
        let backupPath = try database.createBackup()
        
        // Получаем информацию о файле
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: backupPath)
        let size = attributes[.size] as? Int64 ?? 0
        let date = attributes[.modificationDate] as? Date ?? Date()
        
        let backupInfo = BackupInfo(
            id: UUID().uuidString,
            path: backupPath,
            date: date,
            size: size
        )
        
        lastBackup = date
        loadBackups()
        
        logger.info("Backup created: \(backupPath)", correlationID: correlationID)
        
        return backupInfo
    }
    
    /// Загрузить список бэкапов
    func loadBackups() {
        let maxBackups = self.maxBackups
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            let appSupport = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            
            guard let appSupport = appSupport else { return }
            let backupDir = appSupport.appendingPathComponent("AutoCore/backups")
            
            guard fileManager.fileExists(atPath: backupDir.path) else {
                await MainActor.run { [weak self] in
                    self?.backups = []
                }
                return
            }
            
            var backupList: [BackupInfo] = []
            
            do {
                let files = try fileManager.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
                
                for file in files {
                    guard file.pathExtension == "db" || file.pathExtension == "sqlite" else { continue }
                    
                    let attributes = try file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    let size = attributes.fileSize ?? 0
                    let date = attributes.contentModificationDate ?? Date()
                    
                    backupList.append(BackupInfo(
                        id: file.lastPathComponent,
                        path: file.path,
                        date: date,
                        size: Int64(size)
                    ))
                }
                
                // Сортируем по дате (новые первыми)
                backupList.sort { $0.date > $1.date }
                
                // Ограничиваем количество
                if backupList.count > maxBackups {
                    let toDelete = backupList.suffix(backupList.count - maxBackups)
                    for backup in toDelete {
                        try? fileManager.removeItem(atPath: backup.path)
                    }
                    backupList = Array(backupList.prefix(maxBackups))
                }
                
            } catch {
                print("Failed to load backups: \(error)")
            }
            
            // Сохраняем результат до перехода на MainActor
            let finalBackupList = backupList
            let finalLastBackup = backupList.first?.date
            
            await MainActor.run { [weak self] in
                self?.backups = finalBackupList
                self?.lastBackup = finalLastBackup
            }
        }
    }
    
    /// Восстановить из бэкапа
    func restore(from backup: BackupInfo) throws {
        let correlationID = UUIDv7.generateString()
        logger.info("Restoring from backup: \(backup.path)", correlationID: correlationID)
        
        let fileManager = FileManager.default
        let dbPath = database.databaseFileURL
        database.closeForTeardown()

        if fileManager.fileExists(atPath: dbPath.path) {
            let backupCurrentPath = dbPath.path + ".backup_\(Int(Date().timeIntervalSince1970))"
            try fileManager.copyItem(atPath: dbPath.path, toPath: backupCurrentPath)
        }

        try fileManager.copyItem(atPath: backup.path, toPath: dbPath.path)
        
        logger.info("Backup restored successfully", correlationID: correlationID)
    }
    
    /// Удалить бэкап
    func deleteBackup(_ backup: BackupInfo) throws {
        let fileManager = FileManager.default
        try fileManager.removeItem(atPath: backup.path)
        loadBackups()
    }
    
    /// Запустить таймер автоматического бэкапа
    private func startAutoBackupTimer() {
        backupTimer?.invalidate()
        
        let interval = autoBackupInterval
        backupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? self?.createBackup()
            }
        }
    }
    
    /// Создать бэкап перед операцией (например, импортом)
    func createBackupBeforeOperation() throws {
        // Проверяем, нужен ли бэкап (если последний был более часа назад)
        if let lastBackup = lastBackup,
           Date().timeIntervalSince(lastBackup) < 3600 {
            return // Недавно был бэкап
        }
        
        _ = try createBackup() // Результат не используется, но нужно обработать ошибку
    }
}
