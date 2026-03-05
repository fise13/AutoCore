//
//  CloudKitRoleSeeder.swift
//  AutoCore
//
//  Создаёт в CloudKit Public Database записи UserRole по email (для назначения ролей без ручной настройки в Dashboard).
//

import Foundation
import CloudKit

enum CloudKitRoleSeeder {
    private static let containerID = "iCloud.fise.AutoCore"
    
    /// Пары email → роль для начальной настройки
    private static let defaultRoles: [(email: String, role: UserRole)] = [
        ("victhewise@icloud.com", .accountant),
        ("iskanderamiri@icloud.com", .admin)
    ]
    
    /// Создаёт записи UserRole в Public Database. Вызовите один раз (например, из Настроек → Продвинутые).
    /// Если запись с таким email уже есть — она будет обновлена.
    static func createDefaultRoleRecords() async throws {
        let container = CKContainer(identifier: containerID)
        let publicDB = container.publicCloudDatabase
        let zoneID = CKRecordZone.default().zoneID
        
        let defaultCompanyId = "default"
        for (email, role) in defaultRoles {
            let recordName = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
            let record = CKRecord(recordType: "UserRole", recordID: recordID)
            record["role"] = role.rawValue
            record["companyId"] = defaultCompanyId
            _ = try await publicDB.save(record)
        }
    }
}
