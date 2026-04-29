import Foundation
import SwiftUI
import Combine

enum ImportWizardStep: Int, CaseIterable {
    case analyze = 1
    case selectType = 2 // Выбор типа листа (основной/специфичный/пропустить)
    case preview = 3 // Preview и импорт (колонки определяются автоматически)
}

@MainActor
final class ImportViewModel: ObservableObject {
    @Published var currentStep: ImportWizardStep = .analyze
    @Published var sheetConfigs: [SheetImportConfig] = []
    @Published var columnMappings: [UUID: SheetColumnMapping] = [:] // Маппинг колонок для каждого листа
    @Published var isLoading = false
    @Published var isImporting = false
    @Published var importProgress: (current: Int, total: Int)?
    @Published var errorMessage: String?
    @Published var existingBrands: [Brand] = []
    /// Статус/подсказка по сопоставлению листов через OpenRouter (только API, без Vision).
    @Published var aiMappingNotes: String?
    @Published var isAIMapping = false

    // Текущий лист, для которого настраиваются колонки
    @Published var currentSheetConfigID: UUID?

    let database: DatabaseService
    /// Текущая компания для привязки импортируемых моторов.
    var companyId: String = "default"
    private let importService = ExcelImportService()
    private let importAIMapping = ImportOpenRouterMappingService()
    private var rawSheetData: [ImportSheetData] = []
    
    init(database: DatabaseService, companyId: String = "default") {
        self.database = database
        self.companyId = companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "default" : companyId
    }
    
    func load(url: URL) {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            aiMappingNotes = nil
        }
        
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                guard let self else { return }
                let needsAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if needsAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                let data = try self.importService.loadSheets(from: url)
                await MainActor.run { [weak self] in
                    self?.apply(sheets: data)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка импорта Excel: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func loadExistingBrands() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let brands = try self.database.fetchBrands()
                await MainActor.run { [weak self] in
                    self?.updateBrands(brands)
                }
            } catch {
                // Ignore
            }
        }
    }
    
    @MainActor
    private func apply(sheets: [ImportSheetData]) {
        rawSheetData = sheets
        // По умолчанию все листы считаются основными (engines)
        // Автоматически угадываем бренд и код двигателя из названия
        sheetConfigs = sheets.map { sheet in
            SheetImportConfig(
                sheetName: sheet.name,
                rowCount: sheet.rows.count,
                previewRows: Array(sheet.rows.prefix(3))
            )
        }
        // Инициализируем маппинг колонок для каждого листа с автоматическим определением
        for config in sheetConfigs {
            if let sheet = rawSheetData.first(where: { $0.name == config.sheetName }) {
                columnMappings[config.id] = createAutoColumnMapping(for: sheet, sheetID: config.id, importType: config.importType)
            }
        }
        isLoading = false
        loadExistingBrands()
        Task { await runImportAIMapping() }
    }

    /// Сопоставление листов, брендов/двигателей и колонок (в т.ч. «Проданные» → sold_date) через тот же API, что и OpenAI/OpenRouter.
    @MainActor
    private func runImportAIMapping() async {
        let key = OpenRouterKeyProvider.resolved
        guard !key.isEmpty else {
            aiMappingNotes = """
            AI-сопоставление: нет ключа API.

            Как задать:
            • Среда запуска в Xcode: переменные OPENROUTER_API_KEY (или OPENAI_API_KEY), опционально OPENROUTER_BASE_URL, OPENROUTER_MODEL.
            • Локально: `defaults write fise.AutoCore OPENROUTER_API_KEY 'ваш_ключ'`, полностью закройте и откройте приложение.
            """
            return
        }
        isAIMapping = true
        aiMappingNotes = "AI: сопоставление с каталогом (API)…"
        defer { isAIMapping = false }
        do {
            let brands = try database.fetchBrands()
            var engines: [Engine] = []
            var brandNameById: [Int64: String] = [:]
            for b in brands {
                brandNameById[b.id] = b.name
                engines.append(contentsOf: (try? database.fetchEngines(brandID: b.id)) ?? [])
            }
            let payloads: [ImportSheetAIPayload] = rawSheetData.map { sheet in
                let sample = Array(sheet.rows.prefix(8)).map { row in
                    row.prefix(10).map { String($0.prefix(50)) }
                }
                return ImportSheetAIPayload(name: sheet.name, rowCount: sheet.rows.count, sampleRows: sample)
            }
            let result = try await importAIMapping.resolve(
                sheetPayloads: payloads,
                brands: brands,
                engines: engines,
                brandNameById: brandNameById
            )
            applyAIResolution(result, brands: brands)
            aiMappingNotes = result.notes.map { "AI: \($0)" } ?? "AI: сопоставление применено. Проверьте типы листов и колонки на следующем шаге."
        } catch {
            aiMappingNotes = formatImportAIErrorForUI(error)
        }
    }

    /// Подробное сообщение для панели мастера импорта.
    private func formatImportAIErrorForUI(_ error: Error) -> String {
        if let ie = error as? ImportAIError, let d = ie.errorDescription {
            return "AI: ошибка сопоставления\n\n" + d
        }
        let ns = error as NSError
        var parts: [String] = [error.localizedDescription]
        if let sub = ns.userInfo[NSLocalizedFailureReasonErrorKey] as? String, !sub.isEmpty {
            parts.append("Причина: " + sub)
        }
        if let det = ns.userInfo[NSDebugDescriptionErrorKey] as? String, !det.isEmpty {
            parts.append("Деталь: " + det)
        }
        if let ur = error as? URLError {
            parts.append("Сеть: код \(ur.errorCode), \(ur.localizedDescription)")
        }
        return "AI: ошибка\n\n" + parts.joined(separator: "\n\n")
    }

    @MainActor
    private func applyAIResolution(_ r: ImportAIResolution, brands: [Brand]) {
        var lowConfidenceSheets: [String] = []
        for d in r.sheets {
            guard let idx = indexOfConfig(matchingSheetName: d.sheet_name) else { continue }
            var c = sheetConfigs[idx]
            let confidence = d.confidence ?? 1.0
            if confidence < 0.6 {
                lowConfidenceSheets.append(c.sheetName)
            }
            switch d.import_type.lowercased() {
            case "engines":  c.importType = .engines
            case "specific": c.importType = .specific
            case "skip":     c.importType = .skip
            default:         break
            }
            if c.importType == .specific, let cat = d.category_name?.trimmingCharacters(in: .whitespacesAndNewlines), !cat.isEmpty {
                c.categoryName = cat
            }
            if c.importType == .engines {
                if let bn = d.brand_name?.trimmingCharacters(in: .whitespacesAndNewlines), !bn.isEmpty {
                    if let b = brands.first(where: { $0.name.caseInsensitiveCompare(bn) == .orderedSame }) {
                        c.selectedBrandID = b.id
                        c.customBrand = ""
                    } else {
                        c.selectedBrandID = nil
                        c.customBrand = bn
                    }
                }
                if let ec = d.engine_code?.trimmingCharacters(in: .whitespacesAndNewlines), !ec.isEmpty {
                    c.customEngineCode = ImportNormalization.normalizeEngineCode(ec)
                }
            }
            sheetConfigs[idx] = c

            guard let sheet = rawSheetData.first(where: { $0.name == c.sheetName }) else { continue }
            var mapping = createAutoColumnMapping(for: sheet, sheetID: c.id, importType: c.importType)
            if c.importType == .engines, let roles = d.column_roles {
                applyAIRoles(roles, to: &mapping)
            }
            if c.importType == .engines {
                ensureSoldDateMapping(
                    for: sheet,
                    mapping: &mapping,
                    fallbackDateColumns: d.fallback_date_columns,
                    soldSheetHint: d.detected_sold_sheet ?? isLikelySoldSheetName(c.sheetName)
                )
            }
            columnMappings[c.id] = mapping
        }
        if !lowConfidenceSheets.isEmpty {
            let joined = lowConfidenceSheets.joined(separator: ", ")
            let warning = "\nAI: Низкая уверенность по листам: \(joined)."
            aiMappingNotes = (aiMappingNotes ?? "") + warning
        }
    }

    private func indexOfConfig(matchingSheetName name: String) -> Int? {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = sheetConfigs.firstIndex(where: { $0.sheetName == t }) { return i }
        return sheetConfigs.firstIndex { $0.sheetName.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(t) == .orderedSame }
    }

    private func applyAIRoles(_ roles: [String: String], to mapping: inout SheetColumnMapping) {
        for (key, roleRaw) in roles {
            guard let col = Int(key), let field = engineFieldFromAIRole(roleRaw) else { continue }
            guard let i = mapping.columnMappings.firstIndex(where: { $0.columnIndex == col }) else { continue }
            mapping.columnMappings[i].engineFieldMapping = field
            if field != .ignore {
                mapping.columnMappings[i].customFieldName = nil
            }
        }
    }

    private func engineFieldFromAIRole(_ raw: String) -> EngineFieldMapping? {
        let r = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch r {
        case "serial", "serial_code", "number", "vin", "мотор", "серий", "двигатель":
            return .serialCode
        case "configuration", "комплектация", "комплект":
            return .configuration
        case "notes", "примеч", "замет", "отмет":
            return .notes
        case "quantity", "qty", "кол", "шт", "кол-во":
            return .quantity
        case "transmission", "кпп", "короб", "трансмис":
            return .transmission
        case "arrival", "arrival_date", "приход", "поступ":
            return .arrivalDate
        case "sold", "sold_date", "продаж", "дата_продаж", "date_sold", "цена", "price", "сумма":
            // Проданные: даты и деньги в одном и том же import engines — дата в soldDate; сумму часто суют в notes, если нет поля
            if r == "цена" || r == "price" || r == "сумма" {
                return .notes
            }
            return .soldDate
        case "ignore", "none", "skip", "":
            return .ignore
        default:
            if r.contains("sold") || r.contains("продаж") { return .soldDate }
            if r.contains("приход") { return .arrivalDate }
            if r.contains("серий") || r == "№" { return .serialCode }
            return nil
        }
    }

    private func ensureSoldDateMapping(
        for sheet: ImportSheetData,
        mapping: inout SheetColumnMapping,
        fallbackDateColumns: [Int]?,
        soldSheetHint: Bool
    ) {
        guard soldSheetHint else { return }
        if mapping.columnMappings.contains(where: { $0.engineFieldMapping == .soldDate }) {
            return
        }
        if let preferred = fallbackDateColumns {
            for index in preferred {
                guard let mappingIndex = mapping.columnMappings.firstIndex(where: { $0.columnIndex == index }) else { continue }
                let candidate = mapping.columnMappings[mappingIndex]
                if hasDateLikePreview(candidate.previewValues) {
                    mapping.columnMappings[mappingIndex].engineFieldMapping = .soldDate
                    return
                }
            }
        }
        if let fallbackIndex = detectFallbackSoldDateColumn(in: mapping) {
            mapping.columnMappings[fallbackIndex].engineFieldMapping = .soldDate
        }
    }

    private func detectFallbackSoldDateColumn(in mapping: SheetColumnMapping) -> Int? {
        let preferredWords = ["продаж", "sold", "sale", "дата", "date", "реализ"]
        for (index, column) in mapping.columnMappings.enumerated() {
            guard column.engineFieldMapping == nil || column.engineFieldMapping == .ignore else { continue }
            let header = ImportNormalization.normalizeHeader(column.headerValue ?? "")
            if preferredWords.contains(where: { header.contains($0) }) && hasDateLikePreview(column.previewValues) {
                return index
            }
        }
        return mapping.columnMappings.firstIndex(where: { column in
            (column.engineFieldMapping == nil || column.engineFieldMapping == .ignore) &&
            hasDateLikePreview(column.previewValues)
        })
    }

    private func hasDateLikePreview(_ values: [String]) -> Bool {
        guard !values.isEmpty else { return false }
        var matches = 0
        for v in values.prefix(5) {
            let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { continue }
            if ImportNormalization.parseDateString(t) != nil {
                matches += 1
                continue
            }
            if let n = Double(t), ImportNormalization.dateFromExcelSerial(n) != nil {
                matches += 1
            }
        }
        return matches >= 1
    }

    private func isLikelySoldSheetName(_ name: String) -> Bool {
        let n = ImportNormalization.normalizeHeader(name)
        return n.contains("продан") || n.contains("продажи") || n.contains("sold") || n.contains("sales")
    }
    
    // Создает автоматический маппинг колонок на основе заголовков
    private func createAutoColumnMapping(for sheet: ImportSheetData, sheetID: UUID, importType: SheetImportType) -> SheetColumnMapping {
        let maxColumn = sheet.rows.map { $0.count }.max() ?? 0
        var columnMappings: [ColumnMapping] = []
        
        // Пытаемся найти строку с заголовками (первая непустая строка)
        var headerRowIndex: Int? = nil
        var headerRow: [String]? = nil
        
        for (index, row) in sheet.rows.prefix(10).enumerated() {
            let nonEmptyCount = row.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            if nonEmptyCount >= 2 {
                headerRowIndex = index
                headerRow = row
                break
            }
        }
        
        // Создаем маппинг для каждой колонки с автоматическим определением
        for columnIndex in 0..<maxColumn {
            let letter = columnLetter(for: columnIndex)
            let headerValue = headerRow?.indices.contains(columnIndex) == true ? headerRow?[columnIndex] : nil
            let trimmedHeader = (headerValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").uppercased()
            
            // Берем preview значений
            let dataStartIndex = (headerRowIndex ?? -1) + 1
            let previewValues = sheet.rows
                .suffix(from: dataStartIndex)
                .prefix(5)
                .compactMap { row -> String? in
                    guard row.indices.contains(columnIndex) else { return nil }
                    let value = row[columnIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? nil : value
                }
            
            // Автоматическое определение для основных листов
            var engineFieldMapping: EngineFieldMapping? = nil
            var customFieldName: String? = nil
            
            if importType == .engines {
                engineFieldMapping = detectEngineField(from: trimmedHeader)
            } else if importType == .specific {
                // Для специфичных листов используем заголовок как имя поля
                if !trimmedHeader.isEmpty {
                    customFieldName = headerValue?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            columnMappings.append(ColumnMapping(
                columnIndex: columnIndex,
                columnLetter: letter,
                headerValue: headerValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                previewValues: previewValues,
                engineFieldMapping: engineFieldMapping,
                customFieldName: customFieldName
            ))
        }
        
        return SheetColumnMapping(
            sheetID: sheetID,
            columnMappings: columnMappings,
            headerRowIndex: headerRowIndex
        )
    }
    
    // Автоматическое определение поля двигателя по заголовку
    private func detectEngineField(from header: String) -> EngineFieldMapping? {
        let normalized = header.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Номер двигателя
        if normalized.contains("НОМЕР") && (normalized.contains("ДВИГАТЕЛ") || normalized.contains("МОТОР")) {
            return .serialCode
        }
        if normalized == "НОМЕР" || normalized == "SERIAL" || normalized == "№" {
            return .serialCode
        }
        
        // Комплектация
        if normalized.contains("КОМПЛЕКТ") || normalized.contains("КОМПЛЕКС") {
            return .configuration
        }
        if normalized == "КОМПЛЕКТАЦИЯ" {
            return .configuration
        }
        
        // Особые отметки
        if normalized.contains("ОСОБ") || normalized.contains("ОТМЕТ") || normalized.contains("ПРИМЕЧ") {
            return .notes
        }
        if normalized == "ЗАМЕТКИ" || normalized == "NOTES" || normalized == "КОММЕНТ" {
            return .notes
        }
        
        // Количество
        if normalized.contains("КОЛ") || normalized.contains("КОЛИЧ") || normalized == "QTY" || normalized == "QUANTITY" {
            return .quantity
        }
        
        // Коробка
        if normalized.contains("КОРОБ") || normalized.contains("КПП") || normalized.contains("ТРАНСМИСС") {
            return .transmission
        }
        if normalized == "GEARBOX" || normalized == "TRANSMISSION" {
            return .transmission
        }
        
        // Дата прихода
        if normalized.contains("ПРИХОД") || normalized.contains("ПОСТУП") || normalized.contains("ARRIVAL") {
            return .arrivalDate
        }
        if normalized.contains("ДАТА") && (normalized.contains("ПРИХОД") || normalized.contains("ПОСТУП")) {
            return .arrivalDate
        }
        
        // Дата продажи
        if normalized.contains("ПРОДАЖ") || normalized.contains("SOLD") {
            return .soldDate
        }
        if normalized.contains("ДАТА") && normalized.contains("ПРОДАЖ") {
            return .soldDate
        }
        
        return nil
    }
    
    // Старая функция для обратной совместимости (не используется)
    private func createInitialColumnMapping(for sheet: ImportSheetData, sheetID: UUID) -> SheetColumnMapping {
        let maxColumn = sheet.rows.map { $0.count }.max() ?? 0
        var columnMappings: [ColumnMapping] = []
        
        // Пытаемся найти строку с заголовками (первая непустая строка)
        var headerRowIndex: Int? = nil
        var headerRow: [String]? = nil
        
        for (index, row) in sheet.rows.prefix(10).enumerated() {
            let nonEmptyCount = row.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            if nonEmptyCount >= 2 { // Если в строке хотя бы 2 непустых ячейки
                headerRowIndex = index
                headerRow = row
                break
            }
        }
        
        // Создаем маппинг для каждой колонки
        for columnIndex in 0..<maxColumn {
            let letter = columnLetter(for: columnIndex)
            let headerValue = headerRow?.indices.contains(columnIndex) == true ? headerRow?[columnIndex] : nil
            let trimmedHeader = headerValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Берем preview значений из первых строк данных (после заголовка, если есть)
            let dataStartIndex = (headerRowIndex ?? -1) + 1
            let previewValues = sheet.rows
                .suffix(from: dataStartIndex)
                .prefix(5)
                .compactMap { row -> String? in
                    guard row.indices.contains(columnIndex) else { return nil }
                    let value = row[columnIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? nil : value
                }
            
            columnMappings.append(ColumnMapping(
                columnIndex: columnIndex,
                columnLetter: letter,
                headerValue: trimmedHeader.isEmpty ? nil : trimmedHeader,
                previewValues: previewValues,
                engineFieldMapping: nil,
                customFieldName: nil
            ))
        }
        
        return SheetColumnMapping(
            sheetID: sheetID,
            columnMappings: columnMappings,
            headerRowIndex: headerRowIndex
        )
    }
    
    func updateColumnMapping(for sheetID: UUID, mapping: SheetColumnMapping) {
        columnMappings[sheetID] = mapping
    }
    
    // Обновляет маппинг колонок при смене типа листа
    func updateColumnMappingForTypeChange(sheetID: UUID, importType: SheetImportType) {
        guard let config = sheetConfigs.first(where: { $0.id == sheetID }),
              let sheet = rawSheetData.first(where: { $0.name == config.sheetName }) else { return }
        
        columnMappings[sheetID] = createAutoColumnMapping(for: sheet, sheetID: sheetID, importType: importType)
    }
    
    func updateSheetConfig(_ config: SheetImportConfig) {
        guard let index = sheetConfigs.firstIndex(where: { $0.id == config.id }) else { return }
        sheetConfigs[index] = config
    }
    
    func canProceedToNextStep() -> Bool {
        switch currentStep {
        case .analyze:
            return !sheetConfigs.isEmpty && !isAIMapping
        case .selectType:
            // Все листы должны иметь выбранный тип
            // Для специфичных листов должна быть задана категория
            // Для основных листов должны быть заданы бренд и код двигателя
            return sheetConfigs.allSatisfy { config in
                if config.importType == .skip {
                    return true
                }
                if config.importType == .specific {
                    return config.isConfigured
                }
                if config.importType == .engines {
                    // Проверяем, что бренд и код двигателя заданы
                    // И что есть маппинг с serial_code
                    guard let mapping = columnMappings[config.id] else { return false }
                    return config.isConfigured && mapping.isValidForEngines()
                }
                return config.importType != .skip
            }
        case .preview:
            return true
        }
    }
    
    func nextStep() {
        guard canProceedToNextStep() else { return }
        guard let next = ImportWizardStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
        
        // При смене типа листа обновляем автоматический маппинг колонок
        if currentStep == .selectType {
            for config in sheetConfigs {
                if let sheet = rawSheetData.first(where: { $0.name == config.sheetName }) {
                    columnMappings[config.id] = createAutoColumnMapping(for: sheet, sheetID: config.id, importType: config.importType)
                }
            }
        }
    }
    
    func previousStep() {
        guard let prev = ImportWizardStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }
    
    func getCurrentSheetConfig() -> SheetImportConfig? {
        guard let id = currentSheetConfigID else { return nil }
        return sheetConfigs.first(where: { $0.id == id })
    }
    
    func getNextSheetToConfigure() -> SheetImportConfig? {
        guard let currentID = currentSheetConfigID else {
            return sheetConfigs.filter { $0.importType != .skip }.first
        }
        let sheetsToConfigure = sheetConfigs.filter { $0.importType != .skip }
        guard let currentIndex = sheetsToConfigure.firstIndex(where: { $0.id == currentID }) else {
            return sheetsToConfigure.first
        }
        let nextIndex = currentIndex + 1
        if nextIndex < sheetsToConfigure.count {
            return sheetsToConfigure[nextIndex]
        }
        return nil
    }
    
    func moveToNextSheet() {
        if let next = getNextSheetToConfigure() {
            currentSheetConfigID = next.id
        } else {
            // Все листы настроены, переходим к preview
            nextStep()
        }
    }
    
    func getSheetData(for config: SheetImportConfig) -> ImportSheetData? {
        return rawSheetData.first(where: { $0.name == config.sheetName })
    }
    
    func buildPreviewSummary() -> ImportPreviewSummary {
        var newBrands: Set<String> = []
        var newEnginesSet: Set<String> = [] // Используем строку для уникальности
        var newEnginesList: [(brand: String, code: String)] = []
        var totalMotors = 0
        var skippedSheets: [String] = []
        var specificSheets: [(name: String, categoryName: String)] = []
        
        for config in sheetConfigs {
            switch config.importType {
            case .skip:
                skippedSheets.append(config.sheetName)
            case .engines:
                if let brand = config.effectiveBrand {
                    newBrands.insert(brand)
                }
                if let engineCode = config.effectiveEngineCode, let brand = config.effectiveBrand {
                    let key = "\(brand)|\(engineCode)"
                    if !newEnginesSet.contains(key) {
                        newEnginesSet.insert(key)
                        newEnginesList.append((brand: brand, code: engineCode))
                    }
                }
                if let sheet = getSheetData(for: config),
                   let mapping = columnMappings[config.id] {
                    let rows = buildEngineRows(for: sheet, mapping: mapping)
                    totalMotors += rows.count
                }
            case .specific:
                specificSheets.append((name: config.sheetName, categoryName: config.categoryName))
            }
        }
        
        return ImportPreviewSummary(
            totalMotors: totalMotors,
            newBrands: Array(newBrands).sorted(),
            newEngines: newEnginesList.sorted(by: { $0.brand < $1.brand || ($0.brand == $1.brand && $0.code < $1.code) }),
            skippedSheets: skippedSheets,
            specificSheets: specificSheets
        )
    }
    
    // Строит строки для основных листов на основе маппинга
    func buildEngineRows(for sheet: ImportSheetData, mapping: SheetColumnMapping) -> [ImportRow] {
        guard let serialMapping = mapping.columnMappings.first(where: { $0.engineFieldMapping == .serialCode }) else {
            return []
        }
        let soldSheetHint = isLikelySoldSheetName(sheet.name)
        let soldDateColumn = mapping.columnMappings.first(where: { $0.engineFieldMapping == .soldDate })?.columnIndex
        let arrivalDateColumn = mapping.columnMappings.first(where: { $0.engineFieldMapping == .arrivalDate })?.columnIndex
        let fallbackSoldColumn: Int? = {
            if soldDateColumn != nil { return nil }
            guard soldSheetHint else { return nil }
            guard let idx = detectFallbackSoldDateColumn(in: mapping) else { return nil }
            return mapping.columnMappings[idx].columnIndex
        }()
        
        let dataStartIndex = (mapping.headerRowIndex ?? -1) + 1
        var rows: [ImportRow] = []
        
        for (rowIndex, row) in sheet.rows.enumerated() {
            if rowIndex < dataStartIndex { continue }
            
            let serialCode = getStringValue(from: row, at: serialMapping.columnIndex)
            if serialCode.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let configuration = getOptionalStringValue(from: row, at: mapping.columnMappings.first(where: { $0.engineFieldMapping == .configuration })?.columnIndex)
            let notes = getOptionalStringValue(from: row, at: mapping.columnMappings.first(where: { $0.engineFieldMapping == .notes })?.columnIndex)
            let quantity = getOptionalStringValue(from: row, at: mapping.columnMappings.first(where: { $0.engineFieldMapping == .quantity })?.columnIndex)
            let transmission = getOptionalStringValue(from: row, at: mapping.columnMappings.first(where: { $0.engineFieldMapping == .transmission })?.columnIndex)
            let arrivalDateRaw = getOptionalStringValue(from: row, at: arrivalDateColumn)
            let soldDateRaw = getOptionalStringValue(from: row, at: soldDateColumn)
            let fallbackSoldRaw = getOptionalStringValue(from: row, at: fallbackSoldColumn)
            let arrivalDate = parseDate(from: arrivalDateRaw ?? "")
            var soldDate = parseDate(from: soldDateRaw ?? "")
            if soldDate == nil {
                soldDate = parseDate(from: fallbackSoldRaw ?? "")
            }
            if soldDate == nil && soldSheetHint {
                soldDate = arrivalDate ?? ImportNormalization.normalizeToLocalCalendarDay(Date())
            }
            
            rows.append(ImportRow(
                serialCode: serialCode,
                configuration: configuration?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? "",
                notes: notes?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? "",
                quantity: parseQuantity(from: quantity ?? ""),
                transmission: transmission?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? "",
                arrivalDate: arrivalDate,
                soldDate: soldDate
            ))
        }
        
        return rows
    }
    
    // Строит данные для специфичных листов на основе маппинга
    func buildSpecificRows(for sheet: ImportSheetData, mapping: SheetColumnMapping) -> [[String: String]] {
        let dataStartIndex = (mapping.headerRowIndex ?? -1) + 1
        var rows: [[String: String]] = []

        let orderedFieldNames: [String] = mapping.columnMappings.compactMap { columnMapping in
            guard let fieldName = columnMapping.customFieldName else { return nil }
            let trimmed = fieldName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        let columnOrderJSON = (try? String(
            data: JSONSerialization.data(withJSONObject: orderedFieldNames),
            encoding: .utf8
        )) ?? ""

        for (rowIndex, row) in sheet.rows.enumerated() {
            if rowIndex < dataStartIndex { continue }

            var rowData: [String: String] = [:]
            var hasData = false

            for columnMapping in mapping.columnMappings {
                if let fieldName = columnMapping.customFieldName, !fieldName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    let value = getStringValue(from: row, at: columnMapping.columnIndex)
                    if !value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                        rowData[fieldName] = value
                        hasData = true
                    }
                }
            }

            if hasData {
                if !columnOrderJSON.isEmpty {
                    rowData["_columnOrder"] = columnOrderJSON
                }
                rows.append(rowData)
            }
        }

        return rows
    }
    
    private func getStringValue(from row: [String], at index: Int?) -> String {
        guard let index = index, row.indices.contains(index) else { return "" }
        return row[index]
    }
    
    private func getOptionalStringValue(from row: [String], at index: Int?) -> String? {
        guard let index = index, row.indices.contains(index) else { return nil }
        let value = row[index].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
    
    private func parseQuantity(from value: String) -> Int {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Int(trimmed), number > 0 {
            return number
        }
        return 1
    }
    
    private func parseDate(from value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let raw: Date?
        if let number = Double(trimmed) {
            raw = ImportNormalization.dateFromExcelSerial(number)
        } else {
            raw = ImportNormalization.parseDateString(trimmed)
        }
        return raw.map { ImportNormalization.normalizeToLocalCalendarDay($0) }
    }
    
    func commitImport(database: DatabaseService, backupService: BackupService?) async throws -> Int {
        // Создаем бэкап перед импортом
        try? backupService?.createBackupBeforeOperation()
        
        await MainActor.run {
            isImporting = true
            importProgress = nil
        }
        
        defer {
            Task { @MainActor in
                isImporting = false
                importProgress = nil
            }
        }
        
        let configs = await MainActor.run { sheetConfigs }
        let mappings = await MainActor.run { columnMappings }
        let rawData = await MainActor.run { rawSheetData }
        let companyId = await MainActor.run { self.companyId }
        
        return try await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { throw ImportError.cancelled }
            var imported = 0
            let totalSheets = configs.filter { $0.importType != .skip }.count
            var processedSheets = 0
            
            do {
                try database.executeInTransactionBlock {
                    try database.beginTransaction()
                    
                    for config in configs {
                        guard let sheetData = rawData.first(where: { $0.name == config.sheetName }) else { continue }
                        guard let mapping = mappings[config.id] else { continue }
                        
                        switch config.importType {
                        case .skip:
                            continue
                        case .engines:
                            let count = try Self.importEngineSheet(
                                config: config,
                                sheetData: sheetData,
                                mapping: mapping,
                                database: database,
                                companyId: companyId
                            )
                            imported += count
                        case .specific:
                            try Self.importSpecificSheet(
                                config: config,
                                sheetData: sheetData,
                                mapping: mapping,
                                database: database
                            )
                        }
                        
                        processedSheets += 1
                    }
                    
                    try database.commitTransaction()
                }
                
                // Обновляем прогресс после транзакции
                let finalProgress = (current: totalSheets, total: totalSheets)
                await MainActor.run { [weak self] in
                    self?.importProgress = finalProgress
                }
            } catch {
                try? database.rollbackTransaction()
                throw error
            }
            
            return imported
        }.value
    }
    
    enum ImportError: LocalizedError {
        case cancelled
        case invalidCategoryName
        
        var errorDescription: String? {
            switch self {
            case .cancelled:
                return "Импорт отменен"
            case .invalidCategoryName:
                return "Имя категории не может быть пустым"
            }
        }
    }
    
    nonisolated private static func importEngineSheet(
        config: SheetImportConfig,
        sheetData: ImportSheetData,
        mapping: SheetColumnMapping,
        database: DatabaseService,
        companyId: String = "default"
    ) throws -> Int {
        let rows = buildEngineRows(for: sheetData, mapping: mapping)
        
        let brandID: Int64
        if let selectedID = config.selectedBrandID {
            brandID = selectedID
        } else if let brandName = config.effectiveBrand {
            brandID = try database.upsertBrandUnlocked(name: brandName)
        } else {
            return 0
        }
        
        guard let engineCode = config.effectiveEngineCode else { return 0 }
        let engineID = try database.upsertEngineUnlocked(brandID: brandID, code: engineCode)
        let cid = companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "default" : companyId
        
        var imported = 0
        for row in rows {
            try database.insertOrUpdateMotorUnlocked(
                engineID: engineID,
                serialCode: row.serialCode,
                configuration: row.configuration,
                notes: row.notes,
                quantity: row.quantity,
                transmission: row.transmission,
                arrivalDate: row.arrivalDate ?? Date(),
                soldDate: row.soldDate,
                companyId: cid
            )
            imported += 1
        }
        
        return imported
    }
    
    nonisolated private static func buildEngineRows(for sheet: ImportSheetData, mapping: SheetColumnMapping) -> [ImportRow] {
        guard let serialMapping = mapping.columnMappings.first(where: { $0.engineFieldMapping == .serialCode }) else {
            return []
        }
        let soldSheetHint = isLikelySoldSheetNameStatic(sheet.name)
        let soldDateColumn = mapping.columnMappings.first(where: { $0.engineFieldMapping == .soldDate })?.columnIndex
        let arrivalDateColumn = mapping.columnMappings.first(where: { $0.engineFieldMapping == .arrivalDate })?.columnIndex
        let fallbackSoldColumn: Int? = {
            if soldDateColumn != nil { return nil }
            guard soldSheetHint else { return nil }
            guard let idx = detectFallbackSoldDateColumnStatic(in: mapping) else { return nil }
            return mapping.columnMappings[idx].columnIndex
        }()
        
        let dataStartIndex = (mapping.headerRowIndex ?? -1) + 1
        var rows: [ImportRow] = []
        
        for (rowIndex, row) in sheet.rows.enumerated() {
            if rowIndex < dataStartIndex { continue }
            
            let serialCode = getStringValueStatic(from: row, at: serialMapping.columnIndex)
            if serialCode.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let configuration = getStringValueStatic(from: row, at: mapping.columnMappings.first(where: { $0.engineFieldMapping == .configuration })?.columnIndex)
            let notes = getStringValueStatic(from: row, at: mapping.columnMappings.first(where: { $0.engineFieldMapping == .notes })?.columnIndex)
            let quantity = getStringValueStatic(from: row, at: mapping.columnMappings.first(where: { $0.engineFieldMapping == .quantity })?.columnIndex)
            let transmission = getStringValueStatic(from: row, at: mapping.columnMappings.first(where: { $0.engineFieldMapping == .transmission })?.columnIndex)
            let arrivalDateRaw = getStringValueStatic(from: row, at: arrivalDateColumn)
            let soldDateRaw = getStringValueStatic(from: row, at: soldDateColumn)
            let fallbackSoldRaw = getStringValueStatic(from: row, at: fallbackSoldColumn)
            let arrivalDate = parseDate(from: arrivalDateRaw)
            var soldDate = parseDate(from: soldDateRaw)
            if soldDate == nil {
                soldDate = parseDate(from: fallbackSoldRaw)
            }
            if soldDate == nil && soldSheetHint {
                soldDate = arrivalDate ?? ImportNormalization.normalizeToLocalCalendarDay(Date())
            }
            
            rows.append(ImportRow(
                serialCode: serialCode,
                configuration: configuration.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                quantity: parseQuantity(from: quantity),
                transmission: transmission.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                arrivalDate: arrivalDate,
                soldDate: soldDate
            ))
        }
        
        return rows
    }

    nonisolated private static func detectFallbackSoldDateColumnStatic(in mapping: SheetColumnMapping) -> Int? {
        let preferredWords = ["продаж", "sold", "sale", "дата", "date", "реализ"]
        for (index, column) in mapping.columnMappings.enumerated() {
            guard column.engineFieldMapping == nil || column.engineFieldMapping == .ignore else { continue }
            let header = ImportNormalization.normalizeHeader(column.headerValue ?? "")
            if preferredWords.contains(where: { header.contains($0) }) && hasDateLikePreviewStatic(column.previewValues) {
                return index
            }
        }
        return mapping.columnMappings.firstIndex(where: { column in
            (column.engineFieldMapping == nil || column.engineFieldMapping == .ignore) &&
            hasDateLikePreviewStatic(column.previewValues)
        })
    }

    nonisolated private static func hasDateLikePreviewStatic(_ values: [String]) -> Bool {
        guard !values.isEmpty else { return false }
        var matches = 0
        for v in values.prefix(5) {
            let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { continue }
            if ImportNormalization.parseDateString(t) != nil {
                matches += 1
                continue
            }
            if let n = Double(t), ImportNormalization.dateFromExcelSerial(n) != nil {
                matches += 1
            }
        }
        return matches >= 1
    }

    nonisolated private static func isLikelySoldSheetNameStatic(_ name: String) -> Bool {
        let n = ImportNormalization.normalizeHeader(name)
        return n.contains("продан") || n.contains("продажи") || n.contains("sold") || n.contains("sales")
    }
    
    nonisolated private static func getStringValueStatic(from row: [String], at index: Int?) -> String {
        guard let index = index, row.indices.contains(index) else { return "" }
        return row[index]
    }
    
    nonisolated private static func parseQuantity(from value: String) -> Int {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Int(trimmed), number > 0 {
            return number
        }
        return 1
    }
    
    nonisolated private static func parseDate(from value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let raw: Date?
        if let number = Double(trimmed) {
            raw = ImportNormalization.dateFromExcelSerial(number)
        } else {
            raw = ImportNormalization.parseDateString(trimmed)
        }
        return raw.map { ImportNormalization.normalizeToLocalCalendarDay($0) }
    }
    
    nonisolated private static func importSpecificSheet(
        config: SheetImportConfig,
        sheetData: ImportSheetData,
        mapping: SheetColumnMapping,
        database: DatabaseService
    ) throws {
        // Строим данные на основе маппинга
        let rows = buildSpecificRows(for: sheetData, mapping: mapping)
        
        // Создаем категорию (имя задано пользователем или взято из имени листа)
        let categoryName = config.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !categoryName.isEmpty else {
            throw ImportError.invalidCategoryName
        }
        
        // Создаем категорию (если уже существует - получим её ID)
        let categoryID: Int64
        do {
            categoryID = try database.createSpecificCategoryUnlocked(name: categoryName)
        } catch {
            // Если категория уже существует, получаем её ID
            // В SQLite UNIQUE constraint вернет ошибку, но мы можем попробовать найти существующую
            // Для простоты создаем новую с уникальным именем или используем существующую
            // В реальности лучше проверить существование перед созданием
            throw error
        }
        
        // Сохраняем каждую строку как JSON в specific_records
        for (rowIndex, rowData) in rows.enumerated() {
            let jsonData = try JSONSerialization.data(withJSONObject: rowData)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { continue }
            
            try database.insertSpecificRecordUnlocked(
                categoryID: categoryID,
                rowIndex: rowIndex,
                dataJSON: jsonString
            )
        }
    }
    
    // Находит поле с номером двигателя в специфичном листе
    nonisolated private static func findSerialCodeField(in mapping: SheetColumnMapping) -> String? {
        // Ищем по различным вариантам названий
        for columnMapping in mapping.columnMappings {
            if let fieldName = columnMapping.customFieldName {
                let normalized = fieldName.uppercased()
                if normalized.contains("НОМЕР") && (normalized.contains("ДВИГАТЕЛ") || normalized.contains("МОТОР")) {
                    return fieldName
                }
                if normalized == "НОМЕР" || normalized == "SERIAL" || normalized == "SERIAL_CODE" {
                    return fieldName
                }
            }
        }
        return nil
    }
    
    nonisolated private static func buildSpecificRows(for sheet: ImportSheetData, mapping: SheetColumnMapping) -> [[String: String]] {
        let dataStartIndex = (mapping.headerRowIndex ?? -1) + 1
        var rows: [[String: String]] = []

        let orderedFieldNames: [String] = mapping.columnMappings.compactMap { columnMapping in
            guard let fieldName = columnMapping.customFieldName else { return nil }
            let trimmed = fieldName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        let columnOrderJSON = (try? String(
            data: JSONSerialization.data(withJSONObject: orderedFieldNames),
            encoding: .utf8
        )) ?? ""

        for (rowIndex, row) in sheet.rows.enumerated() {
            if rowIndex < dataStartIndex { continue }

            var rowData: [String: String] = [:]
            var hasData = false

            for columnMapping in mapping.columnMappings {
                if let fieldName = columnMapping.customFieldName, !fieldName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    let value = getStringValueStatic(from: row, at: columnMapping.columnIndex)
                    if !value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                        rowData[fieldName] = value
                        hasData = true
                    }
                }
            }

            if hasData {
                if !columnOrderJSON.isEmpty {
                    rowData["_columnOrder"] = columnOrderJSON
                }
                rows.append(rowData)
            }
        }

        return rows
    }
    
    @MainActor
    private func setError(_ message: String) {
        errorMessage = message
        isLoading = false
    }
    
    @MainActor
    private func updateBrands(_ brands: [Brand]) {
        existingBrands = brands
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
}
