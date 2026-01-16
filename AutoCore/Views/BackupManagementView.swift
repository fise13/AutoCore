import SwiftUI

struct BackupManagementView: View {
    @ObservedObject var backupService: BackupService
    @State private var isShowingRestoreAlert = false
    @State private var selectedBackup: BackupService.BackupInfo?
    @State private var isCreatingBackup = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Заголовок
            HStack {
                Text("Управление бэкапами")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: createBackup) {
                    Label("Создать бэкап", systemImage: "plus.circle.fill")
                }
                .disabled(isCreatingBackup)
            }
            
            // Информация о последнем бэкапе
            if let lastBackup = backupService.lastBackup {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Последний бэкап: \(formatDate(lastBackup))")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Бэкапы не создавались")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // Список бэкапов
            if backupService.backups.isEmpty {
                ContentUnavailableView(
                    "Нет бэкапов",
                    systemImage: "externaldrive.badge.timemachine",
                    description: Text("Создайте первый бэкап для защиты данных")
                )
            } else {
                List {
                    ForEach(backupService.backups) { backup in
                        BackupRowView(
                            backup: backup,
                            onRestore: {
                                selectedBackup = backup
                                isShowingRestoreAlert = true
                            },
                            onDelete: {
                                try? backupService.deleteBackup(backup)
                            }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
        .alert("Восстановить из бэкапа?", isPresented: $isShowingRestoreAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Восстановить", role: .destructive) {
                if let backup = selectedBackup {
                    restoreFromBackup(backup)
                }
            }
        } message: {
            if let backup = selectedBackup {
                Text("База данных будет заменена на версию от \(backup.formattedDate).\nТекущая БД будет сохранена как резервная копия.\n\nТребуется перезапуск приложения.")
            }
        }
    }
    
    private func createBackup() {
        isCreatingBackup = true
        Task {
            do {
                _ = try await Task { @MainActor in
                    try backupService.createBackup()
                }.value
            } catch {
                print("Failed to create backup: \(error)")
            }
            isCreatingBackup = false
        }
    }
    
    private func restoreFromBackup(_ backup: BackupService.BackupInfo) {
        Task {
            do {
                try await Task { @MainActor in
                    try backupService.restore(from: backup)
                }.value
                
                // Показываем сообщение о необходимости перезапуска
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Бэкап восстановлен"
                    alert.informativeText = "Пожалуйста, перезапустите приложение для применения изменений."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            } catch {
                print("Failed to restore backup: \(error)")
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

struct BackupRowView: View {
    let backup: BackupService.BackupInfo
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(backup.formattedDate)
                    .font(.headline)
                Text(backup.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onRestore) {
                Label("Восстановить", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            
            Button(action: onDelete) {
                Label("Удалить", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(.vertical, 4)
    }
}
