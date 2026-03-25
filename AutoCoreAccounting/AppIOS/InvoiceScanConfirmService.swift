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
        
        // 1. Финансовая операция (расход на сумму накладной)
        let expense = FinancialOperationEntity(
            id: 0,
            type: .expense,
            amount: total,
            paymentMethod: .transfer,
            cashReceived: nil,
            changeGiven: nil,
            account: .cashbox,
            relatedMotorID: nil,
            createdAt: invoice.scannedAt,
            createdByUser: currentUserEmail,
            comment: "Накладная (скан)",
            source: "Скан накладной",
            details: "\(invoice.items.count) позиций",
            category: "Накладная",
            description: "Накладная от \(formatDate(invoice.scannedAt))"
        )
        try expense.validate()
        _ = try await financialSync.pushOperation(expense, companyId: companyId)
        
        // 2. Движения по складу: для каждой строки ищем или создаём товар и добавляем приход
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
        
        // 3. Документ в Firestore
        let docId = UUID().uuidString
        let docData: [String: Any] = [
            "companyId": companyId,
            "scannedAt": Timestamp(date: invoice.scannedAt),
            "totalAmount": NSDecimalNumber(decimal: total).doubleValue,
            "itemsCount": invoice.items.count,
            "rawText": invoice.rawText as Any,
            "source": "invoice_scan",
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
}

#endif
