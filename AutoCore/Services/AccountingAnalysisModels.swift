import Foundation

// MARK: - Intermediate pipeline models

/// A single parsed row from any accounting sheet, after normalization.
struct AccountingNormalizedRow {
    let sheetName: String
    let rawName: String
    let normalizedName: String  // lowercase, alphanumeric only
    let quantity: Double
    let price: Double
    let date: Date?
    let category: String
    let isAdvance: Bool
    let advanceDirection: AdvanceDirection

    enum AdvanceDirection {
        case received   // income advance (аванс получен)
        case paid       // expense advance (аванс выдан)
        case none
    }
}

/// A group of rows determined to be the same product/item via name matching.
struct MatchedItemGroup {
    var canonicalName: String       // first seen name used as canonical
    var aliases: Set<String>        // all raw names encountered (incl. canonical)
    var saleRows: [AccountingNormalizedRow]
    var costRows: [AccountingNormalizedRow]
}

// MARK: - Final JSON output models (strictly matching the spec schema)

struct AccountingAnalysisResult: Encodable {
    let sold_items: [SoldItemResult]
    let advances: AdvancesResult
    let unmatched: [UnmatchedResult]

    struct SoldItemResult: Encodable {
        let canonical_name: String
        let aliases: [String]
        let total_quantity: Double
        let avg_sell_price: Double
        let total_revenue: Double
        let cost_price: Double
        let profit: Double
        let margin: Double
        let transactions: [TransactionResult]
    }

    struct AdvancesResult: Encodable {
        let received: Double
        let paid: Double
        let balance: Double
    }

    struct UnmatchedResult: Encodable {
        let name: String
        let reason: String
    }

    struct TransactionResult: Encodable {
        let date: String?
        let quantity: Double
        let price: Double
        let sheet: String
    }
}
