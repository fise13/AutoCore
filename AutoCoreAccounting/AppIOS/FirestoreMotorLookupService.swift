import Foundation
import FirebaseFirestore

#if os(iOS)

struct FirestoreMotorLookupResult: Identifiable, Equatable {
    let id: String // cloud document id
    let localId: Int64?
    let serialCode: String
    let engineCode: String
    let brandName: String
    let isSold: Bool
}

final class FirestoreMotorLookupService {
    private let db = Firestore.firestore()
    
    private struct ScoredMotor {
        let result: FirestoreMotorLookupResult
        let score: Int
    }

    func searchMotors(companyId: String, query: String, limit: Int = 12) async throws -> [FirestoreMotorLookupResult] {
        let trimmedCompanyId = companyId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCompanyId.isEmpty, !trimmedQuery.isEmpty else { return [] }

        // Firestore не поддерживает надежный contains без индексов/токенов.
        // Берем актуальные документы компании и фильтруем локально по вхождению.
        let snapshot = try await db.collection("motors")
            .whereField("companyId", isEqualTo: trimmedCompanyId)
            .order(by: "updatedAt", descending: true)
            .limit(to: 200)
            .getDocuments()

        let queryLower = trimmedQuery.lowercased()
        let all: [ScoredMotor] = snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let serialCode = data["serialCode"] as? String else { return nil }
            let localId = (data["localId"] as? NSNumber)?.int64Value ?? data["localId"] as? Int64
            let engineCode = data["engineCode"] as? String ?? ""
            let brandName = data["brandName"] as? String ?? ""
            let isSold = (data["soldDate"] as? Timestamp) != nil
            return ScoredMotor(result: FirestoreMotorLookupResult(
                id: doc.documentID,
                localId: localId,
                serialCode: serialCode,
                engineCode: engineCode,
                brandName: brandName,
                isSold: isSold
            ), score: score(query: queryLower, serial: serialCode, engine: engineCode, brand: brandName))
        }
        .filter { $0.score > 0 }
        .sorted { lhs, rhs in
            if lhs.result.isSold != rhs.result.isSold {
                return lhs.result.isSold == false
            }
            return lhs.score > rhs.score
        }

        return Array(all.prefix(limit).map(\.result))
    }

    private func score(query: String, serial: String, engine: String, brand: String) -> Int {
        let serialLower = serial.lowercased()
        let engineLower = engine.lowercased()
        let brandLower = brand.lowercased()
        if serialLower == query { return 120 }
        if serialLower.hasPrefix(query) { return 100 }
        if serialLower.contains(query) { return 80 }
        if engineLower.hasPrefix(query) { return 60 }
        if engineLower.contains(query) { return 40 }
        if brandLower.contains(query) { return 20 }
        return 0
    }
}

#endif
