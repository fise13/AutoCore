import SwiftUI
import AppKit
import Combine

/// Новый UI для управления бэкапами с ZIP архивами
struct BackupManagementViewNew: View {
    @StateObject private var viewModel: BackupManagementViewModel
    @State private var isShowingRestoreAlert = false
    @State private var isShowingDeleteAlert = false
    @State private var selectedBackup: BackupEntity?
    @State private var errorMessage: String?
    
    init(
        backupRepository: BackupRepository,
        databaseService: DatabaseService,
        recoveryState: RecoveryState?
    ) {
        _viewModel = StateObject(wrappedValue: BackupManagementViewModel(
            backupRepository: backupRepository,
            databaseService: databaseService,
            recoveryState: recoveryState
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок и действия
            headerSection
            
            Divider()
            
            // Основной контент
            if viewModel.isLoading {
                loadingView
            } else if viewModel.backups.isEmpty {
                emptyStateView
            } else {
                backupsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Восстановить из бэкапа?", isPresented: $isShowingRestoreAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Восстановить", role: .destructive) {
                if let backup = selectedBackup {
                    restoreBackup(backup)
                }
            }
        } message: {
            if let backup = selectedBackup {
                Text("База данных будет заменена на версию от \(formatDate(backup.createdAt)).\nТекущая БД будет сохранена как резервная копия.\n\nТребуется перезапуск приложения.")
            }
        }
        .alert("Удалить бэкап?", isPresented: $isShowingDeleteAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                if let backup = selectedBackup {
                    deleteBackup(backup)
                }
            }
        } message: {
            if let backup = selectedBackup {
                Text("Бэкап от \(formatDate(backup.createdAt)) будет удалён без возможности восстановления.")
            }
        }
        .alert("Ошибка", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") {
                errorMessage = nil
            }
        } message: { message in
            Text(message)
        }
        .onAppear {
            viewModel.loadBackups()
        }
    }
    
    // MARK: - Components
    
    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Бэкапы базы данных")
                    .font(.system(size: 28, weight: .bold))
                Text("Создавайте резервные копии для защиты данных")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: openBackupsFolder) {
                    Label("Открыть папку", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: createBackup) {
                    if viewModel.isCreatingBackup {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .controlSize(.small)
                            Text("Создание...")
                        }
                    } else {
                        Label("Создать бэкап", systemImage: "plus.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isCreatingBackup)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Загрузка бэкапов...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "externaldrive.badge.timemachine")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating)
            
            VStack(spacing: 8) {
                Text("Нет бэкапов")
                    .font(.system(size: 24, weight: .semibold))
                
                Text("Создайте первый бэкап для защиты данных")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: createBackup) {
                if viewModel.isCreatingBackup {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Создание бэкапа...")
                    }
                } else {
                    Label("Создать бэкап", systemImage: "plus.circle.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isCreatingBackup)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var backupsList: some View {
        VStack(spacing: 0) {
            // Информация о количестве
            HStack {
                Text("Всего бэкапов: \(viewModel.backups.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Таблица бэкапов (Table имеет встроенный скроллинг)
            Table(viewModel.backups, selection: .constant(nil)) {
                TableColumn("Дата и время") { backup in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDate(backup.createdAt))
                            .font(.system(size: 13, weight: .medium))
                        Text(formatTime(backup.createdAt))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .width(min: 150, ideal: 180)
                
                TableColumn("Размер") { backup in
                    Text(formatSize(backup.size))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .width(min: 80, ideal: 90)
                
                TableColumn("Версия приложения") { backup in
                    Text(backup.appVersion)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .width(min: 120, ideal: 130)
                
                TableColumn("Устройство") { backup in
                    Text(backup.deviceName)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .width(min: 120, ideal: 150)
                
                TableColumn("Схема БД") { backup in
                    Text("v\(backup.schemaVersion)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .width(min: 70, ideal: 80)
                
                TableColumn("Действия") { backup in
                    HStack(spacing: 8) {
                        Button(action: {
                            selectedBackup = backup
                            isShowingRestoreAlert = true
                        }) {
                            Label("Восстановить", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: {
                            selectedBackup = backup
                            isShowingDeleteAlert = true
                        }) {
                            Label("Удалить", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                    }
                    .padding(.vertical, 2)
                }
                .width(min: 160, ideal: 180)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func createBackup() {
        viewModel.createBackup { result in
            switch result {
            case .success:
                viewModel.loadBackups()
            case .failure(let error):
                errorMessage = "Ошибка создания бэкапа: \(error.localizedDescription)"
            }
        }
    }
    
    private func restoreBackup(_ backup: BackupEntity) {
        viewModel.restoreBackup(backup: backup) { result in
            switch result {
            case .success:
                // Показываем сообщение о необходимости перезапуска
                let alert = NSAlert()
                alert.messageText = "Бэкап восстановлен"
                alert.informativeText = "Пожалуйста, перезапустите приложение для применения изменений."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
                viewModel.loadBackups()
            case .failure(let error):
                errorMessage = "Ошибка восстановления: \(error.localizedDescription)"
            }
        }
    }
    
    private func deleteBackup(_ backup: BackupEntity) {
        viewModel.deleteBackup(backup: backup) { result in
            switch result {
            case .success:
                viewModel.loadBackups()
            case .failure(let error):
                errorMessage = "Ошибка удаления: \(error.localizedDescription)"
            }
        }
    }
    
    private func openBackupsFolder() {
        Task {
            do {
                let backupsDir = try viewModel.getBackupsDirectory()
                NSWorkspace.shared.open(backupsDir)
            } catch {
                errorMessage = "Не удалось открыть папку: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Formatters
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.formattingContext = .standalone
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - ViewModel

@MainActor
final class BackupManagementViewModel: ObservableObject {
    @Published var backups: [BackupEntity] = []
    @Published var isLoading = false
    @Published var isCreatingBackup = false
    
    let backupRepository: BackupRepository
    private let databaseService: DatabaseService
    private let recoveryState: RecoveryState?
    
    private let createBackupUseCase: CreateBackupUseCase
    private let restoreBackupUseCase: RestoreBackupUseCase
    private let deleteBackupUseCase: DeleteBackupUseCase
    private let listBackupsUseCase: ListBackupsUseCase
    
    init(
        backupRepository: BackupRepository,
        databaseService: DatabaseService,
        recoveryState: RecoveryState?
    ) {
        self.backupRepository = backupRepository
        self.databaseService = databaseService
        self.recoveryState = recoveryState
        
        self.createBackupUseCase = CreateBackupUseCase(
            backupRepository: backupRepository,
            databaseService: databaseService,
            recoveryState: recoveryState
        )
        
        self.restoreBackupUseCase = RestoreBackupUseCase(
            backupRepository: backupRepository,
            databaseService: databaseService,
            recoveryState: recoveryState
        )
        
        self.deleteBackupUseCase = DeleteBackupUseCase(
            backupRepository: backupRepository
        )
        
        self.listBackupsUseCase = ListBackupsUseCase(
            backupRepository: backupRepository
        )
    }
    
    func loadBackups() {
        isLoading = true
        Task {
            defer { isLoading = false }
            
            do {
                backups = try listBackupsUseCase.execute()
            } catch {
                print("Failed to load backups: \(error)")
            }
        }
    }
    
    func createBackup(completion: @escaping (Result<Void, Error>) -> Void) {
        isCreatingBackup = true
        Task {
            defer { isCreatingBackup = false }
            
            do {
                _ = try await createBackupUseCase.execute()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func restoreBackup(backup: BackupEntity, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try restoreBackupUseCase.execute(backup: backup)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func deleteBackup(backup: BackupEntity, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try deleteBackupUseCase.execute(backup: backup)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func getBackupsDirectory() throws -> URL {
        guard let localRepo = backupRepository as? BackupRepositoryLocalImpl else {
            throw BackupError.unableToCreateArchive
        }
        return try localRepo.getBackupsDirectory()
    }
}
