//
//  IOSSettingsView.swift
//  AutoCoreAccounting
//
//  Настройки в стиле Flowly для iOS.
//

import SwiftUI

#if os(iOS)

struct IOSSettingsView: View {
    @ObservedObject var backupService: BackupService
    @ObservedObject var featureFlagService: FeatureFlagService
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var recoveryState: RecoveryState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: SettingsViewModel
    @State private var localImportExport: ImportExportSettings
    @State private var localWorkflow: WorkflowSettings
    @State private var localAdvanced: AdvancedSettings

    let databaseService: DatabaseService
    let companyId: String?
    @State private var showClearAccountingConfirm = false
    @State private var clearAccountingMessage: String?

    init(
        backupService: BackupService,
        featureFlagService: FeatureFlagService,
        settingsService: SettingsService,
        recoveryState: RecoveryState,
        databaseService: DatabaseService
        , companyId: String? = nil
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
        _localImportExport = State(initialValue: settingsService.settings.importExport)
        _localWorkflow = State(initialValue: settingsService.settings.workflow)
        _localAdvanced = State(initialValue: settingsService.settings.advanced)
    }

    @AppStorage("themePreference") private var themePreferenceRaw: Int = ThemePreference.system.rawValue

    var body: some View {
        ZStack {
            IOSScreenBackground()
            VStack(spacing: 0) {
                headerSection
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.x3) {
                        appearanceCard
                        generalCard
                        featuresCard
                        dataCard
                        importExportCard
                        workflowCard
                        advancedCard
                        accountingDangerCard
                    }
                    .padding(Spacing.x3)
                }
            }
        }
        .onChange(of: viewModel.settings.importExport) { _, _ in
            localImportExport = viewModel.settings.importExport
        }
        .onChange(of: viewModel.settings.workflow) { _, _ in
            localWorkflow = viewModel.settings.workflow
        }
        .onChange(of: viewModel.settings.advanced) { _, _ in
            localAdvanced = viewModel.settings.advanced
        }
    }

    private var headerSection: some View {
        ZStack(alignment: .topTrailing) {
            IOSPalette.headerGradient
                .frame(height: 140)
                .ignoresSafeArea(edges: .top)
            VStack(alignment: .leading, spacing: 4) {
                Text("Настройки")
                    .font(IOSDesign.Typography.title)
                    .foregroundStyle(.white)
                Text("Настройки приложения")
                    .font(IOSDesign.Typography.subtitle)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.x3)
            .padding(.top, 60)
            .padding(.bottom, Spacing.x3)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.top, 56)
            .padding(.trailing, Spacing.x3)
        }
    }

    private var appearanceCard: some View {
        IOSFlowlyCard {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("Внешний вид")
                    .font(IOSDesign.Typography.subtitle.weight(.semibold))
                    .foregroundStyle(IOSPalette.textPrimary)

                HStack(spacing: 10) {
                    ForEach([ThemePreference.system, .light, .dark], id: \.rawValue) { pref in
                        let isSelected = themePreferenceRaw == pref.rawValue
                        Button {
                            IOSHaptics.selection()
                            withAnimation(IOSMotion.quick) {
                                themePreferenceRaw = pref.rawValue
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: pref == .system ? "gear" : pref == .light ? "sun.max.fill" : "moon.fill")
                                    .font(.system(size: 20))
                                Text(pref.displayName)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(isSelected ? .white : IOSPalette.textPrimary)
                            .background(
                                RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
                                    .fill(isSelected ? IOSPalette.flowlyBlue : IOSPalette.backgroundElevated)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
                                            .stroke(isSelected ? Color.clear : IOSPalette.border, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var generalCard: some View {
        IOSFlowlyCard {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("Состояние системы")
                    .font(IOSDesign.Typography.subtitle.weight(.semibold))
                    .foregroundStyle(IOSPalette.textPrimary)
                if viewModel.isRecoveryMode {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(IOSPalette.warning)
                        Text(viewModel.recoveryMessage ?? "Режим восстановления активен")
                            .font(IOSDesign.Typography.body)
                            .foregroundStyle(IOSPalette.textSecondary)
                    }
                    .padding(Spacing.x2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                            .fill(IOSPalette.warning.opacity(0.15))
                    )
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(IOSPalette.positive)
                        Text("Приложение работает нормально")
                            .font(IOSDesign.Typography.body)
                            .foregroundStyle(IOSPalette.textPrimary)
                    }
                }
            }
        }
    }

    private var featuresCard: some View {
        IOSFlowlyCard {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("Управление функциями")
                    .font(IOSDesign.Typography.subtitle.weight(.semibold))
                    .foregroundStyle(IOSPalette.textPrimary)
                ForEach(FeatureFlagService.Flag.allCases, id: \.rawValue) { flag in
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: Binding(
                            get: {
                                return viewModel.isFeatureEnabled(flag)
                            },
                            set: { viewModel.setFeatureEnabled(flag, enabled: $0) }
                        )) {
                            Text(flag.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(IOSDesign.Typography.body.weight(.medium))
                                .foregroundStyle(IOSPalette.textPrimary)
                        }
                        .tint(IOSPalette.flowlyBlue)
                        Text(flag.description)
                            .font(.caption)
                            .foregroundStyle(IOSPalette.textSecondary)
                    }
                    .padding(.vertical, 4)
                    if flag != FeatureFlagService.Flag.allCases.last {
                        Divider().overlay(IOSPalette.border)
                    }
                }
            }
        }
    }

    private var dataCard: some View {
        IOSFlowlyCard {
            BackupManagementViewNew(
                backupRepository: BackupRepositoryLocalImpl(),
                databaseService: databaseService,
                recoveryState: recoveryState
            )
        }
    }

    private var importExportCard: some View {
        IOSFlowlyCard {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("Импорт / Экспорт")
                    .font(IOSDesign.Typography.subtitle.weight(.semibold))
                    .foregroundStyle(IOSPalette.textPrimary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Поведение при конфликтах")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(IOSPalette.textSecondary)
                    Picker("", selection: $localImportExport.importConflictBehavior) {
                        ForEach(ImportExportSettings.ImportConflictBehavior.allCases, id: \.self) { behavior in
                            Text(behavior.displayName).tag(behavior)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: localImportExport.importConflictBehavior) { _, _ in
                        viewModel.updateImportExportSettings(localImportExport)
                    }
                }

                Divider().overlay(IOSPalette.border)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Формат даты")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(IOSPalette.textSecondary)
                    TextField("yyyy-MM-dd", text: $localImportExport.exportDateFormat)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: localImportExport.exportDateFormat) { _, _ in
                            viewModel.updateImportExportSettings(localImportExport)
                        }
                }

                VStack(spacing: 12) {
                    Toggle("Экспортировать проданные моторы", isOn: $localImportExport.exportSoldMotors)
                        .onChange(of: localImportExport.exportSoldMotors) { _, _ in
                            viewModel.updateImportExportSettings(localImportExport)
                        }
                        .tint(IOSPalette.flowlyBlue)
                    Toggle("Экспортировать удаленные моторы", isOn: $localImportExport.exportDeletedMotors)
                        .onChange(of: localImportExport.exportDeletedMotors) { _, _ in
                            viewModel.updateImportExportSettings(localImportExport)
                        }
                        .tint(IOSPalette.flowlyBlue)
                }
            }
        }
    }

    private var workflowCard: some View {
        IOSFlowlyCard {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("Рабочий процесс")
                    .font(IOSDesign.Typography.subtitle.weight(.semibold))
                    .foregroundStyle(IOSPalette.textPrimary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Фильтр при запуске")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(IOSPalette.textSecondary)
                    Picker("", selection: Binding(
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
                    .pickerStyle(.menu)
                }

                VStack(spacing: 12) {
                    Toggle("Автопереход к проданным после продажи", isOn: $localWorkflow.autoSwitchToSoldAfterSell)
                        .onChange(of: localWorkflow.autoSwitchToSoldAfterSell) { _, _ in
                            viewModel.updateWorkflowSettings(localWorkflow)
                        }
                        .tint(IOSPalette.flowlyBlue)
                    Toggle("Запоминать последний бренд", isOn: $localWorkflow.rememberLastBrand)
                        .onChange(of: localWorkflow.rememberLastBrand) { _, _ in
                            viewModel.updateWorkflowSettings(localWorkflow)
                        }
                        .tint(IOSPalette.flowlyBlue)
                    Toggle("Запоминать последний двигатель", isOn: $localWorkflow.rememberLastEngine)
                        .onChange(of: localWorkflow.rememberLastEngine) { _, _ in
                            viewModel.updateWorkflowSettings(localWorkflow)
                        }
                        .tint(IOSPalette.flowlyBlue)
                }
            }
        }
    }

    private var advancedCard: some View {
        IOSFlowlyCard {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("Продвинутые")
                    .font(IOSDesign.Typography.subtitle.weight(.semibold))
                    .foregroundStyle(IOSPalette.textPrimary)

                VStack(spacing: 12) {
                    Toggle("Режим разработчика", isOn: $localAdvanced.developerModeEnabled)
                        .onChange(of: localAdvanced.developerModeEnabled) { _, _ in
                            viewModel.updateAdvancedSettings(localAdvanced)
                        }
                        .tint(IOSPalette.flowlyBlue)
                    Toggle("Отладочное логирование", isOn: $localAdvanced.enableDebugLogging)
                        .onChange(of: localAdvanced.enableDebugLogging) { _, _ in
                            viewModel.updateAdvancedSettings(localAdvanced)
                        }
                        .tint(IOSPalette.flowlyBlue)
                        .disabled(!localAdvanced.developerModeEnabled)
                    Toggle("Показывать информацию о миграциях", isOn: $localAdvanced.showMigrationInfo)
                        .onChange(of: localAdvanced.showMigrationInfo) { _, _ in
                            viewModel.updateAdvancedSettings(localAdvanced)
                        }
                        .tint(IOSPalette.flowlyBlue)
                        .disabled(!localAdvanced.developerModeEnabled)
                }

                Divider().overlay(IOSPalette.border)

                Button("Сбросить настройки по умолчанию") {
                    viewModel.resetToDefaults()
                }
                .font(IOSDesign.Typography.body.weight(.medium))
                .foregroundStyle(IOSPalette.negative)
                .frame(maxWidth: .infinity)

                Divider().overlay(IOSPalette.border)

                HStack {
                    Text("Версия приложения")
                        .font(IOSDesign.Typography.body)
                        .foregroundStyle(IOSPalette.textPrimary)
                    Spacer()
                    Text("1.0")
                        .font(IOSDesign.Typography.body)
                        .foregroundStyle(IOSPalette.textSecondary)
                }
                HStack {
                    Text("Версия схемы БД")
                        .font(IOSDesign.Typography.body)
                        .foregroundStyle(IOSPalette.textPrimary)
                    Spacer()
                    Text("9")
                        .font(IOSDesign.Typography.body)
                        .foregroundStyle(IOSPalette.textSecondary)
                }
            }
        }
    }

    private var accountingDangerCard: some View {
        IOSFlowlyCard {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("Бухгалтерия")
                    .font(IOSDesign.Typography.subtitle.weight(.semibold))
                    .foregroundStyle(IOSPalette.textPrimary)

                Text("Полностью удалит все финансовые операции текущей компании.")
                    .font(.footnote)
                    .foregroundStyle(IOSPalette.textSecondary)

                Button {
                    showClearAccountingConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Очистить всю бухгалтерию")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                            .fill(IOSPalette.negative)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog("Очистить всю бухгалтерию?", isPresented: $showClearAccountingConfirm) {
            Button("Очистить", role: .destructive) {
                clearAllAccounting()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие удалит все операции без возможности восстановления.")
        }
        .overlay(alignment: .top) {
            if let clearAccountingMessage {
                IOSStatusBanner(type: .error, message: clearAccountingMessage, onDismiss: { self.clearAccountingMessage = nil })
                    .padding(.horizontal, Spacing.x3)
            }
        }
    }

    private func clearAllAccounting() {
        do {
            try databaseService.clearFinancialOperations(companyId: companyId)
            clearAccountingMessage = "Бухгалтерия очищена"
        } catch {
            clearAccountingMessage = "Не удалось очистить бухгалтерию: \(error.localizedDescription)"
        }
    }
}

#endif
