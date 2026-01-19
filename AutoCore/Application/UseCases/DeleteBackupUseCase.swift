import Foundation

/// Use Case: Delete Backup
@MainActor
final class DeleteBackupUseCase {
    private let backupRepository: BackupRepository
    private let logger: LoggingService
    
    init(
        backupRepository: BackupRepository,
        logger: LoggingService = .shared
    ) {
        self.backupRepository = backupRepository
        self.logger = logger
    }
    
    /// Выполнить удаление бэкапа
    func execute(backup: BackupEntity) throws {
        let correlationID = UUIDv7.generateString()
        logger.info("Deleting backup: \(backup.fileName)", correlationID: correlationID)
        
        try backupRepository.delete(backup)
        
        logger.info("Backup deleted successfully", correlationID: correlationID)
    }
}
