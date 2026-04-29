import XCTest
@testable import AutoCoreAccounting

// MARK: - AccountingItemNormalizer tests

final class AccountingItemNormalizerTests: XCTestCase {

    // MARK: normalize()

    func testNormalize_removesSpacesAndDashes() {
        XCTAssertEqual(AccountingItemNormalizer.normalize("EJ-253"), "ej253")
        XCTAssertEqual(AccountingItemNormalizer.normalize("ej 253"), "ej253")
        XCTAssertEqual(AccountingItemNormalizer.normalize("EJ_253"), "ej253")
    }

    func testNormalize_lowercasesLetters() {
        XCTAssertEqual(AccountingItemNormalizer.normalize("Subaru EJ253"), "subaruej253")
    }

    func testNormalize_stripsSymbols() {
        XCTAssertEqual(AccountingItemNormalizer.normalize("(EJ253)"), "ej253")
        XCTAssertEqual(AccountingItemNormalizer.normalize("EJ#253!"), "ej253")
    }

    func testNormalize_emptyInput() {
        XCTAssertEqual(AccountingItemNormalizer.normalize(""), "")
        XCTAssertEqual(AccountingItemNormalizer.normalize("---"), "")
    }

    // MARK: tokenize()

    func testTokenize_splitsOnNonAlphanumeric() {
        let tokens = AccountingItemNormalizer.tokenize("Subaru EJ253")
        XCTAssertTrue(tokens.contains("subaru"))
        XCTAssertTrue(tokens.contains("ej253"))
        XCTAssertEqual(tokens.count, 2)
    }

    func testTokenize_filtersShortTokens() {
        // "a" has 1 char — filtered out
        let tokens = AccountingItemNormalizer.tokenize("a EJ253")
        XCTAssertFalse(tokens.contains("a"))
        XCTAssertTrue(tokens.contains("ej253"))
    }

    // MARK: similarity()

    /// Core spec example: "ej253", "ej-253", "subaru ej253" → all the same item.
    func testSimilarity_canonicalTriple_allAboveThreshold() {
        let threshold = 0.8

        // ej-253 normalizes to ej253 → exact match
        XCTAssertEqual(AccountingItemNormalizer.similarity("ej253", "ej-253"), 1.0)

        // "subaru ej253" contains token "ej253" → token containment = 1.0
        XCTAssertGreaterThanOrEqual(AccountingItemNormalizer.similarity("ej253", "subaru ej253"), threshold)
        XCTAssertGreaterThanOrEqual(AccountingItemNormalizer.similarity("subaru ej253", "ej253"), threshold)
    }

    /// Different engine codes must NOT be merged.
    func testSimilarity_differentEngineCodes_belowThreshold() {
        // Levenshtein is capped at 0.79, so "ej253" vs "ej254" stays below 0.8.
        let score = AccountingItemNormalizer.similarity("ej253", "ej254")
        XCTAssertLessThan(score, 0.8, "Distinct engine codes must not merge (score \(score))")
    }

    func testSimilarity_exactMatch_returns1() {
        XCTAssertEqual(AccountingItemNormalizer.similarity("ej253", "ej253"), 1.0)
    }

    func testSimilarity_fullyDifferent_returns0orLow() {
        let score = AccountingItemNormalizer.similarity("ej253", "fb20")
        XCTAssertLessThan(score, 0.8)
    }

    func testSimilarity_emptyStrings() {
        XCTAssertEqual(AccountingItemNormalizer.similarity("", ""), 0.0)
        XCTAssertEqual(AccountingItemNormalizer.similarity("ej253", ""), 0.0)
    }

    // MARK: isAdvance()

    func testIsAdvance_detectsRussianKeywords() {
        XCTAssertTrue(AccountingItemNormalizer.isAdvance("Аванс от клиента"))
        XCTAssertTrue(AccountingItemNormalizer.isAdvance("Предоплата за товар"))
        XCTAssertTrue(AccountingItemNormalizer.isAdvance("задаток"))
        XCTAssertTrue(AccountingItemNormalizer.isAdvance("депозит"))
    }

    func testIsAdvance_detectsEnglishKeywords() {
        XCTAssertTrue(AccountingItemNormalizer.isAdvance("advance payment"))
        XCTAssertTrue(AccountingItemNormalizer.isAdvance("prepayment"))
    }

    func testIsAdvance_ordinaryRow_returnsFalse() {
        XCTAssertFalse(AccountingItemNormalizer.isAdvance("EJ253"))
        XCTAssertFalse(AccountingItemNormalizer.isAdvance("Продажа мотора"))
    }

    // MARK: parseLocalDate()

    func testParseLocalDate_noBiasToCorrectionDay() {
        // A date parsed as local must not shift to the previous day
        // (which can happen if the parser treats it as UTC midnight and the local TZ is UTC+N).
        let raw = "01.04.2026"
        guard let date = AccountingItemNormalizer.parseLocalDate(raw) else {
            XCTFail("Should parse dd.MM.yyyy")
            return
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        XCTAssertEqual(comps.year,  2026)
        XCTAssertEqual(comps.month, 4)
        XCTAssertEqual(comps.day,   1, "Date must not be shifted backward by timezone conversion")
    }

    func testParseLocalDate_multipleFormats() {
        let cases = [
            ("01.04.2026",  (2026, 4,  1)),
            ("1.4.2026",    (2026, 4,  1)),
            ("2026-04-01",  (2026, 4,  1)),
            ("01/04/2026",  (2026, 4,  1)),
        ]
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        for (raw, (y, m, d)) in cases {
            guard let date = AccountingItemNormalizer.parseLocalDate(raw) else {
                XCTFail("Could not parse: \(raw)")
                continue
            }
            let comps = cal.dateComponents([.year, .month, .day], from: date)
            XCTAssertEqual(comps.year, y,  "year mismatch for \(raw)")
            XCTAssertEqual(comps.month, m, "month mismatch for \(raw)")
            XCTAssertEqual(comps.day, d,   "day mismatch for \(raw)")
        }
    }

    func testParseLocalDate_excelSerial() {
        // Excel serial 45383 = 2024-03-28 in local time (no UTC shift).
        let date = AccountingItemNormalizer.parseLocalDate("45383")
        XCTAssertNotNil(date)
        if let date {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone.current
            let comps = cal.dateComponents([.year, .month, .day], from: date)
            XCTAssertEqual(comps.year,  2024)
            XCTAssertEqual(comps.month, 3)
            XCTAssertEqual(comps.day,   28)
        }
    }

    func testParseLocalDate_invalidInput_returnsNil() {
        XCTAssertNil(AccountingItemNormalizer.parseLocalDate(""))
        XCTAssertNil(AccountingItemNormalizer.parseLocalDate("not a date"))
    }

    // MARK: Levenshtein

    func testLevenshteinDistance_identical() {
        XCTAssertEqual(AccountingItemNormalizer.levenshteinDistance(Array("abc"), Array("abc")), 0)
    }

    func testLevenshteinDistance_oneInsertion() {
        XCTAssertEqual(AccountingItemNormalizer.levenshteinDistance(Array("ab"), Array("abc")), 1)
    }

    func testLevenshteinDistance_emptyStrings() {
        XCTAssertEqual(AccountingItemNormalizer.levenshteinDistance(Array(""), Array("")), 0)
        XCTAssertEqual(AccountingItemNormalizer.levenshteinDistance(Array("abc"), Array("")), 3)
    }
}

// MARK: - ExcelAccountingAnalysisService unit tests

final class ExcelAccountingAnalysisServiceTests: XCTestCase {

    private let service = ExcelAccountingAnalysisService()

    // MARK: - Column detection

    func testDetectColumns_recognisesRussianHeaders() {
        let header = ["Дата", "Название", "Количество", "Цена", "Категория"]
        let map = service.detectColumns(headerRow: header)
        XCTAssertEqual(map.date,     0)
        XCTAssertEqual(map.name,     1)
        XCTAssertEqual(map.quantity, 2)
        XCTAssertEqual(map.price,    3)
        XCTAssertEqual(map.category, 4)
    }

    func testDetectColumns_recognisesEnglishHeaders() {
        let header = ["date", "name", "qty", "price"]
        let map = service.detectColumns(headerRow: header)
        XCTAssertEqual(map.date,     0)
        XCTAssertEqual(map.name,     1)
        XCTAssertEqual(map.quantity, 2)
        XCTAssertEqual(map.price,    3)
    }

    // MARK: - parseNumber

    func testParseNumber_handlesThousandSeparators() {
        XCTAssertEqual(service.parseNumber("1 000 000"), 1_000_000)
        XCTAssertEqual(service.parseNumber("50,000"),    50_000)     // comma as thousands
        XCTAssertEqual(service.parseNumber("3.14"),      3.14)
    }

    func testParseNumber_nilForNonNumeric() {
        XCTAssertNil(service.parseNumber("abc"))
        XCTAssertNil(service.parseNumber(nil))
        XCTAssertNil(service.parseNumber(""))
    }

    // MARK: - Sheet role identification

    func testIdentifySheetRoles_allFourSheets() {
        let sheets = [
            ImportSheetData(name: "Проданные", rows: []),
            ImportSheetData(name: "Доходы",    rows: []),
            ImportSheetData(name: "Расходы",   rows: []),
            ImportSheetData(name: "Авансы",    rows: []),
        ]
        let roles = service.identifySheetRoles(sheets)
        XCTAssertEqual(roles.sold.count,     1)
        XCTAssertEqual(roles.income.count,   1)
        XCTAssertEqual(roles.expense.count,  1)
        XCTAssertEqual(roles.advances.count, 1)
    }

    func testIdentifySheetRoles_fallbackToIncome_whenNoSold() {
        let sheets = [
            ImportSheetData(name: "Доходы",  rows: []),
            ImportSheetData(name: "Расходы", rows: []),
        ]
        let roles = service.identifySheetRoles(sheets)
        XCTAssertTrue(roles.sold.isEmpty, "No sold sheet → sold array should be empty")
        XCTAssertEqual(roles.income.count, 1)
    }

    // MARK: - groupItems

    func testGroupItems_mergesNormalizedDuplicates() {
        let rows: [AccountingNormalizedRow] = [
            makeRow(raw: "ej253",       norm: "ej253"),
            makeRow(raw: "ej-253",      norm: "ej253"),   // same after normalize
            makeRow(raw: "subaru ej253", norm: "subaruej253"),
        ]
        let (groups, unmatched) = service.groupItems(saleRows: rows, costRows: [])
        // "ej253" and "ej-253" share normalized name → merged
        // "subaru ej253" has token "ej253" → also merged via token containment
        XCTAssertEqual(unmatched.count, 0)
        XCTAssertEqual(groups.count, 1, "All three should merge into one group")
        XCTAssertEqual(groups[0].saleRows.count, 3)
    }

    func testGroupItems_keepsSeparateGroups_forDifferentItems() {
        let rows: [AccountingNormalizedRow] = [
            makeRow(raw: "ej253", norm: "ej253"),
            makeRow(raw: "fb20",  norm: "fb20"),
        ]
        let (groups, _) = service.groupItems(saleRows: rows, costRows: [])
        XCTAssertEqual(groups.count, 2, "Distinct items should form separate groups")
    }

    func testGroupItems_unmatchedForBlankName() {
        let row = makeRow(raw: " ", norm: "")    // empty after normalize
        let (groups, unmatched) = service.groupItems(saleRows: [row], costRows: [])
        XCTAssertEqual(groups.count, 0)
        XCTAssertEqual(unmatched.count, 1)
        XCTAssertEqual(unmatched.first?.reason, "low confidence")
    }

    func testGroupItems_costWithNoMatchedItem_goesToUnmatched() {
        let saleRow = makeRow(raw: "ej253", norm: "ej253")
        let costRow = makeRow(raw: "fb20",  norm: "fb20")   // no sold item for fb20
        let (groups, unmatched) = service.groupItems(saleRows: [saleRow], costRows: [costRow])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(unmatched.count, 1)
        XCTAssertEqual(unmatched.first?.name, "fb20")
    }

    // MARK: - computeMetrics

    func testComputeMetrics_basicCalculations() {
        let group = MatchedItemGroup(
            canonicalName: "EJ253",
            aliases: ["EJ253"],
            saleRows: [
                makeRow(raw: "EJ253", norm: "ej253", qty: 2, price: 30_000),
                makeRow(raw: "EJ253", norm: "ej253", qty: 1, price: 35_000),
            ],
            costRows: [
                makeRow(raw: "EJ253 закупка", norm: "ej253zakupka", qty: 1, price: 50_000),
            ]
        )

        let result = service.computeMetrics(for: group)

        XCTAssertEqual(result.total_quantity,  3.0,    accuracy: 0.01)
        XCTAssertEqual(result.total_revenue,   95_000, accuracy: 0.01)  // 2*30k + 1*35k
        XCTAssertEqual(result.avg_sell_price,  95_000.0 / 3.0, accuracy: 0.01)
        XCTAssertEqual(result.cost_price,      50_000, accuracy: 0.01)
        XCTAssertEqual(result.profit,          45_000, accuracy: 0.01)
        let expectedMargin = (45_000.0 / 95_000.0) * 100.0
        XCTAssertEqual(result.margin, expectedMargin, accuracy: 0.01)
    }

    func testComputeMetrics_zeroRevenue_marginIsZero() {
        let group = MatchedItemGroup(
            canonicalName: "test",
            aliases: ["test"],
            saleRows: [makeRow(raw: "test", norm: "test", qty: 1, price: 0)],
            costRows: []
        )
        let result = service.computeMetrics(for: group)
        XCTAssertEqual(result.margin, 0.0)
    }

    // MARK: - extractAdvances

    func testExtractAdvances_fromAdvanceSheet() {
        let received = makeRow(raw: "Аванс получен", norm: "авансполучен", isAdvance: true, direction: .received)
        let paid     = makeRow(raw: "Аванс выдан",   norm: "авансвыдан",   isAdvance: true, direction: .paid)
        let result = service.extractAdvances(
            advanceRows: [received, paid],
            expenseRows: [],
            incomeRows: []
        )
        XCTAssertEqual(result.received, received.price * received.quantity, accuracy: 0.01)
        XCTAssertEqual(result.paid,     paid.price * paid.quantity,         accuracy: 0.01)
        XCTAssertEqual(result.balance,  result.received - result.paid,      accuracy: 0.01)
    }

    func testExtractAdvances_fromInlineExpenseAndIncomeRows() {
        let expenseAdv = makeRow(raw: "Аванс поставщику", norm: "авансположщику", isAdvance: true, direction: .paid,     qty: 1, price: 10_000)
        let incomeAdv  = makeRow(raw: "Предоплата клиент", norm: "предоплатаклиент", isAdvance: true, direction: .received, qty: 1, price: 25_000)

        let result = service.extractAdvances(
            advanceRows: [],
            expenseRows:  [expenseAdv],
            incomeRows:   [incomeAdv]
        )
        XCTAssertEqual(result.received, 25_000, accuracy: 0.01)
        XCTAssertEqual(result.paid,     10_000, accuracy: 0.01)
        XCTAssertEqual(result.balance,  15_000, accuracy: 0.01)
    }

    // MARK: - Full pipeline integration (no file I/O)

    /// Spec example: Проданные present → use it as sales source (not Доходы).
    func testAnalyze_usesSoldSheetWhenPresent() throws {
        let soldSheet = ImportSheetData(name: "Проданные", rows: [
            ["Название",      "Количество", "Цена"],
            ["EJ253",         "2",          "30000"],
        ])
        let incomeSheet = ImportSheetData(name: "Доходы", rows: [
            ["Описание",   "Сумма"],
            ["Другой товар", "5000"],
        ])
        let result = try service.analyze(sheets: [soldSheet, incomeSheet])

        XCTAssertEqual(result.sold_items.count, 1)
        XCTAssertEqual(result.sold_items[0].canonical_name, "EJ253")
        XCTAssertFalse(
            result.sold_items.contains { $0.canonical_name == "Другой товар" },
            "Доходы should be ignored when Проданные is present"
        )
    }

    /// Spec example: no Проданные → fall back to Доходы as sales source.
    func testAnalyze_fallsBackToIncome_whenNoSoldSheet() throws {
        let incomeSheet = ImportSheetData(name: "Доходы", rows: [
            ["Описание", "Сумма"],
            ["EJ253",    "30000"],
        ])
        let result = try service.analyze(sheets: [incomeSheet])

        XCTAssertEqual(result.sold_items.count, 1)
        XCTAssertEqual(result.sold_items[0].canonical_name, "EJ253")
    }

    /// Advances created inside the app (from Расходы rows with advance keywords).
    func testAnalyze_advancesFromExpenseRows() throws {
        let expenseSheet = ImportSheetData(name: "Расходы", rows: [
            ["Описание",              "Сумма"],
            ["Аванс поставщику EJ",   "15000"],
            ["Покупка запчасти",      "5000"],
        ])
        let result = try service.analyze(sheets: [expenseSheet])

        XCTAssertEqual(result.advances.paid, 15_000, accuracy: 0.01)
    }

    func testAnalyze_outputIsValidJSON() throws {
        let sheet = ImportSheetData(name: "Проданные", rows: [
            ["Товар", "Кол-во", "Цена"],
            ["EJ253", "1",      "30000"],
        ])
        let service2 = ExcelAccountingAnalysisService()
        let result = try service2.analyze(sheets: [sheet])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(result)
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(json is [String: Any], "Result must be a JSON object")
    }

    func testAnalyze_strictJSONKeys_matchSpec() throws {
        let sheet = ImportSheetData(name: "Проданные", rows: [
            ["Товар", "Кол-во", "Цена"],
            ["EJ253", "2",      "50000"],
        ])
        let result = try service.analyze(sheets: [sheet])
        let encoder = JSONEncoder()
        let data = try encoder.encode(result)
        let dict = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNotNil(dict["sold_items"])
        XCTAssertNotNil(dict["advances"])
        XCTAssertNotNil(dict["unmatched"])

        if let soldItems = dict["sold_items"] as? [[String: Any]],
           let first = soldItems.first {
            XCTAssertNotNil(first["canonical_name"])
            XCTAssertNotNil(first["aliases"])
            XCTAssertNotNil(first["total_quantity"])
            XCTAssertNotNil(first["avg_sell_price"])
            XCTAssertNotNil(first["total_revenue"])
            XCTAssertNotNil(first["cost_price"])
            XCTAssertNotNil(first["profit"])
            XCTAssertNotNil(first["margin"])
            XCTAssertNotNil(first["transactions"])
        } else {
            XCTFail("sold_items should have at least one entry")
        }

        if let advances = dict["advances"] as? [String: Any] {
            XCTAssertNotNil(advances["received"])
            XCTAssertNotNil(advances["paid"])
            XCTAssertNotNil(advances["balance"])
        } else {
            XCTFail("advances key must be present in JSON")
        }
    }
}

// MARK: - Test helpers

private func makeRow(
    raw: String,
    norm: String,
    qty: Double = 1,
    price: Double = 1000,
    isAdvance: Bool = false,
    direction: AccountingNormalizedRow.AdvanceDirection = .none,
    sheet: String = "Test"
) -> AccountingNormalizedRow {
    AccountingNormalizedRow(
        sheetName: sheet,
        rawName: raw,
        normalizedName: norm,
        quantity: qty,
        price: price,
        date: nil,
        category: "",
        isAdvance: isAdvance,
        advanceDirection: direction
    )
}
