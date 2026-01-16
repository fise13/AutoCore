import Foundation
import ZIPFoundation

final class ExcelExportService {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
    
    // Максимальная длина имени листа в Excel
    private let maxSheetNameLength = 31
    
    struct ExportResult {
        let fileURL: URL
        let sheetsCount: Int
        let motorsCount: Int
        let soldMotorsCount: Int
        let specificSheetsCount: Int
    }
    
    /// Экспортирует все данные из БД в Excel файл
    /// 
    /// Структура файла:
    /// 1. Для каждого двигателя отдельный лист (BRAND_ENGINECODE) - ВСЕ автоматически
    /// 2. Лист "ПРОДАННЫЕ" со всеми проданными моторами
    /// 3. Специфичные листы из specific_records (только выбранные)
    ///
    /// - Parameters:
    ///   - database: Сервис базы данных
    ///   - url: URL для сохранения файла
    ///   - selectedSpecificSheetIDs: ID специфичных листов для экспорта (nil = все)
    /// - Returns: Результат экспорта со статистикой
    /// - Throws: ExportError если не удалось создать файл или нет данных
    func export(database: DatabaseService, to url: URL, selectedSpecificSheetIDs: Set<Int64>? = nil) throws -> ExportResult {
        // Загружаем все данные из БД
        let allMotors = try database.fetchMotors(filter: DatabaseService.MotorFilter(availability: .all), limit: nil, offset: 0)
        let engines = try database.fetchEngines(brandID: nil)
        let brands = try database.fetchBrands()
        
        // Проверяем, есть ли данные для экспорта
        if allMotors.isEmpty && engines.isEmpty {
            throw ExportError.noData
        }
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .create)
        } catch {
            throw ExportError.unableToCreateArchive
        }
        
        // Собираем данные для экспорта
        var sheets: [SheetData] = []
        var sheetId = 1
        var relationshipId = 1
        
        // 1. ЛИСТЫ ДЛЯ КАЖДОГО ДВИГАТЕЛЯ
        // Группируем моторы по двигателям
        let motorsByEngine = Dictionary(grouping: allMotors) { $0.engineID }
        
        // Сортируем двигатели для предсказуемости (по бренду, затем по коду)
        // Это гарантирует одинаковый порядок листов при каждом экспорте
        let sortedEngines = engines.sorted { engine1, engine2 in
            let brand1 = brands.first(where: { $0.id == engine1.brandID })?.name ?? ""
            let brand2 = brands.first(where: { $0.id == engine2.brandID })?.name ?? ""
            if brand1 != brand2 {
                return brand1 < brand2
            }
            return engine1.code < engine2.code
        }
        
        for engine in sortedEngines {
            guard let motors = motorsByEngine[engine.id], !motors.isEmpty else { continue }
            
            let brand = brands.first(where: { $0.id == engine.brandID })
            // Имя листа: BRAND_ENGINECODE (например: SUBARU_EJ253)
            let sheetName = makeSheetName(brand: brand?.name ?? "", engineCode: engine.code)
            
            // Стандартные колонки для всех листов двигателей
            let headers = [
                "НОМЕР ДВИГАТЕЛЯ",
                "КОМПЛЕКТАЦИЯ",
                "ОСОБЫЕ ОТМЕТКИ",
                "КОЛ-ВО",
                "КОРОБКА",
                "ДАТА ПРИХОДА",
                "ДАТА ПРОДАЖИ"
            ]
            
            // Сортируем моторы по дате прихода (новые сверху)
            // В листе присутствуют ВСЕ моторы этого двигателя (и проданные, и в наличии)
            let sortedMotors = motors.sorted { motor1, motor2 in
                motor1.arrivalDate > motor2.arrivalDate
            }
            
            let rows = [headers] + sortedMotors.map { motorRow($0) }
            
            sheets.append(SheetData(
                id: sheetId,
                relationshipId: relationshipId,
                name: sheetName,
                rows: rows
            ))
            
            sheetId += 1
            relationshipId += 1
        }
        
        // 2. ЛИСТ "ПРОДАННЫЕ"
        // Содержит ТОЛЬКО моторы, у которых sold_date != null
        let soldMotors = allMotors.filter { $0.soldDate != nil }
            .sorted { motor1, motor2 in
                guard let date1 = motor1.soldDate, let date2 = motor2.soldDate else { return false }
                return date1 > date2 // Отсортировано по ДАТЕ ПРОДАЖИ (новые сверху)
            }
        
        if !soldMotors.isEmpty {
            // Колонки включают БРЕНД и ДВИГАТЕЛЬ для удобства
            let soldHeaders = [
                "БРЕНД",
                "ДВИГАТЕЛЬ",
                "НОМЕР ДВИГАТЕЛЯ",
                "КОМПЛЕКТАЦИЯ",
                "ОСОБЫЕ ОТМЕТКИ",
                "КОЛ-ВО",
                "КОРОБКА",
                "ДАТА ПРИХОДА",
                "ДАТА ПРОДАЖИ"
            ]
            
            let soldRows = [soldHeaders] + soldMotors.map { soldMotorRow($0) }
            
            sheets.append(SheetData(
                id: sheetId,
                relationshipId: relationshipId,
                name: "ПРОДАННЫЕ",
                rows: soldRows
            ))
            
            sheetId += 1
            relationshipId += 1
        }
        
        // 3. СПЕЦИФИЧНЫЕ ЛИСТЫ
        // Каждый специфичный лист экспортируется отдельно
        // Структура колонок формируется динамически из тех полей, которые пользователь задал при импорте
        // Экспортируются только выбранные пользователем листы
        let allSpecificSheets = try database.fetchAllSpecificSheets()
        let specificSheetsToExport: [DatabaseService.SpecificSheet]
        
        if let selectedIDs = selectedSpecificSheetIDs {
            // Экспортируем только выбранные
            specificSheetsToExport = allSpecificSheets.filter { selectedIDs.contains($0.id) }
        } else {
            // Экспортируем все (для обратной совместимости)
            specificSheetsToExport = allSpecificSheets
        }
        
        let specificSheetsData = try fetchSpecificSheets(database: database, sheetIDs: Set(specificSheetsToExport.map { $0.id }))
        for specificSheet in specificSheetsData {
            // Имя листа = имя категории (например: РЕМОНТ, ПОСЛЕ ДЭНА)
            let sheetName = makeSheetName(name: specificSheet.name)
            let rows = specificSheet.rows
            
            // Пропускаем пустые листы
            if !rows.isEmpty {
                sheets.append(SheetData(
                    id: sheetId,
                    relationshipId: relationshipId,
                    name: sheetName,
                    rows: rows
                ))
                
                sheetId += 1
                relationshipId += 1
            }
        }
        
        // Создаем Excel файл
        try buildExcelFile(sheets: sheets, archive: archive)
        
        return ExportResult(
            fileURL: url,
            sheetsCount: sheets.count,
            motorsCount: allMotors.count,
            soldMotorsCount: soldMotors.count,
            specificSheetsCount: specificSheetsData.count
        )
    }
    
    // MARK: - Data Structures
    
    private struct SheetData {
        let id: Int
        let relationshipId: Int
        let name: String
        let rows: [[String]]
    }
    
    private struct SpecificSheetData {
        let name: String
        let rows: [[String]]
    }
    
    // MARK: - Sheet Name Generation
    
    /// Создает имя листа для двигателя в формате BRAND_ENGINECODE
    /// Пример: SUBARU_EJ253, TOYOTA_2AZFE
    private func makeSheetName(brand: String, engineCode: String) -> String {
        let brandUpper = brand.uppercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let engineUpper = engineCode.uppercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // Убираем недопустимые символы для имени листа Excel
        let cleanBrand = brandUpper.replacingOccurrences(of: "[/\\?*\\[\\]:]", with: "", options: .regularExpression)
        let cleanEngine = engineUpper.replacingOccurrences(of: "[/\\?*\\[\\]:]", with: "", options: .regularExpression)
        
        let name = "\(cleanBrand)_\(cleanEngine)"
        return truncateSheetName(name)
    }
    
    /// Создает имя листа для специфичных данных
    /// Обрезает до 31 символа (ограничение Excel)
    private func makeSheetName(name: String) -> String {
        let upper = name.uppercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        // Убираем недопустимые символы
        let clean = upper.replacingOccurrences(of: "[/\\?*\\[\\]:]", with: "", options: .regularExpression)
        return truncateSheetName(clean)
    }
    
    /// Обрезает имя листа до максимальной длины (31 символ для Excel)
    private func truncateSheetName(_ name: String) -> String {
        if name.count <= maxSheetNameLength {
            return name.isEmpty ? "ЛИСТ" : name
        }
        // Обрезаем до 31 символа
        let truncated = String(name.prefix(maxSheetNameLength))
        return truncated.isEmpty ? "ЛИСТ" : truncated
    }
    
    // MARK: - Row Builders
    
    /// Создает строку для мотора в листе двигателя
    /// Пустые значения остаются пустыми (не "N/A")
    private func motorRow(_ motor: Motor) -> [String] {
        [
            motor.serialCode,
            motor.configuration.isEmpty ? "" : motor.configuration,
            motor.notes.isEmpty ? "" : motor.notes,
            "\(motor.quantity)",
            motor.transmission.isEmpty ? "" : motor.transmission,
            formatDate(motor.arrivalDate),
            formatDate(motor.soldDate)
        ]
    }
    
    /// Создает строку для проданного мотора в листе "ПРОДАННЫЕ"
    /// Включает бренд и код двигателя для удобства
    private func soldMotorRow(_ motor: Motor) -> [String] {
        [
            motor.brandName,
            motor.engineCode,
            motor.serialCode,
            motor.configuration.isEmpty ? "" : motor.configuration,
            motor.notes.isEmpty ? "" : motor.notes,
            "\(motor.quantity)",
            motor.transmission.isEmpty ? "" : motor.transmission,
            formatDate(motor.arrivalDate),
            formatDate(motor.soldDate)
        ]
    }
    
    /// Форматирует дату в локальном формате (dd.MM.yyyy)
    /// Пустые значения остаются пустыми
    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return dateFormatter.string(from: date)
    }
    
    // MARK: - Specific Sheets
    
    private func fetchSpecificSheets(database: DatabaseService, sheetIDs: Set<Int64>? = nil) throws -> [SpecificSheetData] {
        // Получаем специфичные листы (все или только выбранные)
        let allSheets = try database.fetchAllSpecificSheets()
        let sheets: [DatabaseService.SpecificSheet]
        if let sheetIDs = sheetIDs {
            sheets = allSheets.filter { sheetIDs.contains($0.id) }
        } else {
            sheets = allSheets
        }
        
        var result: [SpecificSheetData] = []
        
        for sheet in sheets {
            let records = try database.fetchSpecificRecords(sheetID: sheet.id)
            
            if records.isEmpty {
                continue
            }
            
            // Определяем все уникальные ключи из всех записей
            var allKeys: [String] = []
            var keysSet = Set<String>()
            
            for record in records {
                for key in record.data.keys {
                    if !keysSet.contains(key) {
                        keysSet.insert(key)
                        allKeys.append(key)
                    }
                }
            }
            
            // Сортируем ключи для предсказуемости (порядок колонок сохраняется)
            allKeys.sort()
            
            // Строим строки
            var rows: [[String]] = []
            
            // Заголовки
            rows.append(allKeys)
            
            // Данные (уже отсортированы по rowIndex в запросе из БД)
            // Порядок колонок сохраняется (отсортированы по имени ключа)
            for record in records {
                var row: [String] = []
                for key in allKeys {
                    // Пустые значения остаются пустыми (не "N/A")
                    let value = record.data[key] ?? ""
                    row.append(value)
                }
                rows.append(row)
            }
            
            result.append(SpecificSheetData(name: sheet.name, rows: rows))
        }
        
        return result
    }
    
    // MARK: - Excel Building
    
    private func buildExcelFile(sheets: [SheetData], archive: Archive) throws {
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
        
        // 5. Worksheets
        for sheet in sheets {
            let worksheetXML = buildWorksheetXML(rows: sheet.rows)
            let path = "xl/worksheets/sheet\(sheet.id).xml"
            try addEntry(path, data: worksheetXML, to: archive)
        }
    }
    
    private func buildWorkbookXML(sheets: [SheetData]) -> Data {
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
    
    private func buildWorkbookRelsXML(sheets: [SheetData]) -> Data {
        var relationships = ""
        for sheet in sheets {
            relationships += """
            <Relationship Id="rId\(sheet.relationshipId)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet\(sheet.id).xml"/>
            """
        }
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          \(relationships)
        </Relationships>
        """
        return Data(xml.utf8)
    }
    
    private func buildContentTypesXML(sheets: [SheetData]) -> Data {
        var overrides = """
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        """
        
        for sheet in sheets {
            overrides += """
            <Override PartName="/xl/worksheets/sheet\(sheet.id).xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
            """
        }
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          \(overrides)
        </Types>
        """
        return Data(xml.utf8)
    }
    
    private func buildWorksheetXML(rows: [[String]]) -> Data {
        var rowXML: [String] = []
        for (rowIndex, row) in rows.enumerated() {
            var cellXML: [String] = []
            for (colIndex, value) in row.enumerated() {
                let column = columnLetter(for: colIndex)
                let ref = "\(column)\(rowIndex + 1)"
                let escaped = escapeXML(value)
                let cell = """
                <c r="\(ref)" t="inlineStr"><is><t>\(escaped)</t></is></c>
                """
                cellXML.append(cell)
            }
            rowXML.append("<row r=\"\(rowIndex + 1)\">\(cellXML.joined())</row>")
        }
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            \(rowXML.joined())
          </sheetData>
        </worksheet>
        """
        return Data(xml.utf8)
    }
    
    // MARK: - Helpers
    
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
        // Для атрибутов XML нужно экранировать кавычки и амперсанды
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

// MARK: - Errors

enum ExportError: LocalizedError {
    case unableToCreateArchive
    case noData
    
    var errorDescription: String? {
        switch self {
        case .unableToCreateArchive:
            return "Не удалось создать архив Excel"
        case .noData:
            return "Нет данных для экспорта"
        }
    }
}
