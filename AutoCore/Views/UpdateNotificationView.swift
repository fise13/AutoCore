import SwiftUI

#if os(macOS)

/// View для уведомления об обновлении (только macOS)
struct UpdateNotificationView: View {
    @ObservedObject var updateService: UpdateService
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Иконка и заголовок
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Доступна новая версия AutoCreators \(updateService.availableUpdate?.version ?? "")")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            // Заметки об обновлении
            if let notes = updateService.availableUpdate?.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Что нового:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(notes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(note)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            // Прогресс загрузки
            if updateService.isDownloadingUpdate {
                VStack(spacing: 8) {
                    ProgressView(value: updateService.downloadProgress)
                    Text("Скачивание обновления: \(Int(updateService.downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // Кнопки
            HStack(spacing: 12) {
                Button("Позже") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Button("Скачать обновление") {
                    Task {
                        await downloadUpdate()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(updateService.isDownloadingUpdate)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
    
    private func downloadUpdate() async {
        do {
            try await updateService.downloadAndInstallUpdate()
        } catch {
            // Ошибка при установке - показываем пользователю
            // (это единственный случай, когда показываем ошибку)
            await MainActor.run {
                // Можно показать alert через NotificationCenter
                NotificationCenter.default.post(
                    name: NSNotification.Name("UpdateError"),
                    object: error.localizedDescription
                )
            }
        }
    }
}

#endif
