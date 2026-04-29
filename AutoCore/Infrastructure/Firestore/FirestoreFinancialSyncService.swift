//
//  FirestoreFinancialSyncService.swift
//  AutoCore
//
//  Реализация FinancialSyncService через Firestore.
//  Push при сохранении, pull при запуске (macOS). iOS читает напрямую через запросы.
//

import Foundation
import FirebaseFirestore
import Network

final class FirestoreFinancialSyncService: FinancialSyncService {
    private let db = Firestore.firestore()
    private let logger = LoggingService.shared
    private let networkMonitor = NWPathMonitor()
    private var isConnected = true
    
    static let collectionName = "financialOperations"
    
    private func scopedLocalDocumentId(companyId: String, localID: Int64) -> String {
        // Избегаем коллизий docId между компаниями для локальных операций.
        "company_\(companyId)_local_\(localID)"
    }
    
    init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
        }
        networkMonitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    func pushOperation(_ entity: FinancialOperationEntity, companyId: String) async throws -> String {
        try await pushOperation(entity, companyId: companyId, documentId: nil)
    }
    
    func pushOperation(_ entity: FinancialOperationEntity, companyId: String, documentId: String?) async throws -> String {
        guard !companyId.isEmpty else {
            throw NSError(domain: "FinancialSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "companyId is required for push"])
        }
        let docId = documentId ?? UUID().uuidString
        var data: [String: Any] = [
            "companyId": companyId,
            "type": entity.type.rawValue,
            "amount": NSDecimalNumber(decimal: entity.amount).doubleValue,
            "paymentMethod": entity.paymentMethod.rawValue,
            "account": entity.account.rawValue,
            "createdAt": Timestamp(date: entity.createdAt),
            "createdByUserId": entity.createdByUser,
            "comment": entity.comment,
            "source": entity.source,
            "details": entity.details,
            "description": entity.description,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let cashReceived = entity.cashReceived {
            data["cashReceived"] = NSDecimalNumber(decimal: cashReceived).doubleValue
        }
        if let changeGiven = entity.changeGiven {
            data["changeGiven"] = NSDecimalNumber(decimal: changeGiven).doubleValue
        }
        if let relatedMotorID = entity.relatedMotorID {
            data["relatedMotorID"] = relatedMotorID
        }
        if let category = entity.category {
            data["category"] = category
        }
        
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
                    let ns = error as NSError
                    if ns.domain == FirestoreErrorDomain,
                       ns.code == FirestoreErrorCode.resourceExhausted.rawValue {
                        self.logger.info("Firestore observe paused: resource exhausted (quota). Listener stopped until next app launch.")
                        continuation.finish()
                        return
                    }
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
    
    func deleteOperation(documentId: String, companyId: String) async throws {
        guard !companyId.isEmpty else {
            throw NSError(domain: "FinancialSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "companyId is required for delete"])
        }
        guard !documentId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "FinancialSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "documentId is required for delete"])
        }
        try await db.collection(Self.collectionName).document(documentId).delete()
        logger.info("Firestore DELETE success: docId=\(documentId)")
    }

    func deleteOperation(_ entity: FinancialOperationEntity, companyId: String) async throws {
        if let cloudId = entity.cloudDocumentId?.trimmingCharacters(in: .whitespacesAndNewlines), !cloudId.isEmpty {
            try await deleteOperation(documentId: cloudId, companyId: companyId)
            return
        }

        // Legacy fallback: операция без cloudDocumentId (создана до внедрения cloud id в локальной БД).
        // Ищем максимально похожий документ в облаке и удаляем его.
        let remote = try await pullOperations(companyId: companyId, since: nil)
        guard let matched = remote.first(where: { candidate in
            candidate.type == entity.type &&
            candidate.account == entity.account &&
            candidate.amount == entity.amount &&
            candidate.relatedMotorID == entity.relatedMotorID &&
            candidate.createdByUser == entity.createdByUser &&
            candidate.comment == entity.comment &&
            candidate.details == entity.details &&
            abs(candidate.createdAt.timeIntervalSince(entity.createdAt)) < 10
        }), let matchedDocId = matched.cloudDocumentId else {
            throw NSError(
                domain: "FinancialSync",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Cloud operation not found for legacy local delete"]
            )
        }
        try await deleteOperation(documentId: matchedDocId, companyId: companyId)
    }
    
    /// Сливает список операций из Firestore в локальную БД (без дубликатов). Используется при pull и при observe.
    func mergeEntitiesIntoDatabase(_ entities: [FinancialOperationEntity], companyId: String, database: DatabaseService) async throws {
        var localFilter = DatabaseService.FinancialOperationFilter()
        localFilter.companyId = companyId
        localFilter.limit = 5000
        let localOperations = try database.fetchFinancialOperations(filter: localFilter)
        var localByCloudId: [String: DatabaseService.FinancialOperation] = [:]
        for operation in localOperations {
            if let cloudId = operation.cloudDocumentId?.trimmingCharacters(in: .whitespacesAndNewlines), !cloudId.isEmpty {
                localByCloudId[cloudId] = operation
            }
        }

        var remoteCloudIds = Set<String>()
        var insertedCount = 0
        var updatedCount = 0
        for entity in entities {
            do {
                if let cloudId = entity.cloudDocumentId?.trimmingCharacters(in: .whitespacesAndNewlines), !cloudId.isEmpty {
                    remoteCloudIds.insert(cloudId)
                    if let local = localByCloudId[cloudId] {
                        if try updateLocalOperationIfNeeded(local: local, remote: entity, database: database) {
                            updatedCount += 1
                        }
                        try applyMotorSoldStatusIfNeeded(entity: entity, companyId: companyId, database: database)
                        continue
                    }
                }

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
                
                if let existing {
                    if existing.cloudDocumentId == nil, let cloudId = entity.cloudDocumentId {
                        try database.setFinancialOperationCloudDocumentId(id: existing.id, cloudDocumentId: cloudId)
                    }
                    continue
                }
                
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
                    cloudRecordId: entity.cloudDocumentId,
                    companyId: companyId
                )
                try applyMotorSoldStatusIfNeeded(entity: entity, companyId: companyId, database: database)
                insertedCount += 1
            } catch {
                logger.error("Firestore PULL: failed to merge operation type=\(entity.type.rawValue), amount=\(entity.amount)", error: error)
                continue
            }
        }

        let staleOperations = localOperations.filter { operation in
            guard let cloudId = operation.cloudDocumentId?.trimmingCharacters(in: .whitespacesAndNewlines), !cloudId.isEmpty else {
                return false
            }
            return !remoteCloudIds.contains(cloudId)
        }
        var deletedCount = 0
        for operation in staleOperations {
            do {
                try database.deleteFinancialOperation(id: operation.id)
                deletedCount += 1
                if let motorID = operation.relatedMotorID {
                    try reconcileMotorSoldDateFromFinancialHistory(motorID: motorID, companyId: companyId, database: database)
                }
            } catch {
                logger.error("Firestore MERGE: failed to delete stale local operation id=\(operation.id)", error: error)
            }
        }
        
        logger.info("Firestore MERGE into local DB: inserted=\(insertedCount), updated=\(updatedCount), deleted=\(deletedCount)")
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
                let targetDocId = op.cloudDocumentId ?? scopedLocalDocumentId(companyId: companyId, localID: op.id)
                let pushedDocId = try await pushOperation(entity, companyId: companyId, documentId: targetDocId)
                if op.cloudDocumentId == nil {
                    try database.setFinancialOperationCloudDocumentId(id: op.id, cloudDocumentId: pushedDocId)
                }
            } catch {
                logger.error("Firestore PUSH local op id=\(op.id) failed", error: error)
            }
        }
        if !localOps.isEmpty {
            logger.info("Firestore PUSH local: uploaded \(localOps.count) operations for companyId=\(companyId)")
        }
    }
    
    func updateOperation(documentId: String, companyId: String, fields: [String: Any]) async throws {
        guard !companyId.isEmpty else {
            throw NSError(domain: "FinancialSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "companyId is required"])
        }
        guard !documentId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "FinancialSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "documentId is required"])
        }
        var updateData = fields
        updateData["updatedAt"] = FieldValue.serverTimestamp()
        try await db.collection(Self.collectionName).document(documentId).updateData(updateData)
        logger.info("Firestore UPDATE success: docId=\(documentId)")
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
            cloudDocumentId: doc.documentID,
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

    private func updateLocalOperationIfNeeded(
        local: DatabaseService.FinancialOperation,
        remote: FinancialOperationEntity,
        database: DatabaseService
    ) throws -> Bool {
        let needsUpdate =
            local.amount != remote.amount ||
            local.account != remote.account.rawValue ||
            (local.category ?? "") != (remote.category ?? "") ||
            local.description != remote.description ||
            local.comment != remote.comment

        guard needsUpdate else { return false }

        try database.updateFinancialOperation(
            id: local.id,
            amount: remote.amount,
            account: remote.account.rawValue,
            category: remote.category,
            description: remote.description,
            comment: remote.comment
        )
        return true
    }

    private func reconcileMotorSoldDateFromFinancialHistory(
        motorID: Int64,
        companyId: String,
        database: DatabaseService
    ) throws {
        var filter = DatabaseService.FinancialOperationFilter()
        filter.companyId = companyId
        filter.relatedMotorID = motorID
        filter.limit = 500
        let ops = try database.fetchFinancialOperations(filter: filter)
        let relevant = ops
            .filter { $0.type == FinancialOperationEntity.OperationType.sale.rawValue || $0.type == FinancialOperationEntity.OperationType.refund.rawValue }
            .sorted { $0.createdAt < $1.createdAt }

        guard let latest = relevant.last else {
            try database.updateSoldDate(id: motorID, soldDate: nil)
            return
        }
        if latest.type == FinancialOperationEntity.OperationType.sale.rawValue {
            try database.updateSoldDate(id: motorID, soldDate: latest.createdAt)
        } else {
            try database.updateSoldDate(id: motorID, soldDate: nil)
        }
    }

    private func applyMotorSoldStatusIfNeeded(
        entity: FinancialOperationEntity,
        companyId: String,
        database: DatabaseService
    ) throws {
        guard let motorID = entity.relatedMotorID else { return }
        // В кросс-устройственном сценарии relatedMotorID может быть локальным id другого устройства.
        // Применяем sold-status по ID только для "локальных" операций продажи мотора macOS.
        let isLocalMotorSaleSource = entity.source.localizedCaseInsensitiveContains("Продажа мотора")
            || entity.source.localizedCaseInsensitiveContains("Возврат мотора")
        guard isLocalMotorSaleSource else { return }
        switch entity.type {
        case .sale:
            try database.updateSoldDate(id: motorID, soldDate: entity.createdAt)
            NotificationCenter.default.post(
                name: .remoteMotorSoldStatusChanged,
                object: nil,
                userInfo: [
                    RemoteMotorSyncUserInfoKey.motorID: motorID,
                    RemoteMotorSyncUserInfoKey.soldDate: entity.createdAt,
                    RemoteMotorSyncUserInfoKey.companyId: companyId,
                    RemoteMotorSyncUserInfoKey.operationDocumentId: entity.cloudDocumentId ?? "",
                    RemoteMotorSyncUserInfoKey.operationType: entity.type.rawValue,
                    RemoteMotorSyncUserInfoKey.createdByUser: entity.createdByUser
                ]
            )
        case .refund:
            try database.updateSoldDate(id: motorID, soldDate: nil)
            NotificationCenter.default.post(
                name: .remoteMotorSoldStatusChanged,
                object: nil,
                userInfo: [
                    RemoteMotorSyncUserInfoKey.motorID: motorID,
                    RemoteMotorSyncUserInfoKey.companyId: companyId,
                    RemoteMotorSyncUserInfoKey.operationDocumentId: entity.cloudDocumentId ?? "",
                    RemoteMotorSyncUserInfoKey.operationType: entity.type.rawValue,
                    RemoteMotorSyncUserInfoKey.createdByUser: entity.createdByUser
                ]
            )
        default:
            break
        }
    }
}
