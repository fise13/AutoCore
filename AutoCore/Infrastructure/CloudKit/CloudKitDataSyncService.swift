//
//  CloudKitDataSyncService.swift
//  AutoCore
//
//  Синхронизация данных бухгалтерии с CloudKit: push при сохранении, pull при запуске.
//  Данные привязаны к companyId — у админа и бухгалтера один companyId, оба видят одни и те же операции.
//

import Foundation
import CloudKit

/// Сервис синхронизации финансовых операций с CloudKit (Public Database)
@MainActor
final class CloudKitDataSyncService {
    private let container: CKContainer
    private let publicDB: CKDatabase
    private let database: DatabaseService
    
    static let recordTypeFinancialOperation = "FinancialOperation"
    
    init(containerIdentifier: String = "iCloud.fise.AutoCore", database: DatabaseService) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.publicDB = container.publicCloudDatabase
        self.database = database
    }
    
    // MARK: - Push (сохранение в CloudKit)
    
    /// Сохраняет финансовую операцию в CloudKit. Возвращает recordName (UUID) для записи в cloud_record_id.
    func pushFinancialOperation(_ entity: FinancialOperationEntity, companyId: String, cloudRecordId: String?) async throws -> String {
        let recordName = cloudRecordId ?? UUID().uuidString
        let zoneID = CKRecordZone.default().zoneID
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        let record = CKRecord(recordType: Self.recordTypeFinancialOperation, recordID: recordID)
        
        record["companyId"] = companyId
        record["type"] = entity.type.rawValue
        record["amount"] = String(describing: entity.amount)
        record["paymentMethod"] = entity.paymentMethod.rawValue
        record["cashReceived"] = entity.cashReceived.map { String(describing: $0) }
        record["changeGiven"] = entity.changeGiven.map { String(describing: $0) }
        record["account"] = entity.account.rawValue
        record["relatedMotorID"] = entity.relatedMotorID
        record["createdAt"] = ISO8601DateFormatter().string(from: entity.createdAt)
        record["createdByUser"] = entity.createdByUser
        record["comment"] = entity.comment
        record["source"] = entity.source
        record["details"] = entity.details
        record["category"] = entity.category
        record["description"] = entity.description
        
        _ = try await publicDB.save(record)
        return recordName
    }
    
    // MARK: - Pull (загрузка из CloudKit и слияние в локальную БД)
    
    /// Загружает все финансовые операции компании из CloudKit и сливает в локальную БД.
    func pullAndMergeFinancialOperations(companyId: String) async throws {
        let query = CKQuery(recordType: Self.recordTypeFinancialOperation, predicate: NSPredicate(format: "companyId == %@", companyId))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let result = if let c = cursor {
                try await publicDB.records(continuingMatchFrom: c)
            } else {
                try await publicDB.records(matching: query)
            }
            let (matchResults, nextCursor) = result
            cursor = nextCursor
            for (_, res) in matchResults {
                if case .success(let record) = res {
                    allRecords.append(record)
                }
            }
        } while cursor != nil
        
        let dateFormatter = ISO8601DateFormatter()
        let decimalFormatter: (String) -> Decimal? = { Decimal(string: $0) }
        
        for record in allRecords {
            let recordName = record.recordID.recordName
            if try database.fetchFinancialOperationByCloudRecordId(recordName) != nil {
                continue
            }
            guard let typeRaw = record["type"] as? String,
                  let amountStr = record["amount"] as? String,
                  let amount = decimalFormatter(amountStr),
                  let paymentMethodRaw = record["paymentMethod"] as? String,
                  let accountRaw = record["account"] as? String,
                  let createdAtStr = record["createdAt"] as? String,
                  let createdAt = dateFormatter.date(from: createdAtStr),
                  let createdByUser = record["createdByUser"] as? String else {
                continue
            }
            let comment = record["comment"] as? String ?? ""
            let source = record["source"] as? String ?? ""
            let details = record["details"] as? String ?? ""
            let category = record["category"] as? String
            let description = record["description"] as? String ?? details
            let cashReceived = (record["cashReceived"] as? String).flatMap { decimalFormatter($0) }
            let changeGiven = (record["changeGiven"] as? String).flatMap { decimalFormatter($0) }
            let relatedMotorID = record["relatedMotorID"] as? Int64
            
            _ = try database.insertFinancialOperation(
                type: typeRaw,
                amount: amount,
                paymentMethod: paymentMethodRaw,
                cashReceived: cashReceived,
                changeGiven: changeGiven,
                account: accountRaw,
                relatedMotorID: relatedMotorID,
                createdAt: createdAt,
                createdByUser: createdByUser,
                comment: comment,
                source: source,
                details: details,
                category: category,
                description: description,
                cloudRecordId: recordName
            )
        }
    }
}
