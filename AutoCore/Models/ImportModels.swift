import Foundation

enum SheetImportType: String, CaseIterable, Identifiable {
    case engines = "engines"
    case specific = "specific"
    case skip = "skip"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .engines:
            return "Двигатели (основные данные)"
        case .specific:
            return "Специфичный лист (не склад)"
        case .skip:
            return "Пропустить"
        }
    }
    
    var description: String {
        switch self {
        case .engines:
            return "Данные идут в brands / engines / motors"
        case .specific:
            return "Ремонт, после Дэна, Толя, локации, временные данные"
        case .skip:
            return "Лист не импортируется"
        }
    }
}

enum SpecificSheetCategory: String, CaseIterable, Identifiable {
    case repair = "repair"
    case afterDan = "afterDan"
    case afterTolya = "afterTolya"
    case storage = "storage"
    case other = "other"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .repair:
            return "Ремонт"
        case .afterDan:
            return "После Дэна"
        case .afterTolya:
            return "После Толи"
        case .storage:
            return "Хранение"
        case .other:
            return "Другое"
        }
    }
}

struct SheetImportConfig: Identifiable, Hashable {
    let id = UUID()
    let sheetName: String
    let rowCount: Int
    let previewRows: [[String]]
    
    var importType: SheetImportType = .skip
    
    // Для типа .engines
    var selectedBrandID: Int64? = nil
    var customBrand: String = ""
    var customEngineCode: String = ""
    
    // Для типа .specific
    var specificCategory: SpecificSheetCategory = .repair
    var customCategoryName: String = ""
    
    init(sheetName: String, rowCount: Int, previewRows: [[String]]) {
        self.sheetName = sheetName
        self.rowCount = rowCount
        self.previewRows = previewRows
        
        // Автоматическое определение категории для специфичных листов
        let normalizedName = sheetName.uppercased()
        if normalizedName.contains("РЕМОНТ") {
            if normalizedName.contains("ДЭН") || normalizedName.contains("ДЕН") {
                self.specificCategory = .afterDan
            } else if normalizedName.contains("ТОЛ") || normalizedName.contains("ТОЛЯ") {
                self.specificCategory = .afterTolya
            } else {
                self.specificCategory = .repair
            }
        } else if normalizedName.contains("ДЭН") || normalizedName.contains("ДЕН") {
            self.specificCategory = .afterDan
        } else if normalizedName.contains("ТОЛ") || normalizedName.contains("ТОЛЯ") {
            self.specificCategory = .afterTolya
        } else if normalizedName.contains("ХРАН") || normalizedName.contains("СКЛАД") {
            self.specificCategory = .storage
        }
        
        // Автоматическое определение кода двигателя из названия листа
        let engineCodePattern = #"[A-Z]{1,3}\s*[-_ ]?\s*\d{2,4}[A-Z]?"#
        if let regex = try? NSRegularExpression(pattern: engineCodePattern),
           let match = regex.firstMatch(in: sheetName, range: NSRange(sheetName.startIndex..., in: sheetName)) {
            let raw = (sheetName as NSString).substring(with: match.range)
            self.customEngineCode = ImportNormalization.normalizeEngineCode(raw)
        }
        
        // Автоматическое определение бренда из названия листа (если есть известные бренды)
        let brandMapping: [String: String] = [
            "MITSUBISHI": "Mitsubishi",
            "TOYOTA": "Toyota",
            "NISSAN": "Nissan",
            "INFINITI": "Infiniti",
            "SUBARU": "Subaru",
            "HONDA": "Honda",
            "MAZDA": "Mazda",
            "SUZUKI": "Suzuki",
            "ISUZU": "Isuzu",
            "HYUNDAI": "Hyundai"
        ]
        
        for (key, value) in brandMapping {
            if normalizedName.contains(key) {
                self.customBrand = value
                break
            }
        }
        
        // Если не нашли бренд, но есть код двигателя - попробуем определить по коду
        if customBrand.isEmpty, !customEngineCode.isEmpty {
            if let inferredBrand = ImportNormalization.inferBrand(fromEngineCode: customEngineCode) {
                self.customBrand = inferredBrand
            }
        }
    }
    
    var effectiveBrand: String? {
        if let selectedBrandID = selectedBrandID {
            return nil // Будет resolved через ID
        }
        let brand = customBrand.trimmingCharacters(in: .whitespacesAndNewlines)
        return brand.isEmpty ? nil : brand
    }
    
    var effectiveEngineCode: String? {
        let custom = customEngineCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            return ImportNormalization.normalizeEngineCode(custom)
        }
        return nil
    }
    
    var isConfigured: Bool {
        switch importType {
        case .skip:
            return true
        case .engines:
            return (selectedBrandID != nil || !customBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
                   effectiveEngineCode != nil
        case .specific:
            if specificCategory == .other {
                return !customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        }
    }
}

struct ImportRow: Identifiable, Hashable {
    let id = UUID()
    let serialCode: String
    let configuration: String
    let notes: String
    let quantity: Int
    let transmission: String
    let arrivalDate: Date?
    let soldDate: Date?
}

struct ImportPreviewSummary {
    let totalMotors: Int
    let newBrands: [String]
    let newEngines: [(brand: String, code: String)]
    let skippedSheets: [String]
    let specificSheets: [(name: String, category: SpecificSheetCategory, customCategory: String?)]
}
