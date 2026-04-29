import Foundation
import Combine

/// Settings Service (Application Layer)
/// Управляет системными настройками приложения
/// Settings = поведение системы, НЕ бизнес-данные
@MainActor
final class SettingsService: ObservableObject {
    @Published private(set) var settings: AppSettings
    private let repository: SettingsRepository
    private let logger: LoggingService
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: SettingsRepository, logger: LoggingService = .shared) {
        self.repository = repository
        self.logger = logger
        
        // Загружаем настройки при инициализации
        self.settings = (try? repository.loadSettings()) ?? .default
    }
    
    // MARK: - General Settings
    
    func updateGeneral(_ general: GeneralSettings) {
        var newSettings = settings
        newSettings.general = general
        saveSettings(newSettings)
    }
    
    // MARK: - Backup Settings
    
    func updateBackup(_ backup: BackupSettings) {
        var newSettings = settings
        newSettings.backup = backup
        saveSettings(newSettings)
    }
    
    // MARK: - Import/Export Settings
    
    func updateImportExport(_ importExport: ImportExportSettings) {
        var newSettings = settings
        newSettings.importExport = importExport
        saveSettings(newSettings)
    }
    
    // MARK: - Workflow Settings
    
    func updateWorkflow(_ workflow: WorkflowSettings) {
        var newSettings = settings
        newSettings.workflow = workflow
        saveSettings(newSettings)
    }
    
    // MARK: - Advanced Settings
    
    func updateAdvanced(_ advanced: AdvancedSettings) {
        var newSettings = settings
        newSettings.advanced = advanced
        saveSettings(newSettings)
    }

    // MARK: - Accounting Settings

    func updateAccounting(_ accounting: AccountingSettings) {
        var newSettings = settings
        newSettings.accounting = accounting
        saveSettings(newSettings)
    }
    
    // MARK: - Reset
    
    func resetToDefaults() {
        settings = .default
        saveSettings(settings)
        logger.info("Settings reset to defaults")
    }
    
    // MARK: - Private
    
    private func saveSettings(_ newSettings: AppSettings) {
        settings = newSettings
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            do {
                // saveSettings не async, вызываем напрямую
                try self.repository.saveSettings(newSettings)
                await MainActor.run { [weak self] in
                    self?.logger.info("Settings saved successfully")
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.logger.error("Failed to save settings", error: error)
                }
            }
        }
    }
}
