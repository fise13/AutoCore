//
//  InvoiceScanConfirmService.swift
//  AutoCore
//
//  После подтверждения накладной: создаёт Operation (расход), InventoryMovement по строкам, Document в Firestore.
//

import Foundation
import FirebaseFirestore

#if os(iOS)

final class InvoiceScanConfirmService {
    private let financialSync: FinancialSyncService
    private let inventoryRepository: InventoryRepository
    private let movementRepository: InventoryMovementRepository
    private let db = Firestore.firestore()
    
    init(
        financialSync: FinancialSyncService,
        inventoryRepository: InventoryRepository,
        movementRepository: InventoryMovementRepository
    ) {
        self.financialSync = financialSync
        self.inventoryRepository = inventoryRepository
        self.movementRepository = movementRepository
    }
    
    /// Создаёт расход (Operation), движения по складу и документ.
    func confirmInvoice(
        companyId: String,
        currentUserEmail: String,
        invoice: ScannedInvoice
    ) async throws {
        guard !companyId.isEmpty else { throw NSError(domain: "InvoiceScan", code: -1, userInfo: [NSLocalizedDescriptionKey: "companyId обязателен"]) }
        let total = invoice.totalAmount
        if total <= 0 { return }
        
        let baseType: FinancialOperationEntity.OperationType = invoice.type == .income ? .income : .expense
        let opSource = invoice.documentKind == .workOrder ? "Заказ-наряд (AI скан)" : "Накладная (AI скан)"
        let opCategory = invoice.documentKind == .workOrder ? "Заказ-наряд" : "Накладная"
        let opDescription = {
            if let counterparty = invoice.counterparty, !counterparty.isEmpty {
                return "\(opCategory) • \(counterparty)"
            }
            return "\(opCategory) от \(formatDate(invoice.scannedAt))"
        }()

        // При продажной накладной пытаемся сопоставить моторы по введённым серийникам
        var matchedMotorIDs: [Int64] = []
        if invoice.type == .income {
            matchedMotorIDs = try await markMatchedMotorsAsSold(companyId: companyId, invoice: invoice)
        }
        let opType: FinancialOperationEntity.OperationType = (invoice.type == .income && !matchedMotorIDs.isEmpty) ? .sale : baseType

        // 1. Финансовая операция (приход/расход по результату AI)
        let expense = FinancialOperationEntity(
            id: 0,
            type: opType,
            amount: total,
            paymentMethod: .transfer,
            cashReceived: nil,
            changeGiven: nil,
            account: .cashbox,
            relatedMotorID: matchedMotorIDs.count == 1 ? matchedMotorIDs[0] : nil,
            createdAt: invoice.scannedAt,
            createdByUser: currentUserEmail,
            comment: "Документ (AI скан)",
            source: opSource,
            details: buildOperationDetails(invoice: invoice, matchedMotorIDs: matchedMotorIDs),
            category: opCategory,
            description: opDescription
        )
        try expense.validate()
        _ = try await financialSync.pushOperation(expense, companyId: companyId)
        
        // 2. Для накладной обновляем склад; для заказ-наряда склад не пополняем автоматически.
        if invoice.documentKind == .invoice {
            for item in invoice.items where item.quantity > 0 && item.price >= 0 {
                var filter = InventoryFilter(searchText: nil, category: nil)
                filter.searchText = item.name
                let existing = try await inventoryRepository.findAll(companyId: companyId, filter: filter)
                let exact = existing.first { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == item.name.trimmingCharacters(in: .whitespaces).lowercased() }
                
                if let found = exact {
                    let movement = InventoryMovementEntity(
                        id: UUID().uuidString,
                        companyId: companyId,
                        itemId: found.id,
                        type: .income,
                        quantityDelta: item.quantity,
                        comment: "Накладная (скан)",
                        createdAt: invoice.scannedAt
                    )
                    try movement.validate()
                    _ = try await movementRepository.save(movement)
                    var updated = found
                    try updated.applyMovement(type: .income, quantityDelta: item.quantity)
                    _ = try await inventoryRepository.save(updated)
                } else {
                    let newItem = InventoryItemEntity(
                        id: UUID().uuidString,
                        companyId: companyId,
                        name: item.name,
                        partNumber: "н/д",
                        category: "Накладная",
                        quantity: item.quantity,
                        buyPrice: item.price,
                        sellPrice: item.price,
                        createdAt: invoice.scannedAt,
                        updatedAt: invoice.scannedAt
                    )
                    try newItem.validate()
                    let movement = InventoryMovementEntity(
                        id: UUID().uuidString,
                        companyId: companyId,
                        itemId: newItem.id,
                        type: .income,
                        quantityDelta: item.quantity,
                        comment: "Накладная (скан)",
                        createdAt: invoice.scannedAt
                    )
                    try movement.validate()
                    _ = try await inventoryRepository.save(newItem)
                    _ = try await movementRepository.save(movement)
                }
            }
        }
        
        // 3. Документ в Firestore
        let docId = UUID().uuidString
        let docData: [String: Any] = [
            "companyId": companyId,
            "scannedAt": Timestamp(date: invoice.scannedAt),
            "documentType": invoice.type.rawValue,
            "documentKind": invoice.documentKind.rawValue,
            "counterparty": invoice.counterparty as Any,
            "matchedMotorIDs": matchedMotorIDs,
            "totalAmount": NSDecimalNumber(decimal: total).doubleValue,
            "itemsCount": invoice.items.count,
            "rawText": invoice.rawText as Any,
            "source": "invoice_scan_ai",
            "createdByUserId": currentUserEmail
        ]
        try await db.collection("documents").document(docId).setData(docData)
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: date)
    }

    private func buildOperationDetails(invoice: ScannedInvoice, matchedMotorIDs: [Int64]) -> String {
        if matchedMotorIDs.isEmpty {
            return "\(invoice.items.count) позиций"
        }
        return "\(invoice.items.count) позиций, моторов отмечено как проданные: \(matchedMotorIDs.count)"
    }

    private func markMatchedMotorsAsSold(companyId: String, invoice: ScannedInvoice) async throws -> [Int64] {
        var matchedIDs = Set<Int64>()
        var processedCloudDocumentIDs = Set<String>()
        var fallbackSerials = Set<String>()
        var alreadySoldSerials = Set<String>()
        let batch = db.batch()

        // 1) Приоритет явного выбора мотора из UI (selectedMotorCloudId/localId).
        for item in invoice.items {
            if let selectedCloudId = item.selectedMotorCloudId?.trimmingCharacters(in: .whitespacesAndNewlines),
               !selectedCloudId.isEmpty {
                let ref = db.collection("motors").document(selectedCloudId)
                let snapshot = try await ref.getDocument()
                guard snapshot.exists, let data = snapshot.data() else { continue }
                guard (data["companyId"] as? String) == companyId else { continue }
                if (data["soldDate"] as? Timestamp) != nil {
                    let serialFromDoc = (data["serialCode"] as? String) ?? item.selectedMotorSerial ?? item.motorSerial ?? "неизвестно"
                    alreadySoldSerials.insert(serialFromDoc)
                    continue
                }

                if let localId = item.selectedMotorLocalId ?? localMotorID(from: data) {
                    matchedIDs.insert(localId)
                }
                batch.updateData([
                    "soldDate": Timestamp(date: invoice.scannedAt),
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: ref)
                processedCloudDocumentIDs.insert(selectedCloudId)
                continue
            }

            let fallbackSerial = item.motorSerial?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !fallbackSerial.isEmpty {
                fallbackSerials.insert(fallbackSerial)
            }
        }

        // 2) Фолбэк для старых сценариев: сопоставление по введённому serial.
        for serial in fallbackSerials {
            let query = db.collection("motors")
                .whereField("companyId", isEqualTo: companyId)
                .whereField("serialCode", isEqualTo: serial)
                .limit(to: 1)
            let snapshot = try await query.getDocuments()
            guard let doc = snapshot.documents.first else { continue }
            guard !processedCloudDocumentIDs.contains(doc.documentID) else { continue }
            if (doc.data()["soldDate"] as? Timestamp) != nil {
                alreadySoldSerials.insert(serial)
                continue
            }
            if let localId = localMotorID(from: doc.data()) {
                matchedIDs.insert(localId)
            }
            batch.updateData([
                "soldDate": Timestamp(date: invoice.scannedAt),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: doc.reference)
            processedCloudDocumentIDs.insert(doc.documentID)
        }

        if !alreadySoldSerials.isEmpty {
            let list = alreadySoldSerials.sorted().joined(separator: ", ")
            throw NSError(
                domain: "InvoiceScanConfirm",
                code: -11,
                userInfo: [NSLocalizedDescriptionKey: "Нельзя продать уже проданный мотор: \(list). Выберите доступный мотор."]
            )
        }

        if !processedCloudDocumentIDs.isEmpty {
            try await batch.commit()
        }
        return matchedIDs.sorted()
    }

    private func localMotorID(from data: [String: Any]) -> Int64? {
        if let localIdNumber = data["localId"] as? NSNumber {
            return localIdNumber.int64Value
        }
        if let localIdInt64 = data["localId"] as? Int64 {
            return localIdInt64
        }
        if let localIdInt = data["localId"] as? Int {
            return Int64(localIdInt)
        }
        return nil
    }
}

#endif
