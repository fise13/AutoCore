import Foundation

enum InvoiceDocumentType: String, CaseIterable, Identifiable, Codable {
    case income
    case expense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: return "Приход"
        case .expense: return "Расход"
        }
    }
}

enum InvoiceDocumentKind: String, CaseIterable, Identifiable, Codable {
    case workOrder
    case invoice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workOrder: return "Заказ-наряд"
        case .invoice: return "Накладная"
        }
    }

    var suggestedType: InvoiceDocumentType {
        switch self {
        case .workOrder: return .income
        case .invoice: return .expense
        }
    }
}

struct InvoiceItem: Identifiable, Equatable {
    var id: String {
        "\(name)-\(quantity)-\(price)-\(motorSerial ?? "")-\(selectedMotorLocalId ?? -1)-\(selectedMotorCloudId ?? "")"
    }
    var name: String
    var quantity: Decimal
    var price: Decimal
    var motorSerial: String? = nil
    var selectedMotorLocalId: Int64? = nil
    var selectedMotorCloudId: String? = nil
    var selectedMotorSerial: String? = nil

    var total: Decimal { quantity * price }
}

struct ScannedInvoice: Identifiable {
    let id: String
    var scannedAt: Date
    var type: InvoiceDocumentType
    var documentKind: InvoiceDocumentKind
    var counterparty: String?
    var items: [InvoiceItem]
    var rawText: String?
    var aiWarnings: [String]
    var aiConfidence: Double?

    var totalAmount: Decimal {
        items.reduce(0) { $0 + $1.total }
    }

    init(
        id: String = UUID().uuidString,
        scannedAt: Date = Date(),
        type: InvoiceDocumentType = .expense,
        documentKind: InvoiceDocumentKind = .invoice,
        counterparty: String? = nil,
        items: [InvoiceItem],
        rawText: String? = nil,
        aiWarnings: [String] = [],
        aiConfidence: Double? = nil
    ) {
        self.id = id
        self.scannedAt = scannedAt
        self.type = type
        self.documentKind = documentKind
        self.counterparty = counterparty
        self.items = items
        self.rawText = rawText
        self.aiWarnings = aiWarnings
        self.aiConfidence = aiConfidence
    }
}
