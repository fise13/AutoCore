import Foundation
import ZIPFoundation

/// Infrastructure implementation of BackupRepository
/// Использует локальную файловую систему и ZIP архивы
final class BackupRepositoryLocalImpl: BackupRepository {
    private let fileManager = FileManager.default
    private let backupsDirectoryName = "Backups"
    
    /// Получить путь к папке с бэкапами: ~/Documents/AutoCore/Backups/
    func getBackupsDirectory() throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let backupsURL = documentsURL
            .appendingPathComponent("AutoCore", isDirectory: true)
            .appendingPathComponent(backupsDirectoryName, isDirectory: true)
        
        // Создаём папку, если её нет
        if !fileManager.fileExists(atPath: backupsURL.path) {
            try fileManager.createDirectory(
                at: backupsURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        return backupsURL
    }
    
    /// Создать бэкап
    func createBackup(databasePath: String, metadata: BackupEntity.Metadata) throws -> BackupEntity {
        let backupsDir = try getBackupsDirectory()
        
        // Формируем имя файла: AutoCore_Backup_YYYY-MM-DD_HH-mm.zip
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let timestamp = dateFormatter.string(from: metadata.createdAt)
        let fileName = "AutoCore_Backup_\(timestamp).zip"
        let backupURL = backupsDir.appendingPathComponent(fileName)
        
        // Удаляем существующий файл, если есть
        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }
        
        // Создаём ZIP архив
        guard let archive = Archive(url: backupURL, accessMode: .create) else {
            throw BackupError.unableToCreateArchive
        }
        
        // 1. Добавляем database.sqlite
        let databaseURL = URL(fileURLWithPath: databasePath)
        guard let databaseData = try? Data(contentsOf: databaseURL) else {
            throw BackupError.unableToCreateArchive
        }
        
        try archive.addEntry(
            with: "database.sqlite",
            type: .file,
            uncompressedSize: Int64(databaseData.count),
            compressionMethod: .deflate
        ) { position, size in
            databaseData.subdata(in: Int(position)..<Int(position) + size)
        }
        
        // 2. Создаём metadata.json
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let metadataData = try encoder.encode(metadata)
        
        try archive.addEntry(
            with: "metadata.json",
            type: .file,
            uncompressedSize: Int64(metadataData.count),
            compressionMethod: .deflate
        ) { position, size in
            metadataData.subdata(in: Int(position)..<Int(position) + size)
        }
        
        // Получаем размер файла
        let attributes = try fileManager.attributesOfItem(atPath: backupURL.path)
        let size = attributes[.size] as? Int64 ?? 0
        
        // Создаём сущность
        return BackupEntity.from(
            metadata: metadata,
            filePath: backupURL.path,
            fileName: fileName,
            size: size
        )
    }
    
    /// Получить список всех бэкапов
    func findAll() throws -> [BackupEntity] {
        let backupsDir = try getBackupsDirectory()
        
        guard fileManager.fileExists(atPath: backupsDir.path) else {
            return []
        }
        
        let files = try fileManager.contentsOfDirectory(
            at: backupsDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        
        var backups: [BackupEntity] = []
        
        for fileURL in files {
            guard fileURL.pathExtension == "zip" else { continue }
            
            // Читаем metadata из ZIP
            guard let archive = Archive(url: fileURL, accessMode: .read) else {
                continue
            }
            
            guard let metadataEntry = archive["metadata.json"] else {
                continue
            }
            
            var metadataData = Data()
            _ = try archive.extract(metadataEntry) { data in
                metadataData.append(data)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadata = try decoder.decode(BackupEntity.Metadata.self, from: metadataData)
            
            // Получаем размер файла
            let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            let size = Int64(attributes.fileSize ?? 0)
            
            let backup = BackupEntity.from(
                metadata: metadata,
                filePath: fileURL.path,
                fileName: fileURL.lastPathComponent,
                size: size
            )
            
            backups.append(backup)
        }
        
        // Сортируем по дате (новые первыми)
        backups.sort { $0.createdAt > $1.createdAt }
        
        return backups
    }
    
    /// Найти бэкап по ID
    func findByID(_ id: String) throws -> BackupEntity? {
        let allBackups = try findAll()
        return allBackups.first { $0.id == id }
    }
    
    /// Удалить бэкап
    func delete(_ backup: BackupEntity) throws {
        guard fileManager.fileExists(atPath: backup.filePath) else {
            throw BackupError.backupNotFound
        }
        
        try fileManager.removeItem(atPath: backup.filePath)
    }
    
    /// Распаковать бэкап во временную папку
    func extractToTemp(_ backup: BackupEntity) throws -> URL {
        let backupURL = URL(fileURLWithPath: backup.filePath)
        
        guard let archive = Archive(url: backupURL, accessMode: .read) else {
            throw BackupError.unableToReadArchive
        }
        
        // Создаём временную папку
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("AutoCore_Restore_\(UUID().uuidString)", isDirectory: true)
        
        try fileManager.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Распаковываем все файлы
        for entry in archive {
            let destinationURL = tempDir.appendingPathComponent(entry.path)
            
            // Создаём директории, если нужно
            let destinationDir = destinationURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: destinationDir.path) {
                try fileManager.createDirectory(
                    at: destinationDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
            
            // Распаковываем файл
            var extractedData = Data()
            _ = try archive.extract(entry) { data in
                extractedData.append(data)
            }
            if !extractedData.isEmpty {
                try extractedData.write(to: destinationURL)
            }
        }
        
        return tempDir
    }
}

enum BackupError: LocalizedError {
    case unableToCreateArchive
    case unableToReadArchive
    case backupNotFound
    case invalidMetadata
    case schemaVersionMismatch
    
    var errorDescription: String? {
        switch self {
        case .unableToCreateArchive:
            return "Не удалось создать архив бэкапа"
        case .unableToReadArchive:
            return "Не удалось прочитать архив бэкапа"
        case .backupNotFound:
            return "Бэкап не найден"
        case .invalidMetadata:
            return "Неверные метаданные бэкапа"
        case .schemaVersionMismatch:
            return "Версия схемы БД не совпадает"
        }
    }
}
