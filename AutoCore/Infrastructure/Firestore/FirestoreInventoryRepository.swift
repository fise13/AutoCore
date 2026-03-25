import Foundation
import FirebaseFirestore
import FirebaseAuth

final class FirestoreInventoryRepository: InventoryRepository {
    private let db: Firestore
    private let collection = "inventoryItems"
    private var cachedResolvedCompanyId: String?

    private enum InventoryRepositoryError: LocalizedError {
        case unauthenticated
        case companyNotConfigured
        case permissionDenied(stage: String, domain: String, code: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .unauthenticated:
                return "Firebase Auth: пользователь не авторизован."
            case .companyNotConfigured:
                return "Firebase: не задан companyId (ни в token claims, ни в users/{uid}, ни в локальном профиле)."
            case .permissionDenied(let stage, let domain, let code, let message):
                return "Firebase permission denied [\(stage)] domain=\(domain) code=\(code): \(message)"
            }
        }
    }

    init(db: Firestore = .firestore()) {
        self.db = db
    }

    func save(_ item: InventoryItemEntity) async throws -> InventoryItemEntity {
        let resolvedCompanyId = try await resolveCompanyId(preferred: item.companyId)
        let documentID = item.id.isEmpty ? UUID().uuidString : item.id
        let data: [String: Any] = [
            "companyId": resolvedCompanyId,
            "name": item.name,
            "partNumber": item.partNumber,
            "category": item.category,
            "quantity": NSDecimalNumber(decimal: item.quantity).doubleValue,
            "buyPrice": NSDecimalNumber(decimal: item.buyPrice).doubleValue,
            "sellPrice": NSDecimalNumber(decimal: item.sellPrice).doubleValue,
            "createdAt": Timestamp(date: item.createdAt),
            "updatedAt": Timestamp(date: item.updatedAt)
        ]
        try await db.collection(collection).document(documentID).setData(data, merge: true)

        if item.id == documentID {
            return item
        }

        return InventoryItemEntity(
            id: documentID,
            companyId: resolvedCompanyId,
            name: item.name,
            partNumber: item.partNumber,
            category: item.category,
            quantity: item.quantity,
            buyPrice: item.buyPrice,
            sellPrice: item.sellPrice,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt
        )
    }

    func findByID(_ id: String) async throws -> InventoryItemEntity? {
        let snapshot = try await db.collection(collection).document(id).getDocument()
        return map(snapshot)
    }

    func findAll(companyId: String, filter: InventoryFilter?) async throws -> [InventoryItemEntity] {
        let resolvedCompanyId = try await resolveCompanyId(preferred: companyId)
        let uid = Auth.auth().currentUser?.uid ?? "nil"
        print("[Warehouse] findAll: uid=\(uid), preferredCompanyId=\(companyId), resolvedCompanyId=\(resolvedCompanyId)")

        let query = db.collection(collection)
            .whereField("companyId", isEqualTo: resolvedCompanyId)

        let snapshot: QuerySnapshot
        do {
            // Основной путь: c orderBy (требует индекс, если есть сложные правила/запросы)
            snapshot = try await query
                .order(by: "updatedAt", descending: true)
                .getDocuments()
        } catch {
            // Резервный путь: без orderBy, затем сортировка на клиенте.
            // Если это пройдет, проблема была в запросе/индексе, а не в доступе.
            do {
                snapshot = try await query.getDocuments()
            } catch {
                throw mapPermissionError(error, stage: "inventoryItems.findAll.query")
            }
        }
        var items = snapshot.documents.compactMap(map)
        items.sort { $0.updatedAt > $1.updatedAt }

        if let category = filter?.category?.trimmingCharacters(in: .whitespacesAndNewlines), !category.isEmpty {
            items = items.filter { $0.category.caseInsensitiveCompare(category) == .orderedSame }
        }

        if let searchText = filter?.searchText?.trimmingCharacters(in: .whitespacesAndNewlines), !searchText.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.partNumber.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        return items
    }

    func delete(_ id: String) async throws {
        try await db.collection(collection).document(id).delete()
    }

    private func map(_ snapshot: DocumentSnapshot) -> InventoryItemEntity? {
        guard let data = snapshot.data(),
              let companyId = data["companyId"] as? String,
              let name = data["name"] as? String,
              let partNumber = data["partNumber"] as? String,
              let category = data["category"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
            return nil
        }

        return InventoryItemEntity(
            id: snapshot.documentID,
            companyId: companyId,
            name: name,
            partNumber: partNumber,
            category: category,
            quantity: decimal(from: data["quantity"]) ?? 0,
            buyPrice: decimal(from: data["buyPrice"]) ?? 0,
            sellPrice: decimal(from: data["sellPrice"]) ?? 0,
            createdAt: createdAt,
            updatedAt: updatedAt
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
            throw InventoryRepositoryError.unauthenticated
        }
        let uid = firebaseUser.uid
        let userRef = db.collection("users").document(uid)

        // Принудительно обновляем токен, чтобы Firestore rules видели актуальные claims/request.auth.
        let tokenResult = try await firebaseUser.getIDTokenResult(forcingRefresh: true)

        // Вспомогательная запись и ожидание, чтобы rules успели увидеть users/{uid}.companyId.
        func writeCompanyIdAndWait(_ cid: String) async throws {
            try await userRef.setData(["companyId": cid], merge: true)
            try await Task.sleep(nanoseconds: 400_000_000) // 0.4 c
        }

        // 1) Приоритет: companyId из custom claims токена.
        if let tokenCompanyId = tokenCompanyId(from: tokenResult), !tokenCompanyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try await writeCompanyIdAndWait(tokenCompanyId)
            cachedResolvedCompanyId = tokenCompanyId
            return tokenCompanyId
        }

        let firestoreCompanyId: String
        do {
            // Читаем с сервера, чтобы не взять из кэша старую версию без companyId (после онбординга).
            let userSnapshot = try await userRef.getDocument(source: .server)
            firestoreCompanyId = (userSnapshot.data()?["companyId"] as? String) ?? ""
        } catch {
            if !trimmedPreferred.isEmpty {
                do {
                    try await writeCompanyIdAndWait(trimmedPreferred)
                } catch let writeErr {
                    throw mapPermissionError(writeErr, stage: "users/{uid}.setData(sync companyId)")
                }
                cachedResolvedCompanyId = trimmedPreferred
                return trimmedPreferred
            }
            throw mapPermissionError(error, stage: "users/{uid}.getDocument")
        }

        if !firestoreCompanyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("[Warehouse] resolveCompanyId: from users/\(uid) doc, companyId=\(firestoreCompanyId)")
            try await writeCompanyIdAndWait(firestoreCompanyId)
            cachedResolvedCompanyId = firestoreCompanyId
            return firestoreCompanyId
        }

        if !trimmedPreferred.isEmpty {
            print("[Warehouse] resolveCompanyId: using preferred (from app), companyId=\(trimmedPreferred)")
            try await writeCompanyIdAndWait(trimmedPreferred)
            cachedResolvedCompanyId = trimmedPreferred
            return trimmedPreferred
        }

        print("[Warehouse] resolveCompanyId: FAIL companyNotConfigured (token=empty, doc=empty, preferred=empty)")
        throw InventoryRepositoryError.companyNotConfigured
    }

    private func tokenCompanyId(from token: AuthTokenResult) -> String? {
        if let value = token.claims["companyId"] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private func mapPermissionError(_ error: Error, stage: String) -> Error {
        let ns = error as NSError
        if ns.domain == FirestoreErrorDomain, ns.code == FirestoreErrorCode.permissionDenied.rawValue {
            return InventoryRepositoryError.permissionDenied(
                stage: stage,
                domain: ns.domain,
                code: ns.code,
                message: ns.localizedDescription
            )
        }
        return error
    }
}
