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
    let companyId: String?
    
    init(
        backupService: BackupService,
        featureFlagService: FeatureFlagService,
        settingsService: SettingsService,
        recoveryState: RecoveryState,
        databaseService: DatabaseService,
        companyId: String? = nil
    ) {
        self.backupService = backupService
        self.featureFlagService = featureFlagService
        self.settingsService = settingsService
        self.recoveryState = recoveryState
        self.databaseService = databaseService
        self.companyId = companyId
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            settingsService: settingsService,
            recoveryState: recoveryState,
            backupService: backupService,
            featureFlagService: featureFlagService
        ))
    }
    
    var body: some View {
        Group {
            #if os(macOS)
            NavigationSplitView {
                List(selection: $selectedSection) {
                    ForEach(SettingsViewModel.SettingsSection.allCases, id: \.self) { section in
                        Label(section.rawValue, systemImage: section.icon)
                            .tag(section)
                    }
                }
                .listStyle(.sidebar)
                .frame(minWidth: 200, idealWidth: 240)
            } detail: {
                settingsDetailContent
            }
            .frame(minWidth: 700, minHeight: 500)
            #else
            NavigationStack {
                List(SettingsViewModel.SettingsSection.allCases, id: \.self) { section in
                    NavigationLink(value: section) {
                        Label(section.rawValue, systemImage: section.icon)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationDestination(for: SettingsViewModel.SettingsSection.self) { section in
                    settingsDetailForSection(section)
                }
            }
            #endif
        }
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
    
    @ViewBuilder
    private var settingsDetailContent: some View {
        Group {
            switch selectedSection {
            case .general:
                GeneralSettingsView(viewModel: viewModel, databaseService: databaseService, companyId: companyId)
            case .interface:
                #if os(macOS)
                InterfaceSettingsView()
                #else
                Text("Настройка интерфейса доступна на macOS")
                #endif
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
    
    @ViewBuilder
    private func settingsDetailForSection(_ section: SettingsViewModel.SettingsSection) -> some View {
        switch section {
        case .general:
            GeneralSettingsView(viewModel: viewModel, databaseService: databaseService, companyId: companyId)
        case .interface:
            #if os(macOS)
            InterfaceSettingsView()
            #else
            Text("Настройка интерфейса доступна на macOS")
            #endif
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
}

// MARK: - General Settings

private struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let databaseService: DatabaseService
    let companyId: String?
    @State private var showClearAccountingConfirm = false
    @State private var statusMessage: String?
    
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

                Section {
                    Button(role: .destructive) {
                        showClearAccountingConfirm = true
                    } label: {
                        Label("Очистить всю бухгалтерию", systemImage: "trash")
                    }
                } header: {
                    Text("Бухгалтерия")
                } footer: {
                    Text("Удаляет все финансовые операции текущей компании.")
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .foregroundColor(statusMessage.contains("Не удалось") ? .red : .green)
                    }
                }
            }
            .padding()
            .confirmationDialog("Очистить всю бухгалтерию?", isPresented: $showClearAccountingConfirm) {
                Button("Очистить", role: .destructive) {
                    clearAllAccounting()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Это действие удалит все операции без возможности восстановления.")
            }
        }
    }

    private func clearAllAccounting() {
        do {
            try databaseService.clearFinancialOperations(companyId: companyId)
            statusMessage = "Бухгалтерия очищена"
        } catch {
            statusMessage = "Не удалось очистить бухгалтерию: \(error.localizedDescription)"
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

#if os(macOS)
private struct InterfaceSettingsView: View {
    @State private var sidebarConfig = SidebarCustomizationStore.shared.load()
    @State private var userConfig = UserConfigStore.shared.load() ?? UserConfig.template(.warehouse)

    private let dateFormats = ["dd.MM.yyyy", "MM/dd/yyyy"]

    var body: some View {
        ScrollView {
            Form {
                Section("Левое меню") {
                    ForEach(sidebarConfig.orderedSections, id: \.self) { section in
                        HStack {
                            Toggle(section.title, isOn: Binding(
                                get: { sidebarConfig.isVisible(section) },
                                set: { isOn in
                                    if isOn {
                                        sidebarConfig.hiddenSections.remove(section)
                                    } else {
                                        sidebarConfig.hiddenSections.insert(section)
                                    }
                                    saveSidebar()
                                }
                            ))
                            Spacer()
                            Button {
                                moveSection(section, delta: -1)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            Button {
                                moveSection(section, delta: 1)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    Toggle("Показывать блок категорий", isOn: $sidebarConfig.showSpecificCategories)
                        .onChange(of: sidebarConfig.showSpecificCategories) { _, _ in saveSidebar() }
                    Toggle("Показывать блок брендов", isOn: $sidebarConfig.showBrandsBlock)
                        .onChange(of: sidebarConfig.showBrandsBlock) { _, _ in saveSidebar() }
                }

                Section("Тип шаблона") {
                    Picker("Тип", selection: $userConfig.businessType) {
                        Text("Склад").tag(BusinessType.warehouse)
                        Text("Перепродажа").tag(BusinessType.resale)
                        Text("Своё").tag(BusinessType.custom)
                    }
                    .onChange(of: userConfig.businessType) { _, newValue in
                        let updated = UserConfig.template(newValue)
                        userConfig.columns = updated.columns
                        if userConfig.columns.allSatisfy({ !$0.isVisible }), let first = userConfig.columns.indices.first {
                            userConfig.columns[first].isVisible = true
                        }
                        saveUserConfig()
                    }
                }

                Section("Колонки таблицы") {
                    ForEach(Array(userConfig.columns.enumerated()), id: \.element.id) { index, column in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { userConfig.columns[index].isVisible },
                                set: { isOn in
                                    userConfig.columns[index].isVisible = isOn
                                    ensureAtLeastOneColumnVisible()
                                    saveUserConfig()
                                }
                            ))
                            .labelsHidden()
                            TextField("Название", text: Binding(
                                get: { userConfig.columns[index].title },
                                set: { value in
                                    userConfig.columns[index].title = value
                                    saveUserConfig()
                                }
                            ))
                        }
                    }
                }

                Section("Дата и логика") {
                    Picker("Формат даты", selection: $userConfig.dateFormat) {
                        ForEach(dateFormats, id: \.self) { format in
                            Text(format).tag(format)
                        }
                    }
                    .onChange(of: userConfig.dateFormat) { _, _ in saveUserConfig() }
                    Toggle("Автоставить дату при создании", isOn: $userConfig.useAutoDate)
                        .onChange(of: userConfig.useAutoDate) { _, _ in saveUserConfig() }
                    Toggle("Показывать дату продажи", isOn: $userConfig.showSaleDate)
                        .onChange(of: userConfig.showSaleDate) { _, _ in saveUserConfig() }
                }
            }
            .padding()
        }
    }

    private func moveSection(_ section: SidebarBaseSection, delta: Int) {
        guard let idx = sidebarConfig.orderedSections.firstIndex(of: section) else { return }
        let newIndex = idx + delta
        guard newIndex >= 0 && newIndex < sidebarConfig.orderedSections.count else { return }
        sidebarConfig.orderedSections.swapAt(idx, newIndex)
        saveSidebar()
    }

    private func ensureAtLeastOneColumnVisible() {
        if userConfig.columns.allSatisfy({ !$0.isVisible }), let first = userConfig.columns.indices.first {
            userConfig.columns[first].isVisible = true
        }
    }

    private func saveSidebar() {
        SidebarCustomizationStore.shared.save(sidebarConfig)
    }

    private func saveUserConfig() {
        ensureAtLeastOneColumnVisible()
        UserConfigStore.shared.save(userConfig)
    }
}
#endif

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
                                return viewModel.isFeatureEnabled(flag)
                            },
                            set: { enabled in
                                viewModel.setFeatureEnabled(flag, enabled: enabled)
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
                    Text("Включите или выключите функции приложения. Изменения применяются немедленно.")
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
