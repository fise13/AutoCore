import Foundation

/// Use Case: List Backups
@MainActor
final class ListBackupsUseCase {
    private let backupRepository: BackupRepository
    private let logger: LoggingService
    
    init(
        backupRepository: BackupRepository,
        logger: LoggingService = .shared
    ) {
        self.backupRepository = backupRepository
        self.logger = logger
    }
    
    /// Выполнить получение списка бэкапов
    func execute() throws -> [BackupEntity] {
        let correlationID = UUIDv7.generateString()
        logger.info("Loading backups list", correlationID: correlationID)
        
        let backups = try backupRepository.findAll()
        
        logger.info("Loaded \(backups.count) backups", correlationID: correlationID)
        
        return backups
    }
}
