import Foundation
import FirebaseFirestore

final class FirestoreEngineRepository: EngineRepository {
    private let db: Firestore
    private let collection = "engines"

    init(db: Firestore = .firestore()) {
        self.db = db
    }

    func save(_ engine: EngineItemEntity) async throws -> EngineItemEntity {
        let documentId = engine.id.isEmpty ? UUID().uuidString : engine.id
        let data: [String: Any] = [
            "companyId": engine.companyId,
            "engineNumber": engine.engineNumber,
            "model": engine.model,
            "volume": engine.volume,
            "hasGearbox": engine.hasGearbox,
            "buyPrice": NSDecimalNumber(decimal: engine.buyPrice).doubleValue,
            "sellPrice": NSDecimalNumber(decimal: engine.sellPrice).doubleValue,
            "status": engine.status.rawValue,
            "createdAt": Timestamp(date: engine.createdAt),
            "soldAt": engine.soldAt.map { Timestamp(date: $0) } as Any
        ]

        try await db.collection(collection).document(documentId).setData(data, merge: true)

        var saved = engine
        if saved.id != documentId {
            saved = EngineItemEntity(
                id: documentId,
                companyId: engine.companyId,
                engineNumber: engine.engineNumber,
                model: engine.model,
                volume: engine.volume,
                hasGearbox: engine.hasGearbox,
                buyPrice: engine.buyPrice,
                sellPrice: engine.sellPrice,
                status: engine.status,
                createdAt: engine.createdAt,
                soldAt: engine.soldAt
            )
        }
        return saved
    }

    func findByID(_ id: String) async throws -> EngineItemEntity? {
        let doc = try await db.collection(collection).document(id).getDocument()
        return mapDocument(doc)
    }

    func findAll(companyId: String, filter: EngineFilter?) async throws -> [EngineItemEntity] {
        var query: Query = db.collection(collection).whereField("companyId", isEqualTo: companyId)
        if let status = filter?.status {
            query = query.whereField("status", isEqualTo: status.rawValue)
        }

        let snapshot = try await query.getDocuments()
        let mapped = snapshot.documents.compactMap(mapDocument)

        guard let search = filter?.searchText?.trimmingCharacters(in: .whitespacesAndNewlines), !search.isEmpty else {
            return mapped
        }

        return mapped.filter { entity in
            entity.engineNumber.localizedCaseInsensitiveContains(search) ||
                entity.model.localizedCaseInsensitiveContains(search)
        }
    }

    private func mapDocument(_ doc: DocumentSnapshot) -> EngineItemEntity? {
        guard let data = doc.data(),
              let companyId = data["companyId"] as? String,
              let engineNumber = data["engineNumber"] as? String,
              let model = data["model"] as? String,
              let volume = data["volume"] as? String,
              let hasGearbox = data["hasGearbox"] as? Bool,
              let statusRaw = data["status"] as? String,
              let status = EngineItemEntity.EngineStatus(rawValue: statusRaw),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }

        let buyPrice = decimal(from: data["buyPrice"]) ?? 0
        let sellPrice = decimal(from: data["sellPrice"]) ?? 0
        let soldAt = (data["soldAt"] as? Timestamp)?.dateValue()

        return EngineItemEntity(
            id: doc.documentID,
            companyId: companyId,
            engineNumber: engineNumber,
            model: model,
            volume: volume,
            hasGearbox: hasGearbox,
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            status: status,
            createdAt: createdAt,
            soldAt: soldAt
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
