//
//  FirestoreFinancialSyncService.swift
//  AutoCore
//
//  Реализация FinancialSyncService через Firestore.
//  Push при сохранении, pull при запуске (macOS). iOS читает напрямую через запросы.
//

import Foundation
import FirebaseFirestore

final class FirestoreFinancialSyncService: FinancialSyncService {
    private let db = Firestore.firestore()
    private let logger = LoggingService.shared
    
    static let collectionName = "financialOperations"
    
    func pushOperation(_ entity: FinancialOperationEntity, companyId: String) async throws -> String {
        try await pushOperation(entity, companyId: companyId, documentId: nil)
    }
    
    /// Пуш с опциональным documentId (для выгрузки локальных операций без дубликатов).
    func pushOperation(_ entity: FinancialOperationEntity, companyId: String, documentId: String?) async throws -> String {
        guard !companyId.isEmpty else {
            throw NSError(domain: "FinancialSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "companyId is required for push"])
        }
        let docId = documentId ?? UUID().uuidString
        let data: [String: Any] = [
            "companyId": companyId,
            "type": entity.type.rawValue,
            "amount": NSDecimalNumber(decimal: entity.amount).doubleValue,
            "paymentMethod": entity.paymentMethod.rawValue,
            "cashReceived": entity.cashReceived.map { NSDecimalNumber(decimal: $0).doubleValue } as Any,
            "changeGiven": entity.changeGiven.map { NSDecimalNumber(decimal: $0).doubleValue } as Any,
            "account": entity.account.rawValue,
            "relatedMotorID": entity.relatedMotorID as Any,
            "createdAt": Timestamp(date: entity.createdAt),
            "createdByUserId": entity.createdByUser,
            "comment": entity.comment,
            "source": entity.source,
            "details": entity.details,
            "category": entity.category as Any,
            "description": entity.description
        ]
        
        logger.info("Firestore PUSH start: docId=\(docId), companyId=\(companyId)")
        do {
            try await db.collection(Self.collectionName).document(docId).setData(data)
            logger.info("Firestore PUSH success: docId=\(docId)")
            return docId
        } catch {
            logger.error("Firestore PUSH failed", error: error)
            throw error
        }
    }
    
    func pullOperations(companyId: String, since: Date?) async throws -> [FinancialOperationEntity] {
        guard !companyId.isEmpty else { return [] }
        
        var query: Query = db.collection(Self.collectionName)
            .whereField("companyId", isEqualTo: companyId)
        
        if let since = since {
            query = query.whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: since))
        }
        query = query.order(by: "createdAt", descending: false)
        
        let snapshot = try await query.getDocuments()
        var entities: [FinancialOperationEntity] = []
        
        for doc in snapshot.documents {
            guard let entity = mapDocumentToEntity(doc) else { continue }
            entities.append(entity)
        }
        
        logger.info("Firestore PULL fetched: count=\(entities.count) for companyId=\(companyId)")
        return entities
    }

    func observeOperations(companyId: String) -> AsyncStream<[FinancialOperationEntity]> {
        AsyncStream { continuation in
            guard !companyId.isEmpty else {
                continuation.yield([])
                continuation.finish()
                return
            }
            let query = db.collection(Self.collectionName)
                .whereField("companyId", isEqualTo: companyId)
                .order(by: "createdAt", descending: false)
            let listener = query.addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.logger.error("Firestore observe error", error: error)
                    continuation.yield([])
                    return
                }
                guard let snapshot else {
                    continuation.yield([])
                    return
                }
                let entities = snapshot.documents.compactMap { self.mapDocumentToEntity($0) }
                self.logger.info("Firestore OBSERVE: count=\(entities.count), fromCache=\(snapshot.metadata.isFromCache)")
                continuation.yield(entities)
            }
            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
    
    /// Сливает список операций из Firestore в локальную БД (без дубликатов). Используется при pull и при observe.
    func mergeEntitiesIntoDatabase(_ entities: [FinancialOperationEntity], companyId: String, database: DatabaseService) async throws {
        var insertedCount = 0
        for entity in entities {
            do {
                var filter = DatabaseService.FinancialOperationFilter()
                filter.companyId = companyId
                filter.type = entity.type
                filter.account = entity.account
                let fromDate = entity.createdAt.addingTimeInterval(-1)
                let toDate = entity.createdAt.addingTimeInterval(1)
                filter.fromDate = fromDate
                filter.toDate = toDate
                
                let existing = try database.fetchFinancialOperations(filter: filter).first(where: {
                    $0.amount == entity.amount &&
                    $0.createdByUser == entity.createdByUser &&
                    $0.comment == entity.comment &&
                    $0.details == entity.details
                })
                
                if existing != nil { continue }
                
                _ = try database.insertFinancialOperation(
                    type: entity.type.rawValue,
                    amount: entity.amount,
                    paymentMethod: entity.paymentMethod.rawValue,
                    cashReceived: entity.cashReceived,
                    changeGiven: entity.changeGiven,
                    account: entity.account.rawValue,
                    relatedMotorID: entity.relatedMotorID,
                    createdAt: entity.createdAt,
                    createdByUser: entity.createdByUser,
                    comment: entity.comment,
                    source: entity.source,
                    details: entity.details,
                    category: entity.category,
                    description: entity.description,
                    cloudRecordId: nil,
                    companyId: companyId
                )
                insertedCount += 1
            } catch {
                logger.error("Firestore PULL: failed to merge operation type=\(entity.type.rawValue), amount=\(entity.amount)", error: error)
                continue
            }
        }
        
        logger.info("Firestore MERGE into local DB: inserted=\(insertedCount)")
    }
    
    func pullAndMergeFinancialOperations(companyId: String, database: DatabaseService) async throws {
        let entities = try await pullOperations(companyId: companyId, since: nil)
        try await mergeEntitiesIntoDatabase(entities, companyId: companyId, database: database)
    }
    
    /// Выгружает локальные операции Mac в Firestore (чтобы iOS их видел). Документ id = "local-\(op.id)" для идемпотентности.
    func pushLocalOperationsToFirestore(companyId: String, database: DatabaseService) async throws {
        guard !companyId.isEmpty else { return }
        var filter = DatabaseService.FinancialOperationFilter()
        filter.companyId = companyId
        filter.limit = 2000
        let localOps = try database.fetchFinancialOperations(filter: filter)
        for op in localOps {
            guard let type = FinancialOperationEntity.OperationType(rawValue: op.type),
                  let paymentMethod = FinancialOperationEntity.PaymentMethod(rawValue: op.paymentMethod),
                  let account = FinancialOperationEntity.Account(rawValue: op.account) else { continue }
            let entity = FinancialOperationEntity(
                id: op.id,
                type: type,
                amount: op.amount,
                paymentMethod: paymentMethod,
                cashReceived: op.cashReceived,
                changeGiven: op.changeGiven,
                account: account,
                relatedMotorID: op.relatedMotorID,
                createdAt: op.createdAt,
                createdByUser: op.createdByUser,
                comment: op.comment,
                source: op.source,
                details: op.details,
                category: op.category,
                description: op.description
            )
            do {
                _ = try await pushOperation(entity, companyId: companyId, documentId: "local-\(op.id)")
            } catch {
                logger.error("Firestore PUSH local op id=\(op.id) failed", error: error)
            }
        }
        if !localOps.isEmpty {
            logger.info("Firestore PUSH local: uploaded \(localOps.count) operations for companyId=\(companyId)")
        }
    }
    
    private func mapDocumentToEntity(_ doc: DocumentSnapshot) -> FinancialOperationEntity? {
        guard let data = doc.data(),
              let typeRaw = data["type"] as? String,
              let type = FinancialOperationEntity.OperationType(rawValue: typeRaw),
              let paymentMethodRaw = data["paymentMethod"] as? String,
              let paymentMethod = FinancialOperationEntity.PaymentMethod(rawValue: paymentMethodRaw),
              let accountRaw = data["account"] as? String,
              let account = FinancialOperationEntity.Account(rawValue: accountRaw) else {
            return nil
        }
        
        let amount: Decimal
        if let d = data["amount"] as? Double {
            amount = Decimal(d)
        } else if let n = data["amount"] as? NSNumber {
            amount = n.decimalValue
        } else {
            return nil
        }
        
        let createdAt: Date
        if let ts = data["createdAt"] as? Timestamp {
            createdAt = ts.dateValue()
        } else {
            return nil
        }
        
        let createdByUser = data["createdByUserId"] as? String ?? ""
        let comment = data["comment"] as? String ?? ""
        let source = data["source"] as? String ?? ""
        let details = data["details"] as? String ?? ""
        let category = data["category"] as? String
        let description = data["description"] as? String ?? details
        
        let cashReceived: Decimal?
        if let v = data["cashReceived"] as? Double {
            cashReceived = Decimal(v)
        } else if let v = data["cashReceived"] as? NSNumber {
            cashReceived = v.decimalValue
        } else {
            cashReceived = nil
        }
        
        let changeGiven: Decimal?
        if let v = data["changeGiven"] as? Double {
            changeGiven = Decimal(v)
        } else if let v = data["changeGiven"] as? NSNumber {
            changeGiven = v.decimalValue
        } else {
            changeGiven = nil
        }
        
        let relatedMotorID: Int64? = (data["relatedMotorID"] as? NSNumber)?.int64Value
        
        return FinancialOperationEntity(
            id: 0,
            type: type,
            amount: amount,
            paymentMethod: paymentMethod,
            cashReceived: cashReceived,
            changeGiven: changeGiven,
            account: account,
            relatedMotorID: relatedMotorID,
            createdAt: createdAt,
            createdByUser: createdByUser,
            comment: comment,
            source: source,
            details: details,
            category: category,
            description: description
        )
    }
}
