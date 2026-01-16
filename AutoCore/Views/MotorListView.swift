import SwiftUI
import AppKit

struct MotorListView: View {
    let motors: [Motor]
    @Binding var selectedMotorID: Int64?
    @Binding var selectedMotorIDs: Set<Int64>
    let searchText: String
    let availabilityFilter: MotorAvailabilityFilter
    let isLoading: Bool
    let totalCount: Int
    let hasMorePages: Bool
    let onToggleSold: (Motor) -> Void
    let onLoadMore: () -> Void
    let onDuplicate: ((Motor) -> Void)?
    let onExportSelected: ((Motor) -> Void)?
    let onCellSave: (Int64, EditableCellState.EditableField, String) -> Void
    let onBatchSell: (([Int64]) -> Void)?
    let onBatchUnsell: (([Int64]) -> Void)?
    let onBatchAddNote: (([Int64]) -> Void)?
    let onOpenDetails: ((Motor) -> Void)?
    
    @StateObject private var editViewModel = InlineEditViewModel()
    @FocusState private var isTableFocused: Bool
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.7)
                    Spacer()
                }
                .padding(.vertical, 8)
            }

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
                VStack(spacing: 0) {
                    // Batch операции toolbar
                    if !selectedMotorIDs.isEmpty {
                        HStack {
                            Text("Выбрано: \(selectedMotorIDs.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if let onBatchSell = onBatchSell {
                                Button("Продать") {
                                    onBatchSell(Array(selectedMotorIDs))
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            if let onBatchUnsell = onBatchUnsell {
                                Button("Вернуть") {
                                    onBatchUnsell(Array(selectedMotorIDs))
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            if let onBatchAddNote = onBatchAddNote {
                                Button("Добавить заметку") {
                                    onBatchAddNote(Array(selectedMotorIDs))
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Button("Отменить выбор") {
                                selectedMotorIDs.removeAll()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(.regularMaterial)
                    }
                    
                    Table(motors, selection: $selectedMotorIDs) {
                    TableColumn("Номер двигателя") { motor in
                        makeEditableCell(motor: motor, field: .serialCode)
                            .contextMenu {
                                MotorContextMenu(
                                    motor: motor,
                                    onToggleSold: { onToggleSold(motor) },
                                    onDuplicate: {
                                        onDuplicate?(motor)
                                    },
                                    onExport: {
                                        onExportSelected?(motor)
                                    },
                                    onOpenDetails: onOpenDetails != nil ? { onOpenDetails?(motor) } : nil
                                )
                            }
                    }
                    TableColumn("Комплектация") { motor in
                        makeEditableCell(motor: motor, field: .configuration)
                    }
                    TableColumn("Особые отметки") { motor in
                        makeEditableCell(motor: motor, field: .notes)
                    }
                    TableColumn("Кол-во") { motor in
                        makeEditableCell(motor: motor, field: .quantity)
                    }
                    TableColumn("Коробка") { motor in
                        makeEditableCell(motor: motor, field: .transmission)
                    }
                    TableColumn("Дата прихода") { motor in
                        makeEditableCell(motor: motor, field: .arrivalDate)
                    }
                    TableColumn("Дата продажи") { motor in
                        makeEditableCell(motor: motor, field: .soldDate)
                    }
                    TableColumn("Действие") { motor in
                        HStack(spacing: 8) {
                        Button(motor.availability == .sold ? "Вернуть" : "Продать") {
                            onToggleSold(motor)
                            }
                            .buttonStyle(.bordered)
                            
                            if let onOpenDetails = onOpenDetails {
                                Button("Детали") {
                                    onOpenDetails(motor)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .focused($isTableFocused)
                .onAppear {
                    editViewModel.onCellSave = onCellSave
                }
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
                .background(
                    KeyboardHandler(
                        onTab: {
                            if let editing = editViewModel.editingCell {
                                editViewModel.moveToNextCell(
                                    currentMotorID: editing.motorID,
                                    currentField: editing.field,
                                    motors: motors,
                                    forward: true
                                )
                            }
                        },
                        onShiftTab: {
                            if let editing = editViewModel.editingCell {
                                editViewModel.moveToNextCell(
                                    currentMotorID: editing.motorID,
                                    currentField: editing.field,
                                    motors: motors,
                                    forward: false
                                )
                            }
                        },
                        onEnter: {
                            if editViewModel.editingCell != nil {
                                // Enter уже обрабатывается в TextField.onSubmit
                            } else {
                                // Enter → начать редактирование ВЫДЕЛЕННОЙ ячейки
                                editViewModel.startEditingSelectedCell(motors: motors)
                            }
                        },
                        onEscape: {
                            editViewModel.cancelEditing()
                        }
                    )
                )
                }
            }
        }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return Self.dateFormatter.string(from: date)
    }
    
    // MARK: - Helper для создания EditableCell
    
    private func makeEditableCell(motor: Motor, field: EditableCellState.EditableField) -> EditableCell {
        EditableCell(
            motor: motor,
            field: field,
            selectedCell: editViewModel.selectedCell,
            editingCell: editViewModel.editingCell,
            onSelect: { motorID, field in
                editViewModel.selectCell(motorID: motorID, field: field)
            },
            onStartEditing: { motorID, field in
                let value = getCellValue(motorID: motorID, field: field, motors: motors)
                editViewModel.startEditing(motorID: motorID, field: field, currentValue: value)
            },
            onSave: { motorID, field, value in
                editViewModel.saveCell(motorID: motorID, field: field, value: value)
                onCellSave(motorID, field, value)
            },
            onCopy: { value in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            },
            onPaste: {
                NSPasteboard.general.string(forType: .string) ?? ""
            },
            onClear: {
                if let selected = editViewModel.selectedCell {
                    editViewModel.saveCell(motorID: selected.motorID, field: selected.field, value: "")
                    onCellSave(selected.motorID, selected.field, "")
                }
            },
            isSold: motor.availability == .sold
        )
    }
    
    private func getCellValue(motorID: Int64, field: EditableCellState.EditableField, motors: [Motor]) -> String {
        guard let motor = motors.first(where: { $0.id == motorID }) else { return "" }
        
        switch field {
        case .serialCode:
            return motor.serialCode
        case .configuration:
            return motor.configuration
        case .notes:
            return motor.notes
        case .quantity:
            return "\(motor.quantity)"
        case .transmission:
            return motor.transmission
        case .arrivalDate:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: motor.arrivalDate)
        case .soldDate:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let soldDate = motor.soldDate {
                return formatter.string(from: soldDate)
            } else {
                return ""
            }
        }
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

// MARK: - Context Menu

private struct MotorContextMenu: View {
    let motor: Motor
    let onToggleSold: () -> Void
    let onDuplicate: () -> Void
    let onExport: () -> Void
    let onOpenDetails: (() -> Void)?
    
    var body: some View {
        Group {
            Button(motor.availability == .sold ? "Вернуть в наличие" : "Пометить как проданный") {
                onToggleSold()
            }
            .keyboardShortcut("s", modifiers: .command)
            
            if let onOpenDetails = onOpenDetails {
                Button("Открыть детали") {
                    onOpenDetails()
                }
                .keyboardShortcut("d", modifiers: .command)
            }
            
            Divider()
            
            Button("Дублировать") {
                onDuplicate()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            
            Button("Экспортировать") {
                onExport()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Копировать номер") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(motor.serialCode, forType: .string)
            }
            .keyboardShortcut("c", modifiers: .command)
        }
    }
}
