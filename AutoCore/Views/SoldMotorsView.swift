import SwiftUI

struct SoldMotorsView: View {
    let motors: [Motor]
    @Binding var selectedMotorID: Int64?
    @Binding var searchText: String
    let isLoading: Bool
    let totalCount: Int
    let hasMorePages: Bool
    let onReturnToStock: (Motor) -> Void
    let onLoadMore: () -> Void
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            if motors.isEmpty && !isLoading {
                EmptyStateView(
                    icon: "checkmark.seal.fill",
                    title: totalCount == 0 ? "Проданных моторов пока нет" : "Ничего не найдено",
                    message: totalCount == 0
                        ? "Когда мотор будет продан, он появится здесь"
                        : "Попробуйте изменить запрос",
                    actionTitle: nil,
                    action: nil
                )
            } else {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Table(motors, selection: $selectedMotorID) {
                    TableColumn("Номер двигателя") { motor in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.secondary)
                                .imageScale(.small)
                            Text(motor.serialCode)
                                .foregroundStyle(.secondary)
                        }
                    }
                    TableColumn("Комплектация") { motor in
                        Text(motor.configuration)
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Особые отметки") { motor in
                        Text(motor.notes)
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Кол-во") { motor in
                        Text("\(motor.quantity)")
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Коробка") { motor in
                        Text(motor.transmission)
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Дата прихода") { motor in
                        Text(formatDate(motor.arrivalDate))
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Дата продажи") { motor in
                        Text(formatDate(motor.soldDate))
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Действие") { motor in
                        Button("Вернуть") {
                            onReturnToStock(motor)
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if hasMorePages && !isLoading {
                        HStack {
                            Text("Показано \(motors.count) из \(totalCount)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            Spacer()
                            Button("Загрузить ещё") {
                                onLoadMore()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(.regularMaterial)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Поиск по серийному коду, двигателю, бренду")
        .onAppear {
            if hasMorePages && motors.count > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onLoadMore()
                }
            }
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return Self.dateFormatter.string(from: date)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.title2)
                .foregroundStyle(.primary)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
