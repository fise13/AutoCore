import Foundation

// MARK: - Settings Domain Models
// Value Objects для системных настроек приложения

/// Общие настройки системы
struct GeneralSettings: Codable, Equatable {
    var showRecoveryModeInfo: Bool = true
    var language: String = "ru" // Для будущей локализации
    
    static let `default` = GeneralSettings()
}

/// Настройки бэкапов
struct BackupSettings: Codable, Equatable {
    var isAutoBackupEnabled: Bool = true
    var backupFrequency: BackupFrequency = .daily
    var maxBackupCount: Int = 30
    var backupBeforeImport: Bool = true
    
    enum BackupFrequency: String, Codable, CaseIterable {
        case daily = "daily"
        case beforeImport = "before_import"
        case both = "both"
        
        var displayName: String {
            switch self {
            case .daily: return "Ежедневно"
            case .beforeImport: return "Перед импортом"
            case .both: return "Ежедневно и перед импортом"
            }
        }
    }
    
    static let `default` = BackupSettings()
}

/// Настройки импорта/экспорта
struct ImportExportSettings: Codable, Equatable {
    var importConflictBehavior: ImportConflictBehavior = .ask
    var exportDateFormat: String = "yyyy-MM-dd"
    var exportSoldMotors: Bool = true
    var exportDeletedMotors: Bool = false // Экспортировать ли мягко удаленные моторы
    
    enum ImportConflictBehavior: String, Codable, CaseIterable {
        case skip = "skip"
        case update = "update"
        case ask = "ask"
        
        var displayName: String {
            switch self {
            case .skip: return "Пропустить"
            case .update: return "Обновить"
            case .ask: return "Спрашивать"
            }
        }
    }
    
    static let `default` = ImportExportSettings()
}

/// Настройки рабочего процесса
struct WorkflowSettings: Codable, Equatable {
    var defaultAvailabilityFilterRaw: String = "all" // Сохраняем как String для Codable
    var autoSwitchToSoldAfterSell: Bool = true
    var rememberLastBrand: Bool = true
    var rememberLastEngine: Bool = false
    
    /// Доступ к фильтру как к enum (для использования в коде)
    var defaultAvailabilityFilter: MotorAvailabilityFilter {
        get {
            MotorAvailabilityFilter(rawValue: defaultAvailabilityFilterRaw) ?? .all
        }
        set {
            defaultAvailabilityFilterRaw = newValue.rawValue
        }
    }
    
    static let `default` = WorkflowSettings()
}

/// Продвинутые настройки
struct AdvancedSettings: Codable, Equatable {
    var developerModeEnabled: Bool = false
    var enableDebugLogging: Bool = false
    var showMigrationInfo: Bool = false
    
    static let `default` = AdvancedSettings()
}

/// Настройки бухгалтерии: сотрудники и специфичные теги/направления.
struct AccountingSettings: Codable, Equatable {
    var isConfigured: Bool = false
    var employees: [String] = []
    var specifics: [String] = []

    static let `default` = AccountingSettings()
}

/// Общий контейнер всех настроек
struct AppSettings: Codable, Equatable {
    var general: GeneralSettings
    var backup: BackupSettings
    var importExport: ImportExportSettings
    var workflow: WorkflowSettings
    var advanced: AdvancedSettings
    var accounting: AccountingSettings
    
    var version: Int = 1 // Для миграций настроек в будущем
    
    static let `default` = AppSettings(
        general: .default,
        backup: .default,
        importExport: .default,
        workflow: .default,
        advanced: .default,
        accounting: .default
    )

    private enum CodingKeys: String, CodingKey {
        case general, backup, importExport, workflow, advanced, accounting, version
    }

    init(
        general: GeneralSettings,
        backup: BackupSettings,
        importExport: ImportExportSettings,
        workflow: WorkflowSettings,
        advanced: AdvancedSettings,
        accounting: AccountingSettings,
        version: Int = 1
    ) {
        self.general = general
        self.backup = backup
        self.importExport = importExport
        self.workflow = workflow
        self.advanced = advanced
        self.accounting = accounting
        self.version = version
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        general = try c.decodeIfPresent(GeneralSettings.self, forKey: .general) ?? .default
        backup = try c.decodeIfPresent(BackupSettings.self, forKey: .backup) ?? .default
        importExport = try c.decodeIfPresent(ImportExportSettings.self, forKey: .importExport) ?? .default
        workflow = try c.decodeIfPresent(WorkflowSettings.self, forKey: .workflow) ?? .default
        advanced = try c.decodeIfPresent(AdvancedSettings.self, forKey: .advanced) ?? .default
        accounting = try c.decodeIfPresent(AccountingSettings.self, forKey: .accounting) ?? .default
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
    }
}
