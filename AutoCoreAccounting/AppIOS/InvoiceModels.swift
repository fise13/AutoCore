//
//  InvoiceModels.swift
//  AutoCore
//
//  Модели для сканирования накладных (OCR).
//

import Foundation

#if os(iOS)

/// Строка накладной: название, количество, цена.
struct InvoiceItem: Identifiable, Equatable {
    var id: String { "\(name)-\(quantity)-\(price)" }
    var name: String
    var quantity: Decimal
    var price: Decimal
    
    var total: Decimal { quantity * price }
}

/// Результат сканирования накладной.
struct ScannedInvoice: Identifiable {
    let id: String
    var scannedAt: Date
    var items: [InvoiceItem]
    var rawText: String?
    
    var totalAmount: Decimal {
        items.reduce(0) { $0 + $1.total }
    }
    
    init(id: String = UUID().uuidString, scannedAt: Date = Date(), items: [InvoiceItem], rawText: String? = nil) {
        self.id = id
        self.scannedAt = scannedAt
        self.items = items
        self.rawText = rawText
    }
}

#endif
