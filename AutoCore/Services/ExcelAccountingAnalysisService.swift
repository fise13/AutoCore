import Foundation

/// Orchestrates the full Excel accounting analysis pipeline:
/// parse sheets → normalize rows → group items → compute metrics → strict JSON output
final class ExcelAccountingAnalysisService {

    private let importer = ExcelImportService()
    /// Minimum similarity required to merge two item names into one group.
    let similarityThreshold: Double = 0.8

    // MARK: - Public API

    /// Load an `.xlsx` file, analyze it, and return the result as pretty-printed JSON `Data`.
    func analyzeToJSON(url: URL) throws -> Data {
        let sheets = try importer.loadSheets(from: url)
        let result = try analyze(sheets: sheets)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(result)
    }

    /// Analyze pre-parsed sheets and return a structured result.
    /// Exposed as internal (non-private) so it can be called from unit tests.
    func analyze(sheets: [ImportSheetData]) throws -> AccountingAnalysisResult {
        let roles = identifySheetRoles(sheets)

        // Rule: use "Проданные" as sales source; fall back to "Доходы" if absent.
        let salesSheets = roles.sold.isEmpty ? roles.income : roles.sold

        let saleRows     = salesSheets.flatMap   { parseRows(sheet: $0, context: .sale) }
        let expenseRows  = roles.expense.flatMap { parseRows(sheet: $0, context: .expense) }
        // When "Проданные" exists, "Доходы" rows contribute only as advance sources.
        let incomeRows   = roles.sold.isEmpty ? [] : roles.income.flatMap { parseRows(sheet: $0, context: .income) }
        let advSheetRows = roles.advances.flatMap { parseRows(sheet: $0, context: .advance) }

        // Extract advances before filtering, so advance-tagged rows are counted correctly.
        let advances = extractAdvances(
            advanceRows: advSheetRows,
            expenseRows: expenseRows,
            incomeRows: incomeRows + saleRows
        )

        // Remove advance rows from sale/expense streams so they don't appear as sold items.
        let filteredSaleRows    = saleRows.filter    { !$0.isAdvance }
        let filteredExpenseRows = expenseRows.filter { !$0.isAdvance }

        let (groups, unmatchedEntries) = groupItems(
            saleRows: filteredSaleRows,
            costRows: filteredExpenseRows
        )

        let soldItems = groups.map { computeMetrics(for: $0) }

        return AccountingAnalysisResult(
            sold_items: soldItems,
            advances: advances,
            unmatched: unmatchedEntries.map {
                AccountingAnalysisResult.UnmatchedResult(name: $0.name, reason: $0.reason)
            }
        )
    }

    // MARK: - Sheet role identification

    struct SheetRoles {
        var sold: [ImportSheetData]     = []
        var income: [ImportSheetData]   = []
        var expense: [ImportSheetData]  = []
        var advances: [ImportSheetData] = []
    }

    func identifySheetRoles(_ sheets: [ImportSheetData]) -> SheetRoles {
        var roles = SheetRoles()
        for sheet in sheets {
            let n = sheet.name.lowercased()
            if ["проданные", "sold", "продажи", "реализация"].contains(where: { n.contains($0) }) {
                roles.sold.append(sheet)
            } else if ["доходы", "доход", "income", "приход", "поступлени"].contains(where: { n.contains($0) }) {
                roles.income.append(sheet)
            } else if ["расходы", "расход", "expense", "затрат"].contains(where: { n.contains($0) }) {
                roles.expense.append(sheet)
            } else if ["авансы", "аванс", "advance", "prepayment"].contains(where: { n.contains($0) }) {
                roles.advances.append(sheet)
            }
        }
        return roles
    }

    // MARK: - Column detection

    enum SheetContext { case sale, income, expense, advance }

    struct ColumnMap {
        var name: Int?
        var quantity: Int?
        var price: Int?
        var date: Int?
        var category: Int?
        var direction: Int?   // for advances: received / paid column
    }

    func detectColumns(headerRow: [String]) -> ColumnMap {
        var map = ColumnMap()
        for (i, raw) in headerRow.enumerated() {
            let h = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if      map.name == nil,      isNameHeader(h)      { map.name = i }
            else if map.quantity == nil,  isQuantityHeader(h)  { map.quantity = i }
            else if map.price == nil,     isPriceHeader(h)     { map.price = i }
            else if map.date == nil,      isDateHeader(h)      { map.date = i }
            else if map.category == nil,  isCategoryHeader(h)  { map.category = i }
            else if map.direction == nil, isDirectionHeader(h) { map.direction = i }
        }
        return map
    }

    private func isNameHeader(_ h: String) -> Bool {
        ["название", "наименование", "товар", "мотор", "двигатель",
         "name", "описание", "description", "item", "продукт", "позиция"].contains { h.contains($0) }
    }

    private func isQuantityHeader(_ h: String) -> Bool {
        ["количество", "кол-во", "кол.", "qty", "count", "шт."].contains { h.contains($0) }
    }

    private func isPriceHeader(_ h: String) -> Bool {
        ["цена", "сумма", "price", "стоимость", "выручка",
         "amount", "себестоимость", "закупка"].contains { h.contains($0) }
    }

    private func isDateHeader(_ h: String) -> Bool {
        ["дата", "date", "число"].contains { h.contains($0) }
    }

    private func isCategoryHeader(_ h: String) -> Bool {
        ["категория", "category", "раздел"].contains { h.contains($0) }
    }

    private func isDirectionHeader(_ h: String) -> Bool {
        ["направление", "direction", "тип операции", "operation"].contains { h.contains($0) }
    }

    // MARK: - Row parsing

    func parseRows(sheet: ImportSheetData, context: SheetContext) -> [AccountingNormalizedRow] {
        guard !sheet.rows.isEmpty else { return [] }

        let headerRow = sheet.rows[0]
        let colMap = detectColumns(headerRow: headerRow)

        var result: [AccountingNormalizedRow] = []

        for row in sheet.rows.dropFirst() {
            guard !row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { continue }

            let rawName = cellValue(row, at: colMap.name) ?? firstNonEmpty(row) ?? ""
            let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }

            let qty      = parseNumber(cellValue(row, at: colMap.quantity)) ?? 1.0
            let price    = parseNumber(cellValue(row, at: colMap.price))    ?? 0.0
            let rawDate  = cellValue(row, at: colMap.date)                  ?? ""
            let category = cellValue(row, at: colMap.category)              ?? ""
            let dirRaw   = cellValue(row, at: colMap.direction)             ?? ""

            let normalizedName = AccountingItemNormalizer.normalize(trimmedName)
            let isAdv = AccountingItemNormalizer.isAdvance(trimmedName)
                     || AccountingItemNormalizer.isAdvance(category)

            let direction: AccountingNormalizedRow.AdvanceDirection
            if isAdv {
                let dl = dirRaw.lowercased()
                switch context {
                case .income: direction = .received
                case .expense: direction = .paid
                case .sale:   direction = .received
                case .advance:
                    if dl.contains("получен") || dl.contains("receive") || dl.contains("доход") {
                        direction = .received
                    } else if dl.contains("выдан") || dl.contains("paid") || dl.contains("расход") {
                        direction = .paid
                    } else {
                        direction = .received  // default for ambiguous advance rows
                    }
                }
            } else {
                direction = .none
            }

            result.append(AccountingNormalizedRow(
                sheetName: sheet.name,
                rawName: trimmedName,
                normalizedName: normalizedName,
                quantity: qty,
                price: price,
                date: AccountingItemNormalizer.parseLocalDate(rawDate),
                category: category,
                isAdvance: isAdv,
                advanceDirection: direction
            ))
        }
        return result
    }

    // MARK: - Helpers

    private func cellValue(_ row: [String], at index: Int?) -> String? {
        guard let i = index, i < row.count else { return nil }
        let v = row[i].trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }

    private func firstNonEmpty(_ row: [String]) -> String? {
        row.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Parse a number string, handling spaces and commas as thousand separators.
    func parseNumber(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        let cleaned = raw
            .replacingOccurrences(of: "\u{00A0}", with: "")   // non-breaking space
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    // MARK: - Item grouping

    struct UnmatchedEntry {
        let name: String
        let reason: String
    }

    /// Group sale and cost rows by item name similarity.
    /// Rows with normalized name length < 2 go straight to unmatched.
    /// Cost rows that don't match any known sold item also go to unmatched.
    func groupItems(
        saleRows: [AccountingNormalizedRow],
        costRows: [AccountingNormalizedRow]
    ) -> ([MatchedItemGroup], [UnmatchedEntry]) {
        var groups:    [MatchedItemGroup] = []
        var unmatched: [UnmatchedEntry]  = []

        for row in saleRows {
            if row.normalizedName.count < 2 {
                unmatched.append(UnmatchedEntry(
                    name: row.rawName.isEmpty ? "(пусто)" : row.rawName,
                    reason: "low confidence"
                ))
                continue
            }
            if let idx = bestGroupIndex(for: row.rawName, in: groups) {
                groups[idx].saleRows.append(row)
                groups[idx].aliases.insert(row.rawName)
            } else {
                groups.append(MatchedItemGroup(
                    canonicalName: row.rawName,
                    aliases: [row.rawName],
                    saleRows: [row],
                    costRows: []
                ))
            }
        }

        for row in costRows {
            if row.normalizedName.count < 2 {
                unmatched.append(UnmatchedEntry(
                    name: row.rawName.isEmpty ? "(пусто)" : row.rawName,
                    reason: "low confidence"
                ))
                continue
            }
            if let idx = bestGroupIndex(for: row.rawName, in: groups) {
                groups[idx].costRows.append(row)
                groups[idx].aliases.insert(row.rawName)
            } else {
                // Cost has no matching sold item — cannot attribute it.
                unmatched.append(UnmatchedEntry(name: row.rawName, reason: "low confidence"))
            }
        }

        return (groups, unmatched)
    }

    func bestGroupIndex(for name: String, in groups: [MatchedItemGroup]) -> Int? {
        var bestIdx: Int? = nil
        var bestScore = -1.0
        for (i, group) in groups.enumerated() {
            let score = AccountingItemNormalizer.similarity(name, group.canonicalName)
            if score >= similarityThreshold, score > bestScore {
                bestScore = score
                bestIdx = i
            }
        }
        return bestIdx
    }

    // MARK: - Metric computation

    func computeMetrics(for group: MatchedItemGroup) -> AccountingAnalysisResult.SoldItemResult {
        let totalQty     = group.saleRows.reduce(0.0) { $0 + $1.quantity }
        let totalRevenue = group.saleRows.reduce(0.0) { $0 + ($1.price * $1.quantity) }
        let avgPrice     = totalQty > 0 ? totalRevenue / totalQty : 0.0
        let totalCost    = group.costRows.reduce(0.0) { $0 + $1.price }
        let profit       = totalRevenue - totalCost
        let margin       = totalRevenue > 0 ? (profit / totalRevenue) * 100.0 : 0.0

        let fmt = makeDateFormatter()
        let transactions = group.saleRows.map { row in
            AccountingAnalysisResult.TransactionResult(
                date: row.date.map { fmt.string(from: $0) },
                quantity: row.quantity,
                price: row.price,
                sheet: row.sheetName
            )
        }

        let aliases = group.aliases
            .filter { $0 != group.canonicalName }
            .sorted()

        return AccountingAnalysisResult.SoldItemResult(
            canonical_name: group.canonicalName,
            aliases: aliases,
            total_quantity: round2(totalQty),
            avg_sell_price: round2(avgPrice),
            total_revenue: round2(totalRevenue),
            cost_price: round2(totalCost),
            profit: round2(profit),
            margin: round2(margin),
            transactions: transactions
        )
    }

    private func makeDateFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone.current
        return f
    }

    private func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }

    // MARK: - Advances extraction

    func extractAdvances(
        advanceRows: [AccountingNormalizedRow],
        expenseRows:  [AccountingNormalizedRow],
        incomeRows:   [AccountingNormalizedRow]
    ) -> AccountingAnalysisResult.AdvancesResult {
        var received = 0.0
        var paid     = 0.0

        for row in advanceRows {
            let amount = row.price * row.quantity
            switch row.advanceDirection {
            case .received: received += amount
            case .paid:     paid     += amount
            case .none:     received += amount  // default: treat as received
            }
        }

        for row in expenseRows where row.isAdvance {
            paid += row.price * row.quantity
        }

        for row in incomeRows where row.isAdvance {
            received += row.price * row.quantity
        }

        return AccountingAnalysisResult.AdvancesResult(
            received: round2(received),
            paid:     round2(paid),
            balance:  round2(received - paid)
        )
    }
}
