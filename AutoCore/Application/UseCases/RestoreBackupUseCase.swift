import Foundation

/// Use Case: Restore Backup
@MainActor
final class RestoreBackupUseCase {
    private let backupRepository: BackupRepository
    private let databaseService: DatabaseService
    private let logger: LoggingService
    private let recoveryState: RecoveryState?
    
    init(
        backupRepository: BackupRepository,
        databaseService: DatabaseService,
        logger: LoggingService = .shared,
        recoveryState: RecoveryState? = nil
    ) {
        self.backupRepository = backupRepository
        self.databaseService = databaseService
        self.logger = logger
        self.recoveryState = recoveryState
    }
    
    /// Выполнить восстановление из бэкапа
    func execute(backup: BackupEntity) throws {
        try recoveryState?.assertNotInRecoveryMode()
        
        let correlationID = UUIDv7.generateString()
        logger.info("Restoring from backup: \(backup.fileName)", correlationID: correlationID)
        
        // Проверяем версию схемы
        let currentSchemaVersion = try databaseService.getSchemaVersion()
        if backup.schemaVersion > currentSchemaVersion {
            logger.warning("Backup schema version (\(backup.schemaVersion)) is newer than current (\(currentSchemaVersion))", correlationID: correlationID)
            // Не блокируем восстановление, но предупреждаем
        }
        
        // Распаковываем бэкап во временную папку
        let tempDir = try backupRepository.extractToTemp(backup)
        defer {
            // Удаляем временную папку после использования
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let databaseFile = tempDir.appendingPathComponent("database.sqlite")
        
        guard FileManager.default.fileExists(atPath: databaseFile.path) else {
            throw BackupError.invalidMetadata
        }
        
        let currentDBPath = databaseService.databaseFileURL
        databaseService.closeForTeardown()

        if FileManager.default.fileExists(atPath: currentDBPath.path) {
            let backupCurrentPath = currentDBPath.path + ".backup_\(Int(Date().timeIntervalSince1970))"
            try FileManager.default.copyItem(atPath: currentDBPath.path, toPath: backupCurrentPath)
            logger.info("Current database backed up to: \(backupCurrentPath)", correlationID: correlationID)
        }

        if FileManager.default.fileExists(atPath: currentDBPath.path) {
            try FileManager.default.removeItem(at: currentDBPath)
        }

        try FileManager.default.copyItem(at: databaseFile, to: currentDBPath)
        
        logger.info("Backup restored successfully", correlationID: correlationID)
    }
}
