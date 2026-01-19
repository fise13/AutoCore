import Foundation

/// Use Case: Create Backup
@MainActor
final class CreateBackupUseCase {
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
    
    /// Выполнить создание бэкапа
    func execute() async throws -> BackupEntity {
        try recoveryState?.assertNotInRecoveryMode()
        
        let correlationID = UUIDv7.generateString()
        logger.info("Creating backup", correlationID: correlationID)
        
        // Получаем путь к БД
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbPath = appSupport.appendingPathComponent("AutoCore/autocore.sqlite").path
        
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw BackupError.backupNotFound
        }
        
        // Получаем версию схемы БД (выполняем вне MainActor для избежания deadlock)
        let schemaVersion = try await Task.detached {
            try self.databaseService.getSchemaVersion()
        }.value
        
        // Получаем версию приложения
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        // Получаем имя устройства
        let deviceName = Host.current().localizedName ?? Host.current().name ?? "Unknown"
        
        // Создаём metadata
        let metadata = BackupEntity.Metadata(
            createdAt: Date(),
            appVersion: appVersion,
            deviceName: deviceName,
            schemaVersion: schemaVersion
        )
        
        // Создаём бэкап
        let backup = try backupRepository.createBackup(
            databasePath: dbPath,
            metadata: metadata
        )
        
        logger.info("Backup created successfully: \(backup.fileName)", correlationID: correlationID)
        
        return backup
    }
}
