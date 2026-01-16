import SwiftUI

struct MotorListView: View {
    let motors: [Motor]
    @Binding var selectedMotorID: Int64?
    @Binding var searchText: String
    @Binding var availabilityFilter: MotorAvailabilityFilter
    let isLoading: Bool
    let totalCount: Int
    let hasMorePages: Bool
    let onToggleSold: (Motor) -> Void
    let onLoadMore: () -> Void
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Наличие", selection: $availabilityFilter) {
                    ForEach(MotorAvailabilityFilter.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if motors.isEmpty && !isLoading {
                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "Ничего не найдено",
                        message: "Попробуйте изменить запрос",
                        actionTitle: nil,
                        action: nil
                    )
                } else {
                    EmptyStateView(
                        icon: "engine.combustion",
                        title: "Моторов пока нет",
                        message: "Добавьте первый мотор, чтобы начать работу",
                        actionTitle: nil,
                        action: nil
                    )
                }
            } else {
                Table(motors, selection: $selectedMotorID) {
                TableColumn("Номер двигателя") { motor in
                    MotorRowView(motor: motor)
                }
                TableColumn("Комплектация") { motor in
                    rowText(motor.configuration, sold: motor.availability == .sold)
                }
                TableColumn("Особые отметки") { motor in
                    rowText(motor.notes, sold: motor.availability == .sold)
                }
                TableColumn("Кол-во") { motor in
                    rowText("\(motor.quantity)", sold: motor.availability == .sold)
                }
                TableColumn("Коробка") { motor in
                    rowText(motor.transmission, sold: motor.availability == .sold)
                }
                TableColumn("Дата прихода") { motor in
                    rowText(formatDate(motor.arrivalDate), sold: motor.availability == .sold)
                }
                TableColumn("Дата продажи") { motor in
                    rowText(formatDate(motor.soldDate), sold: motor.availability == .sold)
                }
                TableColumn("Действие") { motor in
                    Button(motor.availability == .sold ? "Вернуть" : "Продать") {
                        onToggleSold(motor)
                    }
                }
            }
            // Пагинация больше не нужна, так как все моторы загружены в память
            // Пагинация больше не нужна, так как все моторы загружены в память
            // Показываем только счетчик
            .overlay(alignment: .bottom) {
                if !isLoading && totalCount > 0 {
                    HStack {
                        Text("Показано \(motors.count) из \(totalCount)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Spacer()
                    }
                    .padding()
                    .background(.regularMaterial)
                }
            }
            }
        }
        .searchable(text: $searchText, prompt: "Поиск по серийному коду")
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return Self.dateFormatter.string(from: date)
    }

    private func rowText(_ value: String, sold: Bool) -> some View {
        Text(value)
            .foregroundStyle(sold ? .secondary : .primary)
    }
}

private struct MotorRowView: View {
    let motor: Motor
    
    var body: some View {
        HStack(spacing: 6) {
            if motor.availability == .sold {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }
            Text(motor.serialCode)
                .foregroundStyle(motor.availability == .sold ? .secondary : .primary)
        }
    }
}
