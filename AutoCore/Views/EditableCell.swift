import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
typealias NSColor = UIColor
extension NSColor {
    static var textBackgroundColor: NSColor { .systemBackground }
    static var separatorColor: NSColor { .separator }
    static var controlBackgroundColor: NSColor { .secondarySystemBackground }
    static var windowBackgroundColor: NSColor { .systemBackground }
    static var controlAccentColor: NSColor { .tintColor }
}
#endif

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

// MARK: - Read-Only Cell (простой Text, без состояний)
struct EditableCell: View {
    let motor: Motor
    let field: EditableCellState.EditableField
    let editingCell: EditingCell?
    let onStartEditing: (Int64, EditableCellState.EditableField) -> Void
    let onSave: (Int64, EditableCellState.EditableField, String) -> Void
    let onCopy: ((String) -> Void)?
    let isSold: Bool
    
    // Только состояние для редактирования (создается только при редактировании)
    @State private var localValue: String = ""
    @FocusState private var isFocused: Bool
    
    // Проверка, редактируется ли ячейка
    private var isCurrentlyEditing: Bool {
        editingCell?.motorID == motor.id && editingCell?.field == field
    }
    
    // Вычисляемое значение для отображения
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
    
    var body: some View {
        Group {
            if isCurrentlyEditing {
                editingView
            } else {
                readOnlyView
            }
        }
        .contentShape(Rectangle())
        // ТОЛЬКО двойной клик для редактирования
        .onTapGesture(count: 2) {
            if !isSold || field == .notes {
                onStartEditing(motor.id, field)
            }
        }
        // Контекстное меню (копирование)
        .contextMenu {
            CellContextMenu(
                onCopy: {
                    onCopy?(displayValue)
                },
                onEdit: {
                    if !isSold || field == .notes {
                        onStartEditing(motor.id, field)
                    }
                },
                canEdit: !isSold || field == .notes
            )
        }
    }
    
    // READ-ONLY VIEW - простой Text, без состояний, без модификаторов
    private var readOnlyView: some View {
        Text(displayValue)
            .foregroundStyle(isSold && field != .notes ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
    }
    
    // EDITING VIEW - показывается только при редактировании
    private var editingView: some View {
        Group {
            switch field {
            case .serialCode, .configuration, .notes, .transmission:
                TextField("", text: $localValue)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit { save() }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.textBackgroundColor))
            case .quantity:
                TextField("", text: $localValue)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit { save() }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.textBackgroundColor))
            case .arrivalDate, .soldDate:
                DatePickerCell(
                    value: $localValue,
                    onSave: save
                )
            }
        }
        .onAppear {
            // Инициализация значения при начале редактирования
            if let editing = editingCell {
                localValue = editing.initialValue
            } else {
                localValue = editValue
            }
            isFocused = true
        }
        .onChange(of: isFocused) { _, newValue in
            if !newValue && isCurrentlyEditing {
                save()
            }
        }
    }
    
    // Значение для редактирования
    private var editValue: String {
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
            if let num = Int(trimmedValue), num > 0 {
                finalValue = "\(num)"
            } else {
                finalValue = editValue // Откат при невалидном значении
            }
        case .arrivalDate, .soldDate:
            finalValue = trimmedValue.isEmpty ? editValue : trimmedValue
        default:
            finalValue = trimmedValue
        }
        
        onSave(motor.id, field, finalValue)
    }
    
    // Статические formatters для производительности
    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    private static let editDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return Self.displayDateFormatter.string(from: date)
    }
    
    private func dateToString(_ date: Date?) -> String {
        guard let date else { return "" }
        return Self.editDateFormatter.string(from: date)
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
    let onEdit: () -> Void
    let canEdit: Bool
    
    var body: some View {
        Group {
            Button("Копировать") {
                onCopy()
            }
            .keyboardShortcut("c", modifiers: .command)
            
            if canEdit {
                Divider()
                Button("Редактировать") {
                    onEdit()
                }
                .keyboardShortcut("e", modifiers: .command)
            }
        }
    }
}
