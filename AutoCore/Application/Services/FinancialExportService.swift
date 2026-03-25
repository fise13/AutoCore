import Foundation
import ZIPFoundation
#if os(macOS)
import PDFKit
import AppKit
import CoreText
#endif

/// Сервис экспорта финансовых операций в Excel и PDF
final class FinancialExportService {
    private let financialOperationRepository: FinancialOperationRepository
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
    
    private let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
    
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = " "
        return formatter
    }()
    
    init(financialOperationRepository: FinancialOperationRepository) {
        self.financialOperationRepository = financialOperationRepository
    }
    
    /// Экспорт в Excel
    func exportToExcel(config: FinancialExportConfig, to url: URL) throws -> URL {
        try config.validate()
        
        // Загружаем операции
        let operations = try loadOperations(config: config)
        
        guard !operations.isEmpty else {
            throw FinancialExportError.noData
        }
        
        // Удаляем существующий файл
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        
        // Создаём Excel файл
        let archive = try Archive(url: url, accessMode: .create)
        
        var sheets: [ExcelSheet] = []
        var sheetId = 1
        var relationshipId = 1
        
        // Лист 1: Обзор (если включён)
        if config.includeSummary {
            let summarySheet = try buildSummarySheet(
                operations: operations,
                config: config,
                sheetId: sheetId,
                relationshipId: relationshipId
            )
            sheets.append(summarySheet)
            sheetId += 1
            relationshipId += 1
        }
        
        // Листы по типам операций (если splitBySheets = true)
        if config.splitBySheets {
            if config.includedOperationTypes.contains(.sale) {
                let sales = operations.filter { $0.type == .sale }
                if !sales.isEmpty {
                    let salesSheet = try buildSalesSheet(
                        operations: sales,
                        sheetId: sheetId,
                        relationshipId: relationshipId
                    )
                    sheets.append(salesSheet)
                    sheetId += 1
                    relationshipId += 1
                }
            }
            
            if config.includedOperationTypes.contains(.expense) {
                let expenses = operations.filter { $0.type == .expense }
                if !expenses.isEmpty {
                    let expensesSheet = try buildExpensesSheet(
                        operations: expenses,
                        sheetId: sheetId,
                        relationshipId: relationshipId
                    )
                    sheets.append(expensesSheet)
                    sheetId += 1
                    relationshipId += 1
                }
            }
            
            if config.includedOperationTypes.contains(.refund) {
                let refunds = operations.filter { $0.type == .refund }
                if !refunds.isEmpty {
                    let refundsSheet = try buildRefundsSheet(
                        operations: refunds,
                        sheetId: sheetId,
                        relationshipId: relationshipId
                    )
                    sheets.append(refundsSheet)
                    sheetId += 1
                    relationshipId += 1
                }
            }
        } else {
            // Один лист со всеми операциями
            let allOperationsSheet = try buildAllOperationsSheet(
                operations: operations,
                sheetId: sheetId,
                relationshipId: relationshipId
            )
            sheets.append(allOperationsSheet)
        }
        
        // Собираем Excel файл
        try buildExcelFile(sheets: sheets, archive: archive)
        
        return url
    }
    
    /// Экспорт в PDF
    #if os(macOS)
    func exportToPDF(config: FinancialExportConfig, to url: URL) throws -> URL {
        try config.validate()
        
        // Загружаем операции
        let operations = try loadOperations(config: config)
        
        guard !operations.isEmpty else {
            throw FinancialExportError.noData
        }
        
        // Создаём PDF документ
        let pdfDocument = PDFDocument()
        
        var pageNumber = 0
        
        // Страница 1: Обзор (если включён)
        if config.includeSummary {
            let summaryPage = try buildSummaryPDFPage(
                operations: operations,
                config: config,
                pageNumber: pageNumber
            )
            pdfDocument.insert(summaryPage, at: pageNumber)
            pageNumber += 1
        }
        
        // Страницы по типам операций
        if config.includedOperationTypes.contains(.sale) {
            let sales = operations.filter { $0.type == .sale }
            if !sales.isEmpty {
                let salesPages = try buildSalesPDFPages(operations: sales, startPage: pageNumber)
                for page in salesPages {
                    pdfDocument.insert(page, at: pageNumber)
                    pageNumber += 1
                }
            }
        }
        
        if config.includedOperationTypes.contains(.expense) {
            let expenses = operations.filter { $0.type == .expense }
            if !expenses.isEmpty {
                let expensesPages = try buildExpensesPDFPages(operations: expenses, startPage: pageNumber)
                for page in expensesPages {
                    pdfDocument.insert(page, at: pageNumber)
                    pageNumber += 1
                }
            }
        }
        
        if config.includedOperationTypes.contains(.refund) {
            let refunds = operations.filter { $0.type == .refund }
            if !refunds.isEmpty {
                let refundsPages = try buildRefundsPDFPages(operations: refunds, startPage: pageNumber)
                for page in refundsPages {
                    pdfDocument.insert(page, at: pageNumber)
                    pageNumber += 1
                }
            }
        }
        
        // Удаляем существующий файл
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        
        // Сохраняем PDF
        guard pdfDocument.write(to: url) else {
            throw FinancialExportError.exportFailed(message: "Не удалось сохранить PDF файл")
        }
        
        return url
    }
    #else
    func exportToPDF(config: FinancialExportConfig, to url: URL) throws -> URL {
        throw FinancialExportError.exportFailed(message: "Экспорт в PDF доступен только на macOS")
    }
    #endif
    
    // MARK: - Data Loading
    
    private func loadOperations(config: FinancialExportConfig) throws -> [FinancialOperationEntity] {
        let filter = FinancialOperationFilter(
            type: nil, // Фильтруем по типам вручную
            account: nil,
            relatedMotorID: nil,
            fromDate: config.dateRange?.start,
            toDate: config.dateRange?.end,
            limit: nil,
            offset: nil
        )
        
        var allOperations = try financialOperationRepository.findAll(filter: filter)
        
        // Фильтруем по типам операций
        allOperations = allOperations.filter { config.includedOperationTypes.contains($0.type) }
        
        // Сортируем по дате (новые сначала)
        allOperations.sort { $0.createdAt > $1.createdAt }
        
        return allOperations
    }
    
    // MARK: - Excel Building
    
    private struct ExcelSheet {
        let id: Int
        let relationshipId: Int
        let name: String
        let rows: [[String]]
        let columnWidths: [Int]?
    }
    
    private func buildSummarySheet(
        operations: [FinancialOperationEntity],
        config: FinancialExportConfig,
        sheetId: Int,
        relationshipId: Int
    ) throws -> ExcelSheet {
        var rows: [[String]] = []
        
        // Заголовок
        rows.append(["ОБЗОР ФИНАНСОВЫХ ОПЕРАЦИЙ"])
        rows.append([])
        
        // Период
        if let range = config.dateRange {
            rows.append(["Период:", "\(dateFormatter.string(from: range.start)) - \(dateFormatter.string(from: range.end))"])
        } else {
            rows.append(["Период:", "Все данные"])
        }
        rows.append([])
        
        // Итоги по типам операций
        let sales = operations.filter { $0.type == .sale }
        let expenses = operations.filter { $0.type == .expense }
        let refunds = operations.filter { $0.type == .refund }
        
        let totalSales = sales.reduce(Decimal(0)) { $0 + $1.amount }
        let totalExpenses = expenses.reduce(Decimal(0)) { $0 + $1.amount }
        let totalRefunds = refunds.reduce(Decimal(0)) { $0 + $1.amount }
        
        rows.append(["ПРОДАЖИ"])
        rows.append(["Количество:", "\(sales.count)"])
        rows.append(["Сумма:", formatCurrency(totalSales)])
        rows.append([])
        
        rows.append(["РАСХОДЫ"])
        rows.append(["Количество:", "\(expenses.count)"])
        rows.append(["Сумма:", formatCurrency(totalExpenses)])
        rows.append([])
        
        rows.append(["ВОЗВРАТЫ"])
        rows.append(["Количество:", "\(refunds.count)"])
        rows.append(["Сумма:", formatCurrency(totalRefunds)])
        rows.append([])
        
        // Чистый результат
        let netResult = totalSales - totalExpenses - totalRefunds
        rows.append(["ЧИСТЫЙ РЕЗУЛЬТАТ:", formatCurrency(netResult)])
        rows.append([])
        
        // Балансы по счетам
        let cashboxBalance = try financialOperationRepository.calculateCashBalance(account: .cashbox, upToDate: config.dateRange?.end)
        let kaspiBalance = try financialOperationRepository.calculateCashBalance(account: .kaspi, upToDate: config.dateRange?.end)
        
        rows.append(["БАЛАНСЫ"])
        rows.append(["Касса:", formatCurrency(cashboxBalance)])
        rows.append(["Каспи:", formatCurrency(kaspiBalance)])
        
        return ExcelSheet(
            id: sheetId,
            relationshipId: relationshipId,
            name: "Обзор",
            rows: rows,
            columnWidths: [30, 20]
        )
    }
    
    private func buildSalesSheet(
        operations: [FinancialOperationEntity],
        sheetId: Int,
        relationshipId: Int
    ) -> ExcelSheet {
        var rows: [[String]] = []
        
        // Заголовки
        rows.append(["Дата", "Мотор", "Цена", "Способ оплаты", "Счёт", "Пользователь", "Комментарий"])
        
        // Данные
        for operation in operations {
            let motorInfo = operation.relatedMotorID != nil ? "Мотор #\(operation.relatedMotorID!)" : "—"
            let paymentMethod = formatPaymentMethod(operation.paymentMethod)
            let account = operation.account == .cashbox ? "Касса" : "Каспи"
            
            rows.append([
                dateFormatter.string(from: operation.createdAt),
                motorInfo,
                formatCurrency(operation.amount),
                paymentMethod,
                account,
                operation.createdByUser,
                operation.comment
            ])
        }
        
        // Итого
        let total = operations.reduce(Decimal(0)) { $0 + $1.amount }
        rows.append([])
        rows.append(["ИТОГО:", "", formatCurrency(total), "", "", "", ""])
        
        return ExcelSheet(
            id: sheetId,
            relationshipId: relationshipId,
            name: "Продажи",
            rows: rows,
            columnWidths: [15, 15, 15, 15, 10, 15, 30]
        )
    }
    
    private func buildExpensesSheet(
        operations: [FinancialOperationEntity],
        sheetId: Int,
        relationshipId: Int
    ) -> ExcelSheet {
        var rows: [[String]] = []
        
        // Заголовки
        rows.append(["Дата", "Сумма", "Счёт", "Категория", "Описание", "Пользователь"])
        
        // Данные
        for operation in operations {
            let account = operation.account == .cashbox ? "Касса" : "Каспи"
            
            rows.append([
                dateFormatter.string(from: operation.createdAt),
                formatCurrency(operation.amount),
                account,
                operation.category ?? "—",
                operation.description,
                operation.createdByUser
            ])
        }
        
        // Итого
        let total = operations.reduce(Decimal(0)) { $0 + $1.amount }
        rows.append([])
        rows.append(["ИТОГО:", formatCurrency(total), "", "", "", ""])
        
        return ExcelSheet(
            id: sheetId,
            relationshipId: relationshipId,
            name: "Расходы",
            rows: rows,
            columnWidths: [15, 15, 10, 20, 40, 15]
        )
    }
    
    private func buildRefundsSheet(
        operations: [FinancialOperationEntity],
        sheetId: Int,
        relationshipId: Int
    ) -> ExcelSheet {
        var rows: [[String]] = []
        
        // Заголовки
        rows.append(["Дата", "Мотор", "Сумма", "Способ оплаты", "Счёт", "Пользователь", "Комментарий"])
        
        // Данные
        for operation in operations {
            let motorInfo = operation.relatedMotorID != nil ? "Мотор #\(operation.relatedMotorID!)" : "—"
            let paymentMethod = formatPaymentMethod(operation.paymentMethod)
            let account = operation.account == .cashbox ? "Касса" : "Каспи"
            
            rows.append([
                dateFormatter.string(from: operation.createdAt),
                motorInfo,
                formatCurrency(operation.amount),
                paymentMethod,
                account,
                operation.createdByUser,
                operation.comment
            ])
        }
        
        // Итого
        let total = operations.reduce(Decimal(0)) { $0 + $1.amount }
        rows.append([])
        rows.append(["ИТОГО:", "", formatCurrency(total), "", "", "", ""])
        
        return ExcelSheet(
            id: sheetId,
            relationshipId: relationshipId,
            name: "Возвраты",
            rows: rows,
            columnWidths: [15, 15, 15, 15, 10, 15, 30]
        )
    }
    
    private func buildAllOperationsSheet(
        operations: [FinancialOperationEntity],
        sheetId: Int,
        relationshipId: Int
    ) -> ExcelSheet {
        var rows: [[String]] = []
        
        // Заголовки
        rows.append(["Дата", "Тип", "Сумма", "Счёт", "Способ оплаты", "Связанный объект", "Комментарий"])
        
        // Данные
        for operation in operations {
            let typeName = formatOperationType(operation.type)
            let account = operation.account == .cashbox ? "Касса" : "Каспи"
            let paymentMethod = formatPaymentMethod(operation.paymentMethod)
            let relatedObject = operation.relatedMotorID != nil ? "Мотор #\(operation.relatedMotorID!)" : (operation.category ?? "—")
            
            rows.append([
                dateFormatter.string(from: operation.createdAt),
                typeName,
                formatCurrency(operation.amount),
                account,
                paymentMethod,
                relatedObject,
                operation.comment
            ])
        }
        
        // Итого
        let total = operations.reduce(Decimal(0)) { $0 + $1.amount }
        rows.append([])
        rows.append(["ИТОГО:", "", formatCurrency(total), "", "", "", ""])
        
        return ExcelSheet(
            id: sheetId,
            relationshipId: relationshipId,
            name: "Все операции",
            rows: rows,
            columnWidths: [15, 12, 15, 10, 15, 20, 30]
        )
    }
    
    private func buildExcelFile(sheets: [ExcelSheet], archive: Archive) throws {
        // 1. Workbook XML
        let workbookXML = buildWorkbookXML(sheets: sheets)
        try addEntry("xl/workbook.xml", data: workbookXML, to: archive)
        
        // 2. Root relationships
        let relsXML = buildRootRelsXML()
        try addEntry("_rels/.rels", data: relsXML, to: archive)
        
        // 3. Workbook relationships
        let workbookRelsXML = buildWorkbookRelsXML(sheets: sheets)
        try addEntry("xl/_rels/workbook.xml.rels", data: workbookRelsXML, to: archive)
        
        // 4. Content types
        let contentTypesXML = buildContentTypesXML(sheets: sheets)
        try addEntry("[Content_Types].xml", data: contentTypesXML, to: archive)
        
        
        // 6. Создаём общую карту shared strings
        var allStrings: [String] = []
        var sharedStringMap: [String: Int] = [:]
        
        for sheet in sheets {
            for row in sheet.rows {
                for cell in row {
                    if !sharedStringMap.keys.contains(cell) {
                        sharedStringMap[cell] = allStrings.count
                        allStrings.append(cell)
                    }
                }
            }
        }
        
        // 7. Shared strings
        var stringsXML = ""
        for str in allStrings {
            stringsXML += """
            <si><t>\(escapeXML(str))</t></si>
            """
        }
        
        let sharedStringsXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\(allStrings.count)" uniqueCount="\(allStrings.count)">
          \(stringsXML)
        </sst>
        """
        try addEntry("xl/sharedStrings.xml", data: Data(sharedStringsXML.utf8), to: archive)
        
        // 8. Worksheets
        for sheet in sheets {
            let worksheetXML = buildWorksheetXML(sheet: sheet, sharedStringMap: sharedStringMap)
            let path = "xl/worksheets/sheet\(sheet.id).xml"
            try addEntry(path, data: worksheetXML, to: archive)
        }
    }
    
    // MARK: - Excel XML Building
    
    private func buildWorkbookXML(sheets: [ExcelSheet]) -> Data {
        var sheetsXML = ""
        for sheet in sheets {
            let escapedName = escapeXMLAttribute(sheet.name)
            sheetsXML += """
            <sheet name="\(escapedName)" sheetId="\(sheet.id)" r:id="rId\(sheet.relationshipId)"/>
            """
        }
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            \(sheetsXML)
          </sheets>
        </workbook>
        """
        return Data(xml.utf8)
    }
    
    private func buildRootRelsXML() -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
        return Data(xml.utf8)
    }
    
    private func buildWorkbookRelsXML(sheets: [ExcelSheet]) -> Data {
        var relsXML = ""
        for sheet in sheets {
            relsXML += """
            <Relationship Id="rId\(sheet.relationshipId)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet\(sheet.id).xml"/>
            """
        }
        relsXML += """
        <Relationship Id="rId\(sheets.count + 1)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
        """
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          \(relsXML)
        </Relationships>
        """
        return Data(xml.utf8)
    }
    
    private func buildContentTypesXML(sheets: [ExcelSheet]) -> Data {
        var sheetsXML = ""
        for sheet in sheets {
            sheetsXML += """
            <Override PartName="/xl/worksheets/sheet\(sheet.id).xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
            """
        }
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
          \(sheetsXML)
        </Types>
        """
        return Data(xml.utf8)
    }
    
    
    private func buildWorksheetXML(sheet: ExcelSheet, sharedStringMap: [String: Int]) -> Data {
        var rowsXML = ""
        
        // Строим строки
        for (rowIndex, row) in sheet.rows.enumerated() {
            var cellsXML = ""
            for (colIndex, cell) in row.enumerated() {
                let cellRef = columnLetter(for: colIndex) + "\(rowIndex + 1)"
                let stringIndex = sharedStringMap[cell] ?? 0
                
                cellsXML += """
                <c r="\(cellRef)" t="s"><v>\(stringIndex)</v></c>
                """
            }
            
            rowsXML += """
            <row r="\(rowIndex + 1)">
              \(cellsXML)
            </row>
            """
        }
        
        // Column widths
        var colsXML = ""
        if let widths = sheet.columnWidths {
            for (index, width) in widths.enumerated() {
                colsXML += """
                <col min="\(index + 1)" max="\(index + 1)" width="\(Double(width))" customWidth="1"/>
                """
            }
        }
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <cols>
            \(colsXML)
          </cols>
          <sheetData>
            \(rowsXML)
          </sheetData>
        </worksheet>
        """
        return Data(xml.utf8)
    }
    
    // MARK: - PDF Building
    #if os(macOS)
    
    private func buildSummaryPDFPage(
        operations: [FinancialOperationEntity],
        config: FinancialExportConfig,
        pageNumber: Int
    ) throws -> PDFPage {
        let pageRect = NSRect(x: 0, y: 0, width: 612, height: 792) // A4 размер
        
        let sales = operations.filter { $0.type == .sale }
        let expenses = operations.filter { $0.type == .expense }
        let refunds = operations.filter { $0.type == .refund }
        
        let totalSales = sales.reduce(Decimal(0)) { $0 + $1.amount }
        let totalExpenses = expenses.reduce(Decimal(0)) { $0 + $1.amount }
        let totalRefunds = refunds.reduce(Decimal(0)) { $0 + $1.amount }
        
        let cashboxBalance = try financialOperationRepository.calculateCashBalance(account: .cashbox, upToDate: config.dateRange?.end)
        let kaspiBalance = try financialOperationRepository.calculateCashBalance(account: .kaspi, upToDate: config.dateRange?.end)
        
        let content = """
        ОБЗОР ФИНАНСОВЫХ ОПЕРАЦИЙ
        
        Период: \(config.dateRange != nil ? "\(dateFormatter.string(from: config.dateRange!.start)) - \(dateFormatter.string(from: config.dateRange!.end))" : "Все данные")
        
        ПРОДАЖИ
        Количество: \(sales.count)
        Сумма: \(formatCurrency(totalSales))
        
        РАСХОДЫ
        Количество: \(expenses.count)
        Сумма: \(formatCurrency(totalExpenses))
        
        ВОЗВРАТЫ
        Количество: \(refunds.count)
        Сумма: \(formatCurrency(totalRefunds))
        
        ЧИСТЫЙ РЕЗУЛЬТАТ: \(formatCurrency(totalSales - totalExpenses - totalRefunds))
        
        БАЛАНСЫ
        Касса: \(formatCurrency(cashboxBalance))
        Каспи: \(formatCurrency(kaspiBalance))
        
        Дата формирования: \(dateTimeFormatter.string(from: Date()))
        """
        
        // Создаём PDF страницу
        let pdfData = NSMutableData()
        let consumer = CGDataConsumer(data: pdfData as CFMutableData)!
        var mediaBox = pageRect
        let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
        
        context.beginPDFPage(nil)
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // Рисуем текст
        let attributedString = NSAttributedString(
            string: content,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.black
            ]
        )
        
        let textRect = NSRect(x: 50, y: 50, width: 512, height: 700)
        let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGPath(rect: textRect, transform: nil)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, attributedString.length), path, nil)
        
        context.textMatrix = .identity
        CTFrameDraw(frame, context)
        
        context.endPDFPage()
        context.closePDF()
        
        // Создаём PDFPage из данных
        let pdfDocument = PDFDocument(data: pdfData as Data)
        return pdfDocument!.page(at: 0)!
    }
    
    private func buildSalesPDFPages(operations: [FinancialOperationEntity], startPage: Int) throws -> [PDFPage] {
        var pages: [PDFPage] = []
        let pageRect = NSRect(x: 0, y: 0, width: 612, height: 792)
        
        // Заголовок
        var content = "ПРОДАЖИ\n\n"
        content += "Дата | Мотор | Цена | Способ оплаты | Счёт | Пользователь | Комментарий\n"
        content += String(repeating: "-", count: 100) + "\n"
        
        for operation in operations {
            let motorInfo = operation.relatedMotorID != nil ? "Мотор #\(operation.relatedMotorID!)" : "—"
            let paymentMethod = formatPaymentMethod(operation.paymentMethod)
            let account = operation.account == .cashbox ? "Касса" : "Каспи"
            
            content += "\(dateFormatter.string(from: operation.createdAt)) | \(motorInfo) | \(formatCurrency(operation.amount)) | \(paymentMethod) | \(account) | \(operation.createdByUser) | \(operation.comment)\n"
        }
        
        let total = operations.reduce(Decimal(0)) { $0 + $1.amount }
        content += "\nИТОГО: \(formatCurrency(total))"
        
        let page = try createPDFPage(content: content, pageRect: pageRect)
        pages.append(page)
        
        return pages
    }
    
    private func buildExpensesPDFPages(operations: [FinancialOperationEntity], startPage: Int) throws -> [PDFPage] {
        var pages: [PDFPage] = []
        let pageRect = NSRect(x: 0, y: 0, width: 612, height: 792)
        
        var content = "РАСХОДЫ\n\n"
        content += "Дата | Сумма | Счёт | Категория | Описание | Пользователь\n"
        content += String(repeating: "-", count: 100) + "\n"
        
        for operation in operations {
            let account = operation.account == .cashbox ? "Касса" : "Каспи"
            content += "\(dateFormatter.string(from: operation.createdAt)) | \(formatCurrency(operation.amount)) | \(account) | \(operation.category ?? "—") | \(operation.description) | \(operation.createdByUser)\n"
        }
        
        let total = operations.reduce(Decimal(0)) { $0 + $1.amount }
        content += "\nИТОГО: \(formatCurrency(total))"
        
        let page = try createPDFPage(content: content, pageRect: pageRect)
        pages.append(page)
        
        return pages
    }
    
    private func buildRefundsPDFPages(operations: [FinancialOperationEntity], startPage: Int) throws -> [PDFPage] {
        var pages: [PDFPage] = []
        let pageRect = NSRect(x: 0, y: 0, width: 612, height: 792)
        
        var content = "ВОЗВРАТЫ\n\n"
        content += "Дата | Мотор | Сумма | Способ оплаты | Счёт | Пользователь | Комментарий\n"
        content += String(repeating: "-", count: 100) + "\n"
        
        for operation in operations {
            let motorInfo = operation.relatedMotorID != nil ? "Мотор #\(operation.relatedMotorID!)" : "—"
            let paymentMethod = formatPaymentMethod(operation.paymentMethod)
            let account = operation.account == .cashbox ? "Касса" : "Каспи"
            
            content += "\(dateFormatter.string(from: operation.createdAt)) | \(motorInfo) | \(formatCurrency(operation.amount)) | \(paymentMethod) | \(account) | \(operation.createdByUser) | \(operation.comment)\n"
        }
        
        let total = operations.reduce(Decimal(0)) { $0 + $1.amount }
        content += "\nИТОГО: \(formatCurrency(total))"
        
        let page = try createPDFPage(content: content, pageRect: pageRect)
        pages.append(page)
        
        return pages
    }
    
    private func createPDFPage(content: String, pageRect: NSRect) throws -> PDFPage {
        let pdfData = NSMutableData()
        let consumer = CGDataConsumer(data: pdfData as CFMutableData)!
        var mediaBox = pageRect
        let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
        
        context.beginPDFPage(nil)
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        let attributedString = NSAttributedString(
            string: content,
            attributes: [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.black
            ]
        )
        
        let textRect = NSRect(x: 50, y: 50, width: 512, height: 700)
        let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGPath(rect: textRect, transform: nil)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, attributedString.length), path, nil)
        
        context.textMatrix = .identity
        CTFrameDraw(frame, context)
        
        context.endPDFPage()
        context.closePDF()
        
        let pdfDocument = PDFDocument(data: pdfData as Data)
        return pdfDocument!.page(at: 0)!
    }
    
    #endif
    
    // MARK: - Helpers
    
    private func formatCurrency(_ amount: Decimal) -> String {
        return currencyFormatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
    
    private func formatPaymentMethod(_ method: FinancialOperationEntity.PaymentMethod) -> String {
        switch method {
        case .cash: return "Наличные"
        case .transfer: return "Перевод"
        case .mixed: return "Смешанная"
        }
    }
    
    private func formatOperationType(_ type: FinancialOperationEntity.OperationType) -> String {
        switch type {
        case .sale: return "Продажа"
        case .income: return "Приход"
        case .refund: return "Возврат"
        case .expense: return "Расход"
        case .transfer: return "Перевод"
        }
    }
    
    private func columnLetter(for index: Int) -> String {
        var index = index
        var letters = ""
        repeat {
            let remainder = index % 26
            letters = String(UnicodeScalar(remainder + 65)!) + letters
            index = index / 26 - 1
        } while index >= 0
        return letters
    }
    
    private func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    private func escapeXMLAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    private func addEntry(_ path: String, data: Data, to archive: Archive) throws {
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: .deflate
        ) { position, size in
            data.subdata(in: Int(position)..<Int(position) + size)
        }
    }
}
