import Foundation
import FirebaseFirestore

final class FirestoreOperationRepository: OperationRepository {
    private let db: Firestore
    private let collection = "operations"

    init(db: Firestore = .firestore()) {
        self.db = db
    }

    func save(_ operation: OperationEntity) async throws -> OperationEntity {
        let documentId = operation.id.isEmpty ? UUID().uuidString : operation.id
        let data: [String: Any] = [
            "companyId": operation.companyId,
            "type": operation.type.rawValue,
            "amount": NSDecimalNumber(decimal: operation.amount).doubleValue,
            "accountId": operation.accountId,
            "category": operation.category as Any,
            "comment": operation.comment,
            "createdAt": Timestamp(date: operation.createdAt),
            "relatedEngineId": operation.relatedEngineId as Any
        ]

        try await db.collection(collection).document(documentId).setData(data, merge: true)

        if operation.id == documentId {
            return operation
        }

        return OperationEntity(
            id: documentId,
            companyId: operation.companyId,
            type: operation.type,
            amount: operation.amount,
            accountId: operation.accountId,
            category: operation.category,
            comment: operation.comment,
            createdAt: operation.createdAt,
            relatedEngineId: operation.relatedEngineId
        )
    }

    func findByID(_ id: String) async throws -> OperationEntity? {
        let doc = try await db.collection(collection).document(id).getDocument()
        return mapDocument(doc)
    }

    func findAll(companyId: String, filter: OperationFilter?) async throws -> [OperationEntity] {
        var query: Query = db.collection(collection).whereField("companyId", isEqualTo: companyId)

        if let type = filter?.type {
            query = query.whereField("type", isEqualTo: type.rawValue)
        }
        if let accountId = filter?.accountId, !accountId.isEmpty {
            query = query.whereField("accountId", isEqualTo: accountId)
        }
        if let fromDate = filter?.fromDate {
            query = query.whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: fromDate))
        }
        if let toDate = filter?.toDate {
            query = query.whereField("createdAt", isLessThanOrEqualTo: Timestamp(date: toDate))
        }
        query = query.order(by: "createdAt", descending: true)

        let snapshot = try await query.getDocuments()
        var entities = snapshot.documents.compactMap(mapDocument)
        if let limit = filter?.limit, limit > 0, entities.count > limit {
            entities = Array(entities.prefix(limit))
        }
        return entities
    }

    private func mapDocument(_ doc: DocumentSnapshot) -> OperationEntity? {
        guard let data = doc.data(),
              let companyId = data["companyId"] as? String,
              let typeRaw = data["type"] as? String,
              let type = OperationEntity.OperationType(rawValue: typeRaw),
              let accountId = data["accountId"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }

        guard let amount = decimal(from: data["amount"]) else {
            return nil
        }

        return OperationEntity(
            id: doc.documentID,
            companyId: companyId,
            type: type,
            amount: amount,
            accountId: accountId,
            category: data["category"] as? String,
            comment: data["comment"] as? String ?? "",
            createdAt: createdAt,
            relatedEngineId: data["relatedEngineId"] as? String
        )
    }

    private func decimal(from value: Any?) -> Decimal? {
        if let decimal = value as? Decimal {
            return decimal
        }
        if let number = value as? NSNumber {
            return number.decimalValue
        }
        if let double = value as? Double {
            return Decimal(double)
        }
        if let string = value as? String {
            return Decimal(string: string)
        }
        return nil
    }
}
