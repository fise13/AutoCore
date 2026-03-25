import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

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
        
        let dbPath = databaseService.databaseFileURL.path
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw BackupError.backupNotFound
        }
        
        // Получаем версию схемы БД (выполняем вне MainActor для избежания deadlock)
        let schemaVersion = try await Task.detached {
            try self.databaseService.getSchemaVersion()
        }.value
        
        // Получаем версию приложения
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        // Получаем имя устройства (для iOS используем UIDevice, для macOS — Host)
        #if os(macOS)
        let deviceName = Host.current().localizedName ?? Host.current().name ?? "Unknown"
        #else
        let deviceName = UIDevice.current.name
        #endif
        
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
