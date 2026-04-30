import SwiftUI
#if os(macOS)
import AppKit
#endif

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
    let currentUser: UserEntity?
    let onSignOut: (() -> Void)?
    let onRefreshUser: (() async -> Void)?
    let onDeleteAccount: (() async -> Void)?
    let onUpdateProfileName: ((String?) async -> Void)?
    let onChangePassword: ((String, String) async -> String?)?
    let onSendPasswordReset: ((String) async -> String?)?
    let onManualCatalogResync: (() async -> String)?
    let initialSection: SettingsViewModel.SettingsSection
    private let backupRepository = BackupRepositoryLocalImpl()
    
    init(
        backupService: BackupService,
        featureFlagService: FeatureFlagService,
        settingsService: SettingsService,
        recoveryState: RecoveryState,
        databaseService: DatabaseService,
        companyId: String? = nil,
        currentUser: UserEntity? = nil,
        onSignOut: (() -> Void)? = nil,
        onRefreshUser: (() async -> Void)? = nil,
        onDeleteAccount: (() async -> Void)? = nil,
        onUpdateProfileName: ((String?) async -> Void)? = nil,
        onChangePassword: ((String, String) async -> String?)? = nil,
        onSendPasswordReset: ((String) async -> String?)? = nil,
        onManualCatalogResync: (() async -> String)? = nil,
        initialSection: SettingsViewModel.SettingsSection = .general
    ) {
        self.backupService = backupService
        self.featureFlagService = featureFlagService
        self.settingsService = settingsService
        self.recoveryState = recoveryState
        self.databaseService = databaseService
        self.companyId = companyId
        self.currentUser = currentUser
        self.onSignOut = onSignOut
        self.onRefreshUser = onRefreshUser
        self.onDeleteAccount = onDeleteAccount
        self.onUpdateProfileName = onUpdateProfileName
        self.onChangePassword = onChangePassword
        self.onSendPasswordReset = onSendPasswordReset
        self.onManualCatalogResync = onManualCatalogResync
        self.initialSection = initialSection
        _selectedSection = State(initialValue: initialSection)
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
            } detail: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(NSColor.windowBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(NSColor.separatorColor).opacity(0.25), lineWidth: 1)
                        )
                    settingsDetailContent
                        .padding(12)
                }
                .padding(14)
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
                GeneralSettingsView(
                    viewModel: viewModel,
                    databaseService: databaseService,
                    companyId: companyId,
                    onManualCatalogResync: onManualCatalogResync
                )
            case .account:
                AccountSettingsView(
                    currentUser: currentUser,
                    onSignOut: onSignOut,
                    onRefreshUser: onRefreshUser,
                    onDeleteAccount: onDeleteAccount,
                    onUpdateProfileName: onUpdateProfileName,
                    onChangePassword: onChangePassword,
                    onSendPasswordReset: onSendPasswordReset
                )
            case .interface:
                #if os(macOS)
                InterfaceSettingsView()
                #else
                Text("Настройка интерфейса доступна на macOS")
                #endif
            case .features:
                FeatureFlagsSettingsView(featureFlagService: featureFlagService)
            case .accounting:
                AccountingSettingsView(viewModel: viewModel)
            case .data:
                BackupManagementViewNew(
                    backupRepository: backupRepository,
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
            GeneralSettingsView(
                viewModel: viewModel,
                databaseService: databaseService,
                companyId: companyId,
                onManualCatalogResync: onManualCatalogResync
            )
        case .account:
            AccountSettingsView(
                currentUser: currentUser,
                onSignOut: onSignOut,
                onRefreshUser: onRefreshUser,
                onDeleteAccount: onDeleteAccount,
                onUpdateProfileName: onUpdateProfileName,
                onChangePassword: onChangePassword,
                onSendPasswordReset: onSendPasswordReset
            )
        case .interface:
            #if os(macOS)
            InterfaceSettingsView()
            #else
            Text("Настройка интерфейса доступна на macOS")
            #endif
        case .features:
            FeatureFlagsSettingsView(featureFlagService: featureFlagService)
        case .accounting:
            AccountingSettingsView(viewModel: viewModel)
        case .data:
            BackupManagementViewNew(
                backupRepository: backupRepository,
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

#if os(macOS)
private struct SettingsSidebarAppKitRepresentable: NSViewRepresentable {
    let selectedSection: SettingsViewModel.SettingsSection
    let sections: [SettingsViewModel.SettingsSection]
    let onSelectSection: (SettingsViewModel.SettingsSection) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("section"))
        column.width = 240
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 42
        table.focusRingType = .none
        table.selectionHighlightStyle = .regular
        table.backgroundColor = .clear
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        context.coordinator.tableView = table

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.documentView = table
        scroll.contentView.postsBoundsChangedNotifications = true
        scroll.borderType = .noBorder
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.tableView?.reloadData()
        if let idx = sections.firstIndex(of: selectedSection) {
            context.coordinator.isProgrammaticSelection = true
            context.coordinator.tableView?.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            context.coordinator.isProgrammaticSelection = false
            context.coordinator.tableView?.scrollRowToVisible(idx)
        }
    }

    final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var parent: SettingsSidebarAppKitRepresentable
        weak var tableView: NSTableView?
        var isProgrammaticSelection = false

        init(_ parent: SettingsSidebarAppKitRepresentable) {
            self.parent = parent
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.sections.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard parent.sections.indices.contains(row) else { return nil }
            let section = parent.sections[row]
            let id = NSUserInterfaceItemIdentifier("settings-row")
            let cell = (tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView) ?? {
                let c = NSTableCellView()
                c.identifier = id
                let image = NSImageView()
                image.translatesAutoresizingMaskIntoConstraints = false
                image.imageScaling = .scaleProportionallyDown
                image.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
                image.tag = 1001

                let label = NSTextField(labelWithString: "")
                label.translatesAutoresizingMaskIntoConstraints = false
                label.font = .systemFont(ofSize: 13, weight: .medium)
                label.tag = 1002

                c.addSubview(image)
                c.addSubview(label)
                NSLayoutConstraint.activate([
                    image.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 12),
                    image.centerYAnchor.constraint(equalTo: c.centerYAnchor),
                    image.widthAnchor.constraint(equalToConstant: 18),
                    image.heightAnchor.constraint(equalToConstant: 18),

                    label.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 10),
                    label.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -10),
                    label.centerYAnchor.constraint(equalTo: c.centerYAnchor)
                ])
                return c
            }()

            (cell.viewWithTag(1001) as? NSImageView)?.image = NSImage(systemSymbolName: section.icon, accessibilityDescription: nil)
            (cell.viewWithTag(1002) as? NSTextField)?.stringValue = section.rawValue
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let row = tableView?.selectedRow, row >= 0, parent.sections.indices.contains(row) else { return }
            guard !isProgrammaticSelection else { return }
            let target = parent.sections[row]
            guard target != parent.selectedSection else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.parent.onSelectSection(target)
            }
        }
    }
}
#endif

private struct AccountSettingsView: View {
    let currentUser: UserEntity?
    let onSignOut: (() -> Void)?
    let onRefreshUser: (() async -> Void)?
    let onDeleteAccount: (() async -> Void)?
    let onUpdateProfileName: ((String?) async -> Void)?
    let onChangePassword: ((String, String) async -> String?)?
    let onSendPasswordReset: ((String) async -> String?)?

    @State private var displayNameDraft = ""
    @State private var isBusy = false
    @State private var showDeleteConfirm = false
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @State private var isShowingPasswordSheet = false
    @State private var isSendingReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox(label: sectionLabel("Профиль", systemImage: "person.crop.circle")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Это имя будет отображаться рядом с вашими действиями.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Например, Виктор", text: $displayNameDraft)
                            .textFieldStyle(.roundedBorder)
                        HStack(spacing: 8) {
                            Button("Сохранить") {
                                Task { await saveProfileName() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isBusy || onUpdateProfileName == nil)

                            Button("Обновить из облака") {
                                Task { await refreshProfile() }
                            }
                            .disabled(isBusy || onRefreshUser == nil)
                            
                            if isBusy {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                GroupBox(label: sectionLabel("Аккаунт", systemImage: "envelope.fill")) {
                    VStack(spacing: 6) {
                        infoRow("Электронная почта", value: currentUser?.email ?? "—")
                        infoRow("Способ входа", value: currentUser?.provider.displayName ?? "—")
                        infoRow("Роль в команде", value: currentUser?.role.displayName ?? "—")
                    }
                    .padding(.vertical, 4)
                }

                GroupBox(label: sectionLabel("Безопасность", systemImage: "lock.shield.fill")) {
                    VStack(alignment: .leading, spacing: 10) {
                        passwordSection
                        
                        Divider()
                        
                        Button {
                            onSignOut?()
                        } label: {
                            Label("Выйти из аккаунта", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderless)
                        .disabled(onSignOut == nil)
                    }
                    .padding(.vertical, 4)
                }
                
                GroupBox(label: sectionLabel("Опасная зона", systemImage: "exclamationmark.triangle.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Удаление навсегда уберёт ваш профиль и доступ к данным компании.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Удалить аккаунт", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(isBusy || onDeleteAccount == nil)
                    }
                    .padding(.vertical, 4)
                }

                if let statusMessage {
                    Label(statusMessage, systemImage: statusIsError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(statusIsError ? .red : .green)
                        .font(.caption)
                        .padding(.horizontal, 4)
                }
            }
            .padding()
        }
        .onAppear {
            displayNameDraft = currentUser?.displayName ?? ""
        }
        .confirmationDialog("Удалить аккаунт?", isPresented: $showDeleteConfirm) {
            Button("Удалить навсегда", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить. Будут удалены ваш профиль и привязки к компании.")
        }
        .sheet(isPresented: $isShowingPasswordSheet) {
            ChangePasswordSheet(
                onChange: { current, new in
                    guard let onChangePassword else { return "Смена пароля недоступна." }
                    return await onChangePassword(current, new)
                },
                onCompleted: { success in
                    statusIsError = !success
                    statusMessage = success ? "Пароль обновлён" : nil
                }
            )
        }
    }
    
    @ViewBuilder
    private var passwordSection: some View {
        switch currentUser?.provider {
        case .email:
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    isShowingPasswordSheet = true
                } label: {
                    Label("Изменить пароль", systemImage: "key.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .disabled(onChangePassword == nil)
                
                Button {
                    Task { await sendResetEmail() }
                } label: {
                    Label(isSendingReset ? "Отправляем письмо…" : "Прислать письмо для сброса", systemImage: "envelope.arrow.triangle.branch")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .disabled(isSendingReset || onSendPasswordReset == nil || (currentUser?.email ?? "").isEmpty)
            }
        case .google:
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Вход через Google. Пароль меняется в настройках вашего Google-аккаунта.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .apple:
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Вход через Apple ID. Пароль меняется в настройках Apple ID.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }

    @ViewBuilder
    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.callout)
    }

    private func saveProfileName() async {
        guard let onUpdateProfileName else { return }
        isBusy = true
        await onUpdateProfileName(displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : displayNameDraft)
        isBusy = false
        statusIsError = false
        statusMessage = "Имя сохранено"
    }

    private func refreshProfile() async {
        guard let onRefreshUser else { return }
        isBusy = true
        await onRefreshUser()
        isBusy = false
        statusIsError = false
        statusMessage = "Профиль загружен из облака"
    }

    private func deleteAccount() async {
        guard let onDeleteAccount else { return }
        isBusy = true
        await onDeleteAccount()
        isBusy = false
        statusIsError = false
        statusMessage = "Аккаунт удалён"
    }
    
    private func sendResetEmail() async {
        guard let onSendPasswordReset, let email = currentUser?.email, !email.isEmpty else { return }
        isSendingReset = true
        let error = await onSendPasswordReset(email)
        isSendingReset = false
        if let error {
            statusIsError = true
            statusMessage = error
        } else {
            statusIsError = false
            statusMessage = "Письмо для сброса пароля отправлено на \(email)"
        }
    }
}

private struct ChangePasswordSheet: View {
    let onChange: (String, String) async -> String?
    let onCompleted: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorText: String?
    @State private var isWorking = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundStyle(.tint)
                Text("Изменить пароль")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Текущий пароль")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("", text: $currentPassword)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Новый пароль")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("Минимум 6 символов", text: $newPassword)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Повторите новый пароль")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
            }
            
            if let errorText {
                Label(errorText, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            HStack {
                Spacer()
                Button("Отмена") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button {
                    Task { await submit() }
                } label: {
                    if isWorking {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Сохранить пароль")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit || isWorking)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
    
    private var canSubmit: Bool {
        !currentPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword
    }
    
    private func submit() async {
        if newPassword != confirmPassword {
            errorText = "Пароли не совпадают"
            return
        }
        if newPassword.count < 6 {
            errorText = "Минимум 6 символов"
            return
        }
        isWorking = true
        errorText = nil
        let error = await onChange(currentPassword, newPassword)
        isWorking = false
        if let error {
            errorText = error
            onCompleted(false)
        } else {
            onCompleted(true)
            dismiss()
        }
    }
}

// MARK: - General Settings

private struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let databaseService: DatabaseService
    let companyId: String?
    let onManualCatalogResync: (() async -> String)?
    @State private var showClearAccountingConfirm = false
    @State private var showDeleteAllDataConfirm = false
    @State private var isDeleting = false
    @State private var isManualResyncing = false
    @State private var statusMessage: String?
    @State private var manualResyncMessage: String?

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

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Где хранятся данные")
                                .font(.subheadline)
                            Text(databaseService.databaseFileURL.path)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        #if os(macOS)
                        Button("Открыть в Finder") {
                            NSWorkspace.shared.selectFile(
                                databaseService.databaseFileURL.path,
                                inFileViewerRootedAtPath: databaseService.databaseFileURL.deletingLastPathComponent().path
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        #endif
                    }

                    if isDeleting {
                        HStack {
                            ProgressView()
                            Text("Удаляем данные…")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button(role: .destructive) {
                            showDeleteAllDataConfirm = true
                        } label: {
                            Label("Стереть всё на этом устройстве", systemImage: "externaldrive.badge.xmark")
                        }
                        .disabled(isDeleting)
                    }
                } header: {
                    Text("Локальные данные")
                } footer: {
                    Text("Удалит все моторы, категории, бухгалтерию и записи на этом устройстве. Копии в облаке остаются.")
                }

                Section {
                    if isManualResyncing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Выполняем cloud resync каталога…")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        runManualCatalogResync()
                    } label: {
                        Label("Ручной Cloud Resync каталога", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(isManualResyncing)

                    if let manualResyncMessage {
                        Text(manualResyncMessage)
                            .foregroundColor(manualResyncMessage.contains("Не удалось") ? .red : .green)
                    }
                } header: {
                    Text("Облачный каталог (Firestore)")
                } footer: {
                    Text("Запускает полный ручной sync brands/engines/motors в Firestore. Используйте как repair/resync по необходимости.")
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
            .confirmationDialog(
                "Удалить все локальные данные?",
                isPresented: $showDeleteAllDataConfirm
            ) {
                Button("Удалить всё", role: .destructive) {
                    deleteAllLocalData()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Будут удалены все моторы, категории, бухгалтерия и разделы из локальной базы. Данные в облаке сохранятся. Это действие необратимо.")
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

    private func deleteAllLocalData() {
        isDeleting = true
        statusMessage = nil
        Task {
            do {
                try databaseService.deleteAllData()
                await MainActor.run {
                    isDeleting = false
                    statusMessage = "Все локальные данные удалены. Перезапустите приложение для применения изменений."
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    statusMessage = "Не удалось удалить данные: \(error.localizedDescription)"
                }
            }
        }
    }

    private func runManualCatalogResync() {
        guard let onManualCatalogResync else {
            manualResyncMessage = "Не удалось запустить resync: обработчик не настроен"
            return
        }

        isManualResyncing = true
        manualResyncMessage = nil
        Task {
            let result = await onManualCatalogResync()
            await MainActor.run {
                isManualResyncing = false
                manualResyncMessage = result
            }
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
    @ObservedObject var featureFlagService: FeatureFlagService
    @State private var localFlags: [FeatureFlagService.Flag: Bool] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Дополнительные возможности")
                    .font(.title3.weight(.semibold))
                Text("Включайте новые возможности приложения по одной. Изменения применяются сразу.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(FeatureFlagService.Flag.allCases, id: \.rawValue) { flag in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(featureTitle(flag))
                                .font(.headline)
                            Text(flag.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { localFlags[flag] ?? featureFlagService.isEnabled(flag) },
                            set: { enabled in
                                localFlags[flag] = enabled
                                do {
                                    try featureFlagService.setEnabled(flag, enabled: enabled)
                                } catch {
                                    localFlags[flag] = featureFlagService.isEnabled(flag)
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
            }
            .padding()
            .onAppear {
                var snapshot: [FeatureFlagService.Flag: Bool] = [:]
                for flag in FeatureFlagService.Flag.allCases {
                    snapshot[flag] = featureFlagService.isEnabled(flag)
                }
                localFlags = snapshot
            }
        }
    }
    
    private func featureTitle(_ flag: FeatureFlagService.Flag) -> String {
        flag.rawValue
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
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
                    Toggle("Создавать копии автоматически", isOn: $localBackup.isAutoBackupEnabled)
                        .onChange(of: localBackup.isAutoBackupEnabled) { _, _ in
                            viewModel.updateBackupSettings(localBackup)
                        }
                    
                    Picker("Как часто", selection: $localBackup.backupFrequency) {
                        ForEach(BackupSettings.BackupFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .onChange(of: localBackup.backupFrequency) { _, _ in
                        viewModel.updateBackupSettings(localBackup)
                    }
                    .disabled(!localBackup.isAutoBackupEnabled)
                    
                    Stepper("Хранить копий: \(localBackup.maxBackupCount)", value: $localBackup.maxBackupCount, in: 5...100, step: 5)
                        .onChange(of: localBackup.maxBackupCount) { _, _ in
                            viewModel.updateBackupSettings(localBackup)
                        }
                    
                    Toggle("Создавать копию перед импортом", isOn: $localBackup.backupBeforeImport)
                        .onChange(of: localBackup.backupBeforeImport) { _, _ in
                            viewModel.updateBackupSettings(localBackup)
                        }
                    
                    Button("Создать копию сейчас") {
                        try? viewModel.createBackupNow()
                    }
                } header: {
                    Text("Резервные копии")
                } footer: {
                    if let lastBackup = viewModel.lastBackupDate {
                        Text("Последняя копия: \(formatDate(lastBackup))")
                    } else {
                        Text("Копии ещё не создавались")
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
                        Text("Копий пока нет")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Последние копии")
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
                    Picker("Если строка уже существует", selection: $localImportExport.importConflictBehavior) {
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
                    Text("Что делать с дубликатами при загрузке Excel-файла.")
                }
                
                Section {
                    TextField("Формат даты", text: $localImportExport.exportDateFormat)
                        .onChange(of: localImportExport.exportDateFormat) { _, _ in
                            viewModel.updateImportExportSettings(localImportExport)
                        }
                    
                    Toggle("Включать проданные моторы", isOn: $localImportExport.exportSoldMotors)
                        .onChange(of: localImportExport.exportSoldMotors) { _, _ in
                            viewModel.updateImportExportSettings(localImportExport)
                        }
                    
                    Toggle("Включать удалённые моторы", isOn: $localImportExport.exportDeletedMotors)
                        .onChange(of: localImportExport.exportDeletedMotors) { _, _ in
                            viewModel.updateImportExportSettings(localImportExport)
                        }
                } header: {
                    Text("Экспорт")
                } footer: {
                    Text("Эти параметры применяются при экспорте в Excel по умолчанию.")
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
                    Toggle("Расширенный режим", isOn: $localAdvanced.developerModeEnabled)
                        .onChange(of: localAdvanced.developerModeEnabled) { _, _ in
                            viewModel.updateAdvancedSettings(localAdvanced)
                        }
                    
                    Toggle("Подробные журналы для поддержки", isOn: $localAdvanced.enableDebugLogging)
                        .onChange(of: localAdvanced.enableDebugLogging) { _, _ in
                            viewModel.updateAdvancedSettings(localAdvanced)
                        }
                        .disabled(!localAdvanced.developerModeEnabled)
                    
                    Toggle("Показывать диагностические сообщения", isOn: $localAdvanced.showMigrationInfo)
                        .onChange(of: localAdvanced.showMigrationInfo) { _, _ in
                            viewModel.updateAdvancedSettings(localAdvanced)
                        }
                        .disabled(!localAdvanced.developerModeEnabled)
                } header: {
                    Text("Расширенные настройки")
                } footer: {
                    Text("Включайте, только если просит служба поддержки. Журналы помогут быстрее найти причину проблемы.")
                }
                
                Section {
                    Button("Вернуть настройки по умолчанию") {
                        viewModel.resetToDefaults()
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("Сброс")
                } footer: {
                    Text("Восстановит все настройки приложения к значениям из коробки. Ваши данные не пострадают.")
                }
                
                Section {
                    HStack {
                        Text("Версия приложения")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("О приложении")
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

// MARK: - Accounting Settings

private struct AccountingSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var localAccounting: AccountingSettings
    @State private var employeeDraft: String = ""
    @State private var specificDraft: String = ""

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        _localAccounting = State(initialValue: viewModel.settings.accounting)
    }

    var body: some View {
        ScrollView {
            Form {
                Section {
                    Toggle("Бухгалтерия настроена", isOn: $localAccounting.isConfigured)
                        .onChange(of: localAccounting.isConfigured) { _, _ in
                            save()
                        }
                } header: {
                    Text("Первый запуск")
                } footer: {
                    Text("Если переключатель выключен — при открытии раздела «Бухгалтерия» появится короткий помощник для настройки.")
                }

                Section {
                    HStack {
                        TextField("Имя сотрудника", text: $employeeDraft)
                        Button("Добавить") {
                            addEmployee()
                        }
                        .disabled(employeeDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if localAccounting.employees.isEmpty {
                        Text("Пока пусто").foregroundStyle(.secondary)
                    } else {
                        ForEach(localAccounting.employees, id: \.self) { name in
                            HStack {
                                Text(name)
                                Spacer()
                                Button(role: .destructive) {
                                    localAccounting.employees.removeAll { $0 == name }
                                    save()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                } header: {
                    Text("Сотрудники")
                }

                Section {
                    HStack {
                        TextField("Например: аванс, касса, логистика...", text: $specificDraft)
                        Button("Добавить") {
                            addSpecific()
                        }
                        .disabled(specificDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if localAccounting.specifics.isEmpty {
                        Text("Пока пусто").foregroundStyle(.secondary)
                    } else {
                        ForEach(localAccounting.specifics, id: \.self) { value in
                            HStack {
                                Text(value)
                                Spacer()
                                Button(role: .destructive) {
                                    localAccounting.specifics.removeAll { $0 == value }
                                    save()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                } header: {
                    Text("Специфика бухгалтерии")
                }
            }
            .padding()
            .onChange(of: viewModel.settings.accounting) { _, newValue in
                if localAccounting != newValue {
                    localAccounting = newValue
                }
            }
        }
    }

    private func addEmployee() {
        let value = employeeDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if !localAccounting.employees.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            localAccounting.employees.append(value)
            localAccounting.employees.sort()
            save()
        }
        employeeDraft = ""
    }

    private func addSpecific() {
        let value = specificDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if !localAccounting.specifics.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            localAccounting.specifics.append(value)
            localAccounting.specifics.sort()
            save()
        }
        specificDraft = ""
    }

    private func save() {
        viewModel.updateAccountingSettings(localAccounting)
    }
}
