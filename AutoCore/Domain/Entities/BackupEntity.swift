import Foundation

/// Domain Entity: Backup
/// Представляет бэкап базы данных
struct BackupEntity: Identifiable, Equatable {
    let id: String
    let createdAt: Date
    let size: Int64
    let fileName: String
    let filePath: String
    let appVersion: String
    let deviceName: String
    let schemaVersion: Int
    
    /// Metadata для бэкапа
    struct Metadata: Codable {
        let createdAt: Date
        let appVersion: String
        let deviceName: String
        let schemaVersion: Int
        
        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
            case appVersion = "app_version"
            case deviceName = "device_name"
            case schemaVersion = "schema_version"
        }
    }
    
    /// Создать Metadata из сущности
    func toMetadata() -> Metadata {
        Metadata(
            createdAt: createdAt,
            appVersion: appVersion,
            deviceName: deviceName,
            schemaVersion: schemaVersion
        )
    }
    
    /// Создать сущность из Metadata и файла
    static func from(metadata: Metadata, filePath: String, fileName: String, size: Int64) -> BackupEntity {
        BackupEntity(
            id: UUID().uuidString,
            createdAt: metadata.createdAt,
            size: size,
            fileName: fileName,
            filePath: filePath,
            appVersion: metadata.appVersion,
            deviceName: metadata.deviceName,
            schemaVersion: metadata.schemaVersion
        )
    }
}
