import SwiftUI

/// Диалоговое окно об успешном обновлении
struct UpdateSuccessView: View {
    @Binding var isPresented: Bool
    let version: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Иконка успеха
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            // Заголовок
            Text("Обновление завершено")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("AutoCreators успешно обновлен до версии \(version)")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Кнопка
            Button("Отлично") {
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 400)
    }
}
