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
    private var cancellables = Set<AnyCancellable>()
    
    // Принудительное обновление для Feature Flags
    @Published var featureFlagsUpdateTrigger: Int = 0
    
    enum SettingsSection: String, CaseIterable {
        case general = "Общие"
        case interface = "Интерфейс"
        case features = "Функции"
        case data = "Данные"
        case importExport = "Импорт / Экспорт"
        case workflow = "Рабочий процесс"
        case advanced = "Продвинутые"
        
        var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .interface: return "sidebar.left"
            case .features: return "flag.fill"
            case .data: return "externaldrive.fill"
            case .importExport: return "arrow.up.arrow.down"
            case .workflow: return "flowchart.fill"
            case .advanced: return "wrench.and.screwdriver.fill"
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
        
        // Принудительно обновляем ViewModel при изменении feature flags
        // Это заставляет SwiftUI обновить UI при изменении флагов
        featureFlagService.objectWillChange
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.featureFlagsUpdateTrigger += 1
                }
            }
            .store(in: &cancellables)
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
    
    func resetToDefaults() {
        settingsService.resetToDefaults()
    }
}
