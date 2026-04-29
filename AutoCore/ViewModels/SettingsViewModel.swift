import Foundation
import Combine

/// Settings ViewModel (Presentation Layer)
/// Только для UI - не содержит бизнес-логики
/// Все изменения проходят через SettingsService
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedSection: SettingsSection = .general
    
    // Settings из Service (read-only для UI)
    @Published private(set) var settings: AppSettings
    
    private let settingsService: SettingsService
    private let recoveryState: RecoveryState?
    private let backupService: BackupService
    private let featureFlagService: FeatureFlagService
    
    enum SettingsSection: String, CaseIterable {
        case general = "Общие"
        case account = "Аккаунт"
        case interface = "Внешний вид"
        case features = "Возможности"
        case accounting = "Бухгалтерия"
        case data = "Резервные копии"
        case importExport = "Импорт и экспорт"
        case workflow = "Поведение"
        case advanced = "Дополнительно"
        
        var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .account: return "person.crop.circle.fill"
            case .interface: return "paintbrush.fill"
            case .features: return "sparkles"
            case .accounting: return "rublesign.circle.fill"
            case .data: return "externaldrive.fill"
            case .importExport: return "arrow.up.arrow.down"
            case .workflow: return "wand.and.stars"
            case .advanced: return "slider.horizontal.3"
            }
        }
    }
    
    init(
        settingsService: SettingsService,
        recoveryState: RecoveryState?,
        backupService: BackupService,
        featureFlagService: FeatureFlagService
    ) {
        self.settingsService = settingsService
        self.recoveryState = recoveryState
        self.backupService = backupService
        self.featureFlagService = featureFlagService
        self.settings = settingsService.settings
        
        // Подписываемся на изменения настроек
        settingsService.$settings
            .assign(to: &$settings)
    }
    
    // MARK: - General Settings
    
    var isRecoveryMode: Bool {
        recoveryState?.isRecoveryMode ?? false
    }
    
    var recoveryMessage: String? {
        recoveryState?.recoveryMessage
    }
    
    // MARK: - Backup Settings
    
    func updateBackupSettings(_ backup: BackupSettings) {
        settingsService.updateBackup(backup)
    }
    
    func createBackupNow() throws {
        // createBackup() синхронный метод
        _ = try backupService.createBackup()
    }
    
    var lastBackupDate: Date? {
        backupService.lastBackup
    }
    
    var backups: [BackupService.BackupInfo] {
        backupService.backups
    }
    
    // MARK: - Feature Flags
    
    func isFeatureEnabled(_ flag: FeatureFlagService.Flag) -> Bool {
        featureFlagService.isEnabled(flag)
    }
    
    func setFeatureEnabled(_ flag: FeatureFlagService.Flag, enabled: Bool) {
        do {
            try featureFlagService.setEnabled(flag, enabled: enabled)
        } catch {
            // Keep silent for UI performance; caller can observe service state.
        }
    }
    
    // MARK: - Import/Export Settings
    
    func updateImportExportSettings(_ importExport: ImportExportSettings) {
        settingsService.updateImportExport(importExport)
    }
    
    // MARK: - Workflow Settings
    
    func updateWorkflowSettings(_ workflow: WorkflowSettings) {
        settingsService.updateWorkflow(workflow)
    }
    
    // MARK: - Advanced Settings
    
    func updateAdvancedSettings(_ advanced: AdvancedSettings) {
        settingsService.updateAdvanced(advanced)
    }

    func updateAccountingSettings(_ accounting: AccountingSettings) {
        settingsService.updateAccounting(accounting)
    }
    
    func resetToDefaults() {
        settingsService.resetToDefaults()
    }
}
