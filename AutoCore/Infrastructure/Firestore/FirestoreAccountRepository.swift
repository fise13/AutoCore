import Foundation
import FirebaseFirestore

final class FirestoreAccountRepository: AccountRepository {
    private let db: Firestore
    private let collection = "accounts"

    init(db: Firestore = .firestore()) {
        self.db = db
    }

    func save(_ account: AccountEntity) async throws -> AccountEntity {
        let documentId = account.id.isEmpty ? UUID().uuidString : account.id
        let data: [String: Any] = [
            "companyId": account.companyId,
            "name": account.name,
            "type": account.type.rawValue,
            "balance": NSDecimalNumber(decimal: account.balance).doubleValue
        ]

        try await db.collection(collection).document(documentId).setData(data, merge: true)

        if account.id == documentId {
            return account
        }

        return AccountEntity(
            id: documentId,
            companyId: account.companyId,
            name: account.name,
            type: account.type,
            balance: account.balance
        )
    }

    func findByID(_ id: String) async throws -> AccountEntity? {
        let doc = try await db.collection(collection).document(id).getDocument()
        return mapDocument(doc)
    }

    func findAll(companyId: String) async throws -> [AccountEntity] {
        let snapshot = try await db.collection(collection)
            .whereField("companyId", isEqualTo: companyId)
            .getDocuments()
        return snapshot.documents.compactMap(mapDocument)
    }

    func updateBalance(accountId: String, delta: Decimal) async throws {
        let ref = db.collection(collection).document(accountId)
        try await db.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(ref)
                guard var data = snapshot.data() else {
                    throw DomainError.notFound(message: "Счет \(accountId) не найден")
                }
                let current = self.decimal(from: data["balance"]) ?? 0
                let next = current + delta
                data["balance"] = NSDecimalNumber(decimal: next).doubleValue
                transaction.setData(data, forDocument: ref, merge: true)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    private func mapDocument(_ doc: DocumentSnapshot) -> AccountEntity? {
        guard let data = doc.data(),
              let companyId = data["companyId"] as? String,
              let name = data["name"] as? String,
              let typeRaw = data["type"] as? String,
              let type = AccountEntity.AccountType(rawValue: typeRaw),
              let balance = decimal(from: data["balance"]) else {
            return nil
        }

        return AccountEntity(
            id: doc.documentID,
            companyId: companyId,
            name: name,
            type: type,
            balance: balance
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
