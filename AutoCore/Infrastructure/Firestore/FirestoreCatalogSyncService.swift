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

        let fingerprint = "\(normalizedCompanyId)|b:\(brands.count)|e:\(engines.count)|m:\(motors.count)|mx:\(motors.map(\.updatedAt).max()?.timeIntervalSince1970 ?? 0)"
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
                batch.setData([
                    "companyId": normalizedCompanyId,
                    "localId": motor.id,
                    "engineId": motor.engineID,
                    "serialCode": motor.serialCode,
                    "configuration": motor.configuration,
                    "notes": motor.notes,
                    "quantity": motor.quantity,
                    "transmission": motor.transmission,
                    "arrivalDate": Timestamp(date: motor.arrivalDate),
                    "soldDate": motor.soldDate.map { Timestamp(date: $0) } as Any,
                    "deletedAt": motor.deletedAt.map { Timestamp(date: $0) } as Any,
                    "createdAt": Timestamp(date: motor.createdAt),
                    "updatedAt": Timestamp(date: motor.updatedAt),
                    "brandName": motor.brandName,
                    "engineCode": motor.engineCode
                ], forDocument: ref, merge: true)
            }

            try await batch.commit()
            logger.info("Firestore catalog sync success: brands=\(brands.count), engines=\(engines.count), motors=\(motors.count)")
        } catch {
            logger.error("Firestore catalog sync failed", error: error)
        }
    }
}
