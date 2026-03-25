import Foundation

/// Resolves per-user SQLite file URLs under Application Support.
enum DatabaseFileLocator {
    static let legacyFileName = "autocore.sqlite"
    private static let folderComponent = "AutoCore"

    static func applicationSupportAutoCoreFolder() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = appSupport.appendingPathComponent(folderComponent, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func legacyDatabaseURL() throws -> URL {
        try applicationSupportAutoCoreFolder().appendingPathComponent(legacyFileName)
    }

    static func perUserDatabaseURL(userId: String) throws -> URL {
        try applicationSupportAutoCoreFolder().appendingPathComponent("autocore_\(sanitizedUserId(userId)).sqlite")
    }

    /// If the per-user file does not exist but the legacy shared file does, move legacy to the per-user path (once).
    static func resolveDatabaseURL(forUserId userId: String) throws -> URL {
        let folder = try applicationSupportAutoCoreFolder()
        let target = try perUserDatabaseURL(userId: userId)
        let legacy = folder.appendingPathComponent(legacyFileName)
        let fm = FileManager.default
        if !fm.fileExists(atPath: target.path), fm.fileExists(atPath: legacy.path) {
            try fm.moveItem(at: legacy, to: target)
            LoggingService.shared.info("Migrated legacy database to per-user file: \(target.lastPathComponent)")
        }
        return target
    }

    static func backupsDirectoryURL() throws -> URL {
        let dir = try applicationSupportAutoCoreFolder().appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func sanitizedUserId(_ id: String) -> String {
        id.unicodeScalars.map { scalar in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" {
                return String(scalar)
            }
            return "_"
        }.joined()
    }
}
