import Foundation
import FirebaseFirestore
import FirebaseAuth

final class FirestoreInventoryMovementRepository: InventoryMovementRepository {
    private let db: Firestore
    private let collection = "inventoryMovements"
    private var cachedResolvedCompanyId: String?

    private enum InventoryMovementRepositoryError: LocalizedError {
        case unauthenticated
        case companyNotConfigured

        var errorDescription: String? {
            switch self {
            case .unauthenticated:
                return "Firebase Auth: пользователь не авторизован."
            case .companyNotConfigured:
                return "Firebase: не задан companyId (ни в token claims, ни в users/{uid}, ни в локальном профиле)."
            }
        }
    }

    init(db: Firestore = .firestore()) {
        self.db = db
    }

    func save(_ movement: InventoryMovementEntity) async throws -> InventoryMovementEntity {
        let resolvedCompanyId = try await resolveCompanyId(preferred: movement.companyId)
        let documentID = movement.id.isEmpty ? UUID().uuidString : movement.id
        let data: [String: Any] = [
            "companyId": resolvedCompanyId,
            "itemId": movement.itemId,
            "type": movement.type.rawValue,
            "quantityDelta": NSDecimalNumber(decimal: movement.quantityDelta).doubleValue,
            "comment": movement.comment,
            "createdAt": Timestamp(date: movement.createdAt)
        ]
        try await db.collection(collection).document(documentID).setData(data, merge: true)

        if movement.id == documentID {
            return movement
        }

        return InventoryMovementEntity(
            id: documentID,
            companyId: resolvedCompanyId,
            itemId: movement.itemId,
            type: movement.type,
            quantityDelta: movement.quantityDelta,
            comment: movement.comment,
            createdAt: movement.createdAt
        )
    }

    func findByID(_ id: String) async throws -> InventoryMovementEntity? {
        let snapshot = try await db.collection(collection).document(id).getDocument()
        return map(snapshot)
    }

    func findAll(companyId: String, filter: InventoryMovementFilter?) async throws -> [InventoryMovementEntity] {
        let resolvedCompanyId = try await resolveCompanyId(preferred: companyId)
        var query: Query = db.collection(collection)
            .whereField("companyId", isEqualTo: resolvedCompanyId)

        if let itemId = filter?.itemId, !itemId.isEmpty {
            query = query.whereField("itemId", isEqualTo: itemId)
        }
        if let fromDate = filter?.fromDate {
            query = query.whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: fromDate))
        }
        if let toDate = filter?.toDate {
            query = query.whereField("createdAt", isLessThanOrEqualTo: Timestamp(date: toDate))
        }

        query = query.order(by: "createdAt", descending: true)
        let snapshot = try await query.getDocuments()
        var movements = snapshot.documents.compactMap(map)
        if let limit = filter?.limit, limit > 0, movements.count > limit {
            movements = Array(movements.prefix(limit))
        }
        return movements
    }

    private func map(_ snapshot: DocumentSnapshot) -> InventoryMovementEntity? {
        guard let data = snapshot.data(),
              let companyId = data["companyId"] as? String,
              let itemId = data["itemId"] as? String,
              let typeRaw = data["type"] as? String,
              let type = InventoryMovementEntity.MovementType(rawValue: typeRaw),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }

        return InventoryMovementEntity(
            id: snapshot.documentID,
            companyId: companyId,
            itemId: itemId,
            type: type,
            quantityDelta: decimal(from: data["quantityDelta"]) ?? 0,
            comment: data["comment"] as? String ?? "",
            createdAt: createdAt
        )
    }

    private func decimal(from value: Any?) -> Decimal? {
        if let decimal = value as? Decimal { return decimal }
        if let number = value as? NSNumber { return number.decimalValue }
        if let double = value as? Double { return Decimal(double) }
        if let string = value as? String { return Decimal(string: string) }
        return nil
    }

    private func resolveCompanyId(preferred: String) async throws -> String {
        if let cachedResolvedCompanyId, !cachedResolvedCompanyId.isEmpty {
            return cachedResolvedCompanyId
        }

        let trimmedPreferred = preferred.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firebaseUser = Auth.auth().currentUser else {
            throw InventoryMovementRepositoryError.unauthenticated
        }
        let uid = firebaseUser.uid
        let userRef = db.collection("users").document(uid)

        let tokenResult = try await firebaseUser.getIDTokenResult(forcingRefresh: true)

        func writeCompanyIdAndWait(_ cid: String) async throws {
            try await userRef.setData(["companyId": cid], merge: true)
            try await Task.sleep(nanoseconds: 400_000_000)
        }

        if let tokenCompanyId = tokenCompanyId(from: tokenResult), !tokenCompanyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try await writeCompanyIdAndWait(tokenCompanyId)
            cachedResolvedCompanyId = tokenCompanyId
            return tokenCompanyId
        }

        let firestoreCompanyId: String
        do {
            let userSnapshot = try await userRef.getDocument(source: .server)
            firestoreCompanyId = (userSnapshot.data()?["companyId"] as? String) ?? ""
        } catch {
            if !trimmedPreferred.isEmpty {
                try await writeCompanyIdAndWait(trimmedPreferred)
                cachedResolvedCompanyId = trimmedPreferred
                return trimmedPreferred
            }
            throw error
        }

        if !firestoreCompanyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try await writeCompanyIdAndWait(firestoreCompanyId)
            cachedResolvedCompanyId = firestoreCompanyId
            return firestoreCompanyId
        }

        if !trimmedPreferred.isEmpty {
            try await writeCompanyIdAndWait(trimmedPreferred)
            cachedResolvedCompanyId = trimmedPreferred
            return trimmedPreferred
        }

        throw InventoryMovementRepositoryError.companyNotConfigured
    }

    private func tokenCompanyId(from token: AuthTokenResult) -> String? {
        if let value = token.claims["companyId"] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
}
