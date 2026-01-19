import SwiftUI

/// Settings View с sidebar в стиле macOS System Settings
struct SettingsView: View {
    @ObservedObject var backupService: BackupService
    @ObservedObject var featureFlagService: FeatureFlagService
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var recoveryState: RecoveryState
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: SettingsViewModel
    @State private var selectedSection: SettingsViewModel.SettingsSection = .general
    @State private var isAdvancedExpanded = false
    
    let databaseService: DatabaseService
    
    init(
        backupService: BackupService,
        featureFlagService: FeatureFlagService,
        settingsService: SettingsService,
        recoveryState: RecoveryState,
        databaseService: DatabaseService
    ) {
        self.backupService = backupService
        self.featureFlagService = featureFlagService
        self.settingsService = settingsService
        self.recoveryState = recoveryState
        self.databaseService = databaseService
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            settingsService: settingsService,
            recoveryState: recoveryState,
            backupService: backupService,
            featureFlagService: featureFlagService
        ))
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar слева
            List(selection: $selectedSection) {
                ForEach(SettingsViewModel.SettingsSection.allCases, id: \.self) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200, idealWidth: 240)
        } detail: {
            // Контент справа
            Group {
                switch selectedSection {
                case .general:
                    GeneralSettingsView(viewModel: viewModel)
                case .features:
                    FeatureFlagsSettingsView(viewModel: viewModel)
                case .data:
                    BackupManagementViewNew(
                        backupRepository: BackupRepositoryLocalImpl(),
                        databaseService: databaseService,
                        recoveryState: recoveryState
                    )
                case .importExport:
                    ImportExportSettingsView(viewModel: viewModel)
                case .workflow:
                    WorkflowSettingsView(viewModel: viewModel)
                case .advanced:
                    AdvancedSettingsView(viewModel: viewModel, isExpanded: $isAdvancedExpanded)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700, minHeight: 500)
        .navigationTitle("Настройки")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Закрыть настройки")
            }
        }
    }
}

// MARK: - General Settings

private struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        ScrollView {
            Form {
                Section {
                    if viewModel.isRecoveryMode {
                        RecoveryModeInfoView(
                            message: viewModel.recoveryMessage ?? "Режим восстановления активен"
                        )
                    } else {
                        Label("Приложение работает нормально", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("Состояние системы")
                } footer: {
                    if viewModel.isRecoveryMode {
                        Text("Приложение работает в режиме только для чтения. Некоторые функции недоступны.")
                    } else {
                        Text("Все системы работают нормально")
                    }
                }
            }
            .padding()
        }
    }
}

private struct RecoveryModeInfoView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Feature Flags Settings

private struct FeatureFlagsSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        ScrollView {
            Form {
                Section {
                    ForEach(FeatureFlagService.Flag.allCases, id: \.rawValue) { flag in
                        Toggle(isOn: Binding(
                            get: {
                                // Используем trigger для принудительного обновления UI
                                let _ = viewModel.featureFlagsUpdateTrigger
                                let isEnabled = viewModel.isFeatureEnabled(flag)
                                // Отладка: логируем текущее состояние
                                print("🔍 [FeatureFlags] GET flag: \(flag.rawValue), enabled: \(isEnabled), trigger: \(viewModel.featureFlagsUpdateTrigger)")
                                return isEnabled
                            },
                            set: { enabled in
                                // Отладка: логируем изменение
                                print("🔧 [FeatureFlags] SET flag: \(flag.rawValue), enabled: \(enabled)")
                                print("   📍 Before: \(viewModel.isFeatureEnabled(flag))")
                                viewModel.setFeatureEnabled(flag, enabled: enabled)
                                // Небольшая задержка для проверки изменения
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 сек
                                    print("   📍 After: \(viewModel.isFeatureEnabled(flag))")
                                    if viewModel.isFeatureEnabled(flag) != enabled {
                                        print("   ⚠️ WARNING: Flag не изменился! Ожидали: \(enabled), получили: \(viewModel.isFeatureEnabled(flag))")
                                    } else {
                                        print("   ✅ SUCCESS: Flag изменен успешно")
                                    }
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(flag.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.headline)
                                Text(flag.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Управление функциями")
                } footer: {
                    Text("Включите или выключите функции приложения. Изменения применяются немедленно. Смотрите консоль для отладки.")
                }
            }
            .padding()
        }
    }
}

// MARK: - Data & Storage Settings

private struct DataStorageSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var localBackup: BackupSettings
    
    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        _localBackup = State(initialValue: viewModel.settings.backup)
    }
    
    // Синхронизируем localBackup с settings при изменении settings
    private func syncBackupSettings() {
        if localBackup != viewModel.settings.backup {
            localBackup = viewModel.settings.backup
        }
    }
    
    var body: some View {
        ScrollView {
            Form {
                Section {
                    Toggle("Автоматический бэкап", isOn: $localBackup.isAutoBackupEnabled)
                        .onChange(of: localBackup.isAutoBackupEnabled) { _, _ in
                            viewModel.updateBackupSettings(localBackup)
                        }
                    
                    Picker("Частота", selection: $localBackup.backupFrequency) {
                        ForEach(BackupSettings.BackupFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .onChange(of: localBackup.backupFrequency) { _, _ in
                        viewModel.updateBackupSettings(localBackup)
                    }
                    .disabled(!localBackup.isAutoBackupEnabled)
                    
                    Stepper("Максимум копий: \(localBackup.maxBackupCount)", value: $localBackup.maxBackupCount, in: 5...100, step: 5)
                        .onChange(of: localBackup.maxBackupCount) { _, _ in
                            viewModel.updateBackupSettings(localBackup)
                        }
                    
                    Toggle("Бэкап перед импортом", isOn: $localBackup.backupBeforeImport)
                        .onChange(of: localBackup.backupBeforeImport) { _, _ in
                            viewModel.updateBackupSettings(localBackup)
                        }
                    
                    Button("Создать бэкап сейчас") {
                        try? viewModel.createBackupNow()
                    }
                } header: {
                    Text("Управление бэкапами")
                } footer: {
                    if let lastBackup = viewModel.lastBackupDate {
                        Text("Последний бэкап: \(formatDate(lastBackup))")
                    } else {
                        Text("Бэкапы еще не создавались")
                    }
                }
                
                Section {
                    if !viewModel.backups.isEmpty {
                        ForEach(viewModel.backups.prefix(5)) { backup in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(backup.formattedDate)
                                        .font(.headline)
                                    Text(backup.formattedSize)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    } else {
                        Text("Бэкапы отсутствуют")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Последние бэкапы")
                }
            }
            .padding()
            .onChange(of: viewModel.settings.backup) { _, _ in
                syncBackupSettings()
            }
            .onAppear {
                syncBackupSettings()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Import/Export Settings

private struct ImportExportSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var localImportExport: ImportExportSettings
    
    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        _localImportExport = State(initialValue: viewModel.settings.importExport)
    }
    
    private func syncImportExportSettings() {
        if localImportExport != viewModel.settings.importExport {
            localImportExport = viewModel.settings.importExport
        }
    }
    
    var body: some View {
        ScrollView {
            Form {
                Section {
                    Picker("Поведение при конфликтах", selection: $localImportExport.importConflictBehavior) {
                        ForEach(ImportExportSettings.ImportConflictBehavior.allCases, id: \.self) { behavior in
                            Text(behavior.displayName).tag(behavior)
                        }
                    }
                    .onChange(of: localImportExport.importConflictBehavior) { _, _ in
                        viewModel.updateImportExportSettings(localImportExport)
                    }
                } header: {
                    Text("Импорт")
                } footer: {
                    Text("Что делать при обнаружении дубликатов при импорте")
                }
                
                Section {
                    TextField("Формат даты", text: $localImportExport.exportDateFormat)
                        .onChange(of: localImportExport.exportDateFormat) { _, _ in
                            viewModel.updateImportExportSettings(localImportExport)
                        }
                    
                    Toggle("Экспортировать проданные моторы", isOn: $localImportExport.exportSoldMotors)
                        .onChange(of: localImportExport.exportSoldMotors) { _, _ in
                            viewModel.updateImportExportSettings(localImportExport)
                        }
                    
                    Toggle("Экспортировать удаленные моторы", isOn: $localImportExport.exportDeletedMotors)
                        .onChange(of: localImportExport.exportDeletedMotors) { _, _ in
                            viewModel.updateImportExportSettings(localImportExport)
                        }
                } header: {
                    Text("Экспорт")
                } footer: {
                    Text("Настройки по умолчанию для экспорта данных")
                }
            }
            .padding()
            .onChange(of: viewModel.settings.importExport) { _, _ in
                syncImportExportSettings()
            }
            .onAppear {
                syncImportExportSettings()
            }
        }
    }
}

// MARK: - Workflow Settings

private struct WorkflowSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var localWorkflow: WorkflowSettings
    
    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        _localWorkflow = State(initialValue: viewModel.settings.workflow)
    }
    
    private func syncWorkflowSettings() {
        if localWorkflow != viewModel.settings.workflow {
            localWorkflow = viewModel.settings.workflow
        }
    }
    
    var body: some View {
        ScrollView {
            Form {
                Section {
                    Picker("Фильтр при запуске", selection: Binding(
                        get: { localWorkflow.defaultAvailabilityFilter },
                        set: { newValue in
                            localWorkflow.defaultAvailabilityFilter = newValue
                            viewModel.updateWorkflowSettings(localWorkflow)
                        }
                    )) {
                        ForEach(MotorAvailabilityFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    
                    Toggle("Автопереход к проданным после продажи", isOn: $localWorkflow.autoSwitchToSoldAfterSell)
                        .onChange(of: localWorkflow.autoSwitchToSoldAfterSell) { _, _ in
                            viewModel.updateWorkflowSettings(localWorkflow)
                        }
                    
                    Toggle("Запоминать последний бренд", isOn: $localWorkflow.rememberLastBrand)
                        .onChange(of: localWorkflow.rememberLastBrand) { _, _ in
                            viewModel.updateWorkflowSettings(localWorkflow)
                        }
                    
                    Toggle("Запоминать последний двигатель", isOn: $localWorkflow.rememberLastEngine)
                        .onChange(of: localWorkflow.rememberLastEngine) { _, _ in
                            viewModel.updateWorkflowSettings(localWorkflow)
                        }
                } header: {
                    Text("Поведение по умолчанию")
                } footer: {
                    Text("Настройки, которые влияют на повседневную работу с приложением")
                }
            }
            .padding()
            .onChange(of: viewModel.settings.workflow) { _, _ in
                syncWorkflowSettings()
            }
            .onAppear {
                syncWorkflowSettings()
            }
        }
    }
}

// MARK: - Advanced Settings

private struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var isExpanded: Bool
    @State private var localAdvanced: AdvancedSettings
    
    init(viewModel: SettingsViewModel, isExpanded: Binding<Bool>) {
        self.viewModel = viewModel
        self._isExpanded = isExpanded
        _localAdvanced = State(initialValue: viewModel.settings.advanced)
    }
    
    private func syncAdvancedSettings() {
        if localAdvanced != viewModel.settings.advanced {
            localAdvanced = viewModel.settings.advanced
        }
    }
    
    var body: some View {
        ScrollView {
            Form {
                Section {
                    Toggle("Режим разработчика", isOn: $localAdvanced.developerModeEnabled)
                        .onChange(of: localAdvanced.developerModeEnabled) { _, _ in
                            viewModel.updateAdvancedSettings(localAdvanced)
                        }
                    
                    Toggle("Отладочное логирование", isOn: $localAdvanced.enableDebugLogging)
                        .onChange(of: localAdvanced.enableDebugLogging) { _, _ in
                            viewModel.updateAdvancedSettings(localAdvanced)
                        }
                        .disabled(!localAdvanced.developerModeEnabled)
                    
                    Toggle("Показывать информацию о миграциях", isOn: $localAdvanced.showMigrationInfo)
                        .onChange(of: localAdvanced.showMigrationInfo) { _, _ in
                            viewModel.updateAdvancedSettings(localAdvanced)
                        }
                        .disabled(!localAdvanced.developerModeEnabled)
                } header: {
                    Text("Разработка")
                } footer: {
                    Text("Включите режим разработчика для доступа к расширенным функциям")
                }
                
                Section {
                    Button("Сбросить настройки по умолчанию") {
                        viewModel.resetToDefaults()
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("Сброс")
                } footer: {
                    Text("Вернуть все настройки к значениям по умолчанию")
                }
                
                Section {
                    HStack {
                        Text("Версия приложения")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Версия схемы БД")
                        Spacer()
                        Text("9")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Информация")
                }
            }
            .padding()
            .onChange(of: viewModel.settings.advanced) { _, _ in
                syncAdvancedSettings()
            }
            .onAppear {
                syncAdvancedSettings()
            }
        }
    }
}
