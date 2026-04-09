import Foundation

#if os(iOS)

struct AITransactionResponse: Decodable {
    let type: String
    let date: String
    let counterparty: String?
    let items: [AIItem]
    let total: Double
    let confidence: Double?
}

struct AIItem: Decodable {
    let name: String
    let quantity: Double?
    let price: Double?
    let total: Double?
}

enum TransactionType: String {
    case income
    case expense
}

struct ExtractedTransactionItem {
    let name: String
    let quantity: Double?
    let price: Double?
    let total: Double?
}

struct Transaction {
    let id: UUID
    let type: TransactionType
    let date: Date
    let counterparty: String?
    let items: [ExtractedTransactionItem]
    let total: Double
}

enum AITransactionMapper {
    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func mapToTransaction(_ response: AITransactionResponse) -> Transaction {
        let type = response.type.lowercased() == "income" ? TransactionType.income : .expense
        let date = isoDateFormatter.date(from: response.date) ?? Date()
        let items = response.items.map {
            ExtractedTransactionItem(name: $0.name, quantity: $0.quantity, price: $0.price, total: $0.total)
        }
        return Transaction(
            id: UUID(),
            type: type,
            date: date,
            counterparty: response.counterparty,
            items: items,
            total: response.total
        )
    }

    static func mapToScannedInvoice(
        _ transaction: Transaction,
        rawText: String?,
        confidence: Double?
    ) -> ScannedInvoice {
        let mappedItems = transaction.items.map { item in
            let qty = Decimal(item.quantity ?? 1)
            let price: Decimal
            if let p = item.price {
                price = Decimal(p)
            } else if let t = item.total, (item.quantity ?? 0) > 0 {
                price = Decimal(t / (item.quantity ?? 1))
            } else {
                price = 0
            }
            return InvoiceItem(name: item.name, quantity: qty, price: price)
        }

        let invoiceType: InvoiceDocumentType = transaction.type == .income ? .income : .expense
        let documentKind: InvoiceDocumentKind = invoiceType == .income ? .workOrder : .invoice
        let normalizedConfidence = deriveConfidence(items: transaction.items, total: transaction.total, provided: confidence)
        let warnings = buildWarnings(items: transaction.items, total: transaction.total, confidence: normalizedConfidence)

        return ScannedInvoice(
            scannedAt: transaction.date,
            type: invoiceType,
            documentKind: documentKind,
            counterparty: transaction.counterparty,
            items: mappedItems,
            rawText: rawText,
            aiWarnings: warnings,
            aiConfidence: normalizedConfidence
        )
    }

    static func buildWarnings(items: [ExtractedTransactionItem], total: Double, confidence: Double?) -> [String] {
        var warnings: [String] = []
        let itemsSum = items.compactMap(\.total).reduce(0, +)
        if abs(itemsSum - total) > 0.5 {
            warnings.append("Сумма позиций (\(itemsSum)) не совпадает с итогом документа (\(total)).")
        }
        if let confidence, confidence < 0.65 {
            warnings.append("Низкая уверенность AI (\(Int(confidence * 100))%). Нужна ручная проверка.")
        }
        return warnings
    }

    static func deriveConfidence(items: [ExtractedTransactionItem], total: Double, provided: Double?) -> Double {
        if let provided {
            return max(0, min(1, provided))
        }
        var score = 0.45
        if !items.isEmpty { score += 0.2 }
        let named = items.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        if !items.isEmpty {
            score += (Double(named) / Double(items.count)) * 0.15
        }
        let hasTotals = items.filter { ($0.total ?? 0) > 0 }.count
        if !items.isEmpty {
            score += (Double(hasTotals) / Double(items.count)) * 0.15
        }
        if total > 0 { score += 0.05 }
        return max(0, min(1, score))
    }
}

#endif
