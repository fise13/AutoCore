import Foundation
import FirebaseFirestore

/// Mirrors local catalog (brands/engines/motors) to Firestore.
/// This keeps current SQLite-first flow but ensures data is available in Firebase.
final class FirestoreCatalogSyncService {
    private let db = Firestore.firestore()
    private let logger = LoggingService.shared

    private var lastFingerprint: String?

    func pushSnapshot(
        companyId: String,
        brands: [Brand],
        engines: [Engine],
        motors: [Motor]
    ) async {
        let normalizedCompanyId = companyId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCompanyId.isEmpty, normalizedCompanyId != "default" else { return }

        let brandSignature = brands
            .sorted { $0.id < $1.id }
            .map { "\($0.id):\($0.name)" }
            .joined(separator: "|")
        let engineSignature = engines
            .sorted { $0.id < $1.id }
            .map { "\($0.id):\($0.brandID):\($0.code)" }
            .joined(separator: "|")
        let motorSignature = motors
            .sorted { $0.id < $1.id }
            .map {
                "\($0.id):\($0.updatedAt.timeIntervalSince1970):\($0.soldDate?.timeIntervalSince1970 ?? 0):\($0.deletedAt?.timeIntervalSince1970 ?? 0)"
            }
            .joined(separator: "|")
        let fingerprint = "\(normalizedCompanyId)|b:\(brandSignature)|e:\(engineSignature)|m:\(motorSignature)"
        if lastFingerprint == fingerprint {
            return
        }
        lastFingerprint = fingerprint

        do {
            let batch = db.batch()

            for brand in brands {
                let ref = db.collection("brands").document("\(normalizedCompanyId)_brand_\(brand.id)")
                batch.setData([
                    "companyId": normalizedCompanyId,
                    "localId": brand.id,
                    "name": brand.name,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: ref, merge: true)
            }

            for engine in engines {
                let ref = db.collection("engines").document("\(normalizedCompanyId)_engine_\(engine.id)")
                batch.setData([
                    "companyId": normalizedCompanyId,
                    "localId": engine.id,
                    "brandId": engine.brandID,
                    "code": engine.code,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: ref, merge: true)
            }

            for motor in motors {
                let ref = db.collection("motors").document("\(normalizedCompanyId)_motor_\(motor.id)")
                var motorData: [String: Any] = [
                    "companyId": normalizedCompanyId,
                    "localId": motor.id,
                    "engineId": motor.engineID,
                    "serialCode": motor.serialCode,
                    "configuration": motor.configuration,
                    "notes": motor.notes,
                    "quantity": motor.quantity,
                    "transmission": motor.transmission,
                    "arrivalDate": Timestamp(date: motor.arrivalDate),
                    "createdAt": Timestamp(date: motor.createdAt),
                    "updatedAt": Timestamp(date: motor.updatedAt),
                    "brandName": motor.brandName,
                    "engineCode": motor.engineCode
                ]
                // Важно: для "не продан" удаляем поле soldDate, а не пишем null/Optional.
                if let soldDate = motor.soldDate {
                    motorData["soldDate"] = Timestamp(date: soldDate)
                } else {
                    motorData["soldDate"] = FieldValue.delete()
                }
                if let deletedAt = motor.deletedAt {
                    motorData["deletedAt"] = Timestamp(date: deletedAt)
                } else {
                    motorData["deletedAt"] = FieldValue.delete()
                }
                batch.setData(motorData, forDocument: ref, merge: true)
            }

            try await batch.commit()
            try await pruneRemovedDocuments(
                companyId: normalizedCompanyId,
                brands: brands,
                engines: engines,
                motors: motors
            )
            logger.info("Firestore catalog sync success: brands=\(brands.count), engines=\(engines.count), motors=\(motors.count)")
        } catch {
            logger.error("Firestore catalog sync failed", error: error)
        }
    }

    func syncMotorSoldStatusesToLocal(companyId: String, database: DatabaseService) async {
        let normalizedCompanyId = companyId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCompanyId.isEmpty, normalizedCompanyId != "default" else { return }
        do {
            let snapshot = try await db.collection("motors")
                .whereField("companyId", isEqualTo: normalizedCompanyId)
                .getDocuments()

            for doc in snapshot.documents {
                let data = doc.data()
                guard let serialCode = data["serialCode"] as? String,
                      !serialCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                let soldDate = (data["soldDate"] as? Timestamp)?.dateValue()
                try? database.setSoldDateForSerialCode(serialCode: serialCode, soldDate: soldDate)
            }
            logger.info("Firestore motor sold-status sync success: companyId=\(normalizedCompanyId), docs=\(snapshot.documents.count)")
        } catch {
            logger.error("Firestore motor sold-status sync failed", error: error)
        }
    }

    private func pruneRemovedDocuments(
        companyId: String,
        brands: [Brand],
        engines: [Engine],
        motors: [Motor]
    ) async throws {
        let currentBrandIds = Set(brands.map(\.id))
        let currentEngineIds = Set(engines.map(\.id))
        let currentMotorIds = Set(motors.map(\.id))

        try await deleteMissingDocuments(collection: "brands", companyId: companyId, keptLocalIds: currentBrandIds)
        try await deleteMissingDocuments(collection: "engines", companyId: companyId, keptLocalIds: currentEngineIds)
        try await deleteMissingDocuments(collection: "motors", companyId: companyId, keptLocalIds: currentMotorIds)
    }

    private func deleteMissingDocuments(
        collection: String,
        companyId: String,
        keptLocalIds: Set<Int64>
    ) async throws {
        let snapshot = try await db.collection(collection)
            .whereField("companyId", isEqualTo: companyId)
            .getDocuments()

        let batch = db.batch()
        var deleteCount = 0
        for doc in snapshot.documents {
            let data = doc.data()
            let localId = (data["localId"] as? NSNumber)?.int64Value ?? data["localId"] as? Int64
            guard let localId else { continue }
            if !keptLocalIds.contains(localId) {
                batch.deleteDocument(doc.reference)
                deleteCount += 1
            }
        }

        if deleteCount > 0 {
            try await batch.commit()
            logger.info("Firestore catalog prune: collection=\(collection), deleted=\(deleteCount), companyId=\(companyId)")
        }
    }
}
