import SwiftUI
import AppKit

// MARK: - Editable Cell State

struct EditableCellState: Equatable {
    enum EditableField: String, CaseIterable {
        case serialCode = "Номер двигателя"
        case configuration = "Комплектация"
        case notes = "Особые отметки"
        case quantity = "Кол-во"
        case transmission = "Коробка"
        case arrivalDate = "Дата прихода"
        case soldDate = "Дата продажи"
    }
}

// MARK: - Editable Cell View

struct EditableCell: View {
    let motor: Motor
    let field: EditableCellState.EditableField
    let selectedCell: SelectedCell?
    let editingCell: EditingCell?
    let onSelect: (Int64, EditableCellState.EditableField) -> Void
    let onStartEditing: (Int64, EditableCellState.EditableField) -> Void
    let onSave: (Int64, EditableCellState.EditableField, String) -> Void
    let onCopy: ((String) -> Void)?
    let onPaste: (() -> String)?
    let onClear: (() -> Void)?
    let isSold: Bool
    
    @State private var localValue: String = ""
    @FocusState private var isFocused: Bool
    
    // РАЗДЕЛЬНЫЕ проверки состояния
    private var isSelected: Bool {
        selectedCell?.motorID == motor.id && selectedCell?.field == field
    }
    
    private var isCurrentlyEditing: Bool {
        editingCell?.motorID == motor.id && editingCell?.field == field
    }
    
    var body: some View {
        Group {
            if isCurrentlyEditing {
                editingView
            } else {
                displayView
            }
        }
        .contentShape(Rectangle())
        // ДВОЙНОЙ КЛИК → редактирование (мгновенно, без задержки)
        .onTapGesture(count: 2) {
            if !isSold || field == .notes {
                onStartEditing(motor.id, field)
            }
        }
        // ОДИН КЛИК → выделение (БЕЗ редактирования)
        .onTapGesture {
            if !isCurrentlyEditing {
                onSelect(motor.id, field)
            }
        }
        // Контекстное меню для ВЫДЕЛЕННОЙ ячейки
        .contextMenu {
            if isSelected {
                CellContextMenu(
                    onCopy: {
                        onCopy?(displayValue)
                    },
                    onPaste: {
                        if let pasted = onPaste?() {
                            onSave(motor.id, field, pasted)
                        }
                    },
                    onClear: {
                        onClear?()
                    },
                    canPaste: onPaste != nil,
                    canEdit: !isSold || field == .notes
                )
            }
        }
    }
    
    private var displayView: some View {
        HStack {
            Text(displayValue)
                .foregroundStyle(isSold && field != .notes ? .secondary : .primary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        // Спокойное выделение: очень легкая заливка (2% opacity) нейтрального серого
        .background(
            isSelected ? Color(white: 0.5, opacity: 0.02) : Color.clear
        )
        // Тонкая рамка 0.5px нейтрального серо-голубого цвета (как в Excel/Numbers)
        .overlay(
            Rectangle()
                .strokeBorder(
                    isSelected ? Color(white: 0.45, opacity: 0.35) : Color.clear,
                    lineWidth: 0.5
                )
        )
    }
    
    private var editingView: some View {
        Group {
            switch field {
            case .serialCode, .configuration, .notes, .transmission:
                TextField("", text: $localValue)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        save()
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    // Фон как у системного textField (белый/светлый)
                    .background(Color(NSColor.textBackgroundColor))
                    // БЕЗ рамки - минималистично, как в Excel при редактировании
                    // Только легкая тень для глубины (опционально)
            case .quantity:
                TextField("", text: $localValue)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        save()
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    // Фон как у системного textField (белый/светлый)
                    .background(Color(NSColor.textBackgroundColor))
                    // БЕЗ рамки - минималистично, как в Excel при редактировании
            case .arrivalDate, .soldDate:
                DatePickerCell(
                    value: $localValue,
                    onSave: save
                )
            }
        }
        .onAppear {
            // МГНОВЕННАЯ инициализация БЕЗ задержек
            if let editing = editingCell {
                localValue = editing.initialValue
            } else {
                localValue = editingValue
            }
            // Фокус устанавливается МГНОВЕННО
            isFocused = true
        }
        .onChange(of: isFocused) { _, newValue in
            // Сохранение при потере фокуса (клик вне ячейки)
            if !newValue && isCurrentlyEditing {
                save()
            }
        }
    }
    
    private var displayValue: String {
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
            return formatDate(motor.arrivalDate)
        case .soldDate:
            return formatDate(motor.soldDate)
        }
    }
    
    private var editingValue: String {
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
            return dateToString(motor.arrivalDate)
        case .soldDate:
            return dateToString(motor.soldDate)
        }
    }
    
    
    private func save() {
        guard isCurrentlyEditing else { return }
        
        let trimmedValue = localValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalValue: String
        
        switch field {
        case .quantity:
            // Валидация числа
            if let num = Int(trimmedValue), num > 0 {
                finalValue = "\(num)"
            } else {
                finalValue = editingValue // Откат при невалидном значении
            }
        case .arrivalDate, .soldDate:
            // Для дат сохраняем как есть, парсинг будет в onSave
            finalValue = trimmedValue.isEmpty ? editingValue : trimmedValue
        default:
            finalValue = trimmedValue
        }
        
        onSave(motor.id, field, finalValue)
        // Состояние редактирования очищается в ViewModel через onSave
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func dateToString(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Date Picker Cell

struct DatePickerCell: View {
    @Binding var value: String
    let onSave: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var showPicker = false
    @State private var selectedDate: Date?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    var body: some View {
        HStack {
            TextField("", text: $value)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    onSave()
                }
                .onChange(of: value) { _, newValue in
                    if let date = dateFormatter.date(from: newValue) {
                        selectedDate = date
                    }
                }
            
            Button {
                showPicker.toggle()
            } label: {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        // Фон как у системного textField (белый/светлый)
        .background(Color(NSColor.textBackgroundColor))
        // БЕЗ рамки - минималистично, как в Excel при редактировании
        .popover(isPresented: $showPicker) {
            DatePicker(
                "Дата",
                selection: Binding(
                    get: { selectedDate ?? Date() },
                    set: { selectedDate = $0 }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .padding()
            .onChange(of: selectedDate) { _, newDate in
                if let newDate {
                    value = dateFormatter.string(from: newDate)
                    onSave()
                }
            }
        }
        .onAppear {
            if let date = dateFormatter.date(from: value) {
                selectedDate = date
            }
            // МГНОВЕННЫЙ фокус БЕЗ задержки
            isFocused = true
        }
    }
}

// MARK: - Cell Context Menu

private struct CellContextMenu: View {
    let onCopy: () -> Void
    let onPaste: () -> Void
    let onClear: () -> Void
    let canPaste: Bool
    let canEdit: Bool
    
    var body: some View {
        Group {
            Button("Копировать") {
                onCopy()
            }
            .keyboardShortcut("c", modifiers: .command)
            
            if canPaste {
                Button("Вставить") {
                    onPaste()
                }
                .keyboardShortcut("v", modifiers: .command)
            }
            
            Divider()
            
            if canEdit {
                Button("Очистить") {
                    onClear()
                }
            }
        }
    }
}
