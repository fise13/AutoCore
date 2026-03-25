import SwiftUI

#if os(macOS)
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
    
    /// Активная ячейка (как в Excel) – одна на всю таблицу
    struct ActiveCell: Equatable {
        let motorID: Int64
        let column: Column
    }
    
    /// Колонки таблицы (без row header)
    enum Column: String, CaseIterable, Identifiable {
        case serial
        case configuration
        case notes
        case quantity
        case transmission
        case arrivalDate
        case soldDate
        case action
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .serial: return "Номер двигателя"
            case .configuration: return "Комплектация"
            case .notes: return "Особые отметки"
            case .quantity: return "Кол-во"
            case .transmission: return "Коробка"
            case .arrivalDate: return "Дата прихода"
            case .soldDate: return "Дата продажи"
            case .action: return "Действие"
            }
        }
        
        /// Выравнивание текста в ячейке
        var alignment: Alignment {
            switch self {
            case .quantity, .arrivalDate, .soldDate:
                return .center
            default:
                return .leading
            }
        }
        
        /// Примерная ширина колонки
        var width: CGFloat {
            switch self {
            case .serial: return 140
            case .configuration: return 180
            case .notes: return 220
            case .quantity: return 70
            case .transmission: return 120
            case .arrivalDate, .soldDate: return 120
            case .action: return 160
            }
        }
    }
    
    @State private var activeCell: ActiveCell?
    @State private var lastSelectedMotorIDForRange: Int64?
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    private static let editDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    // MARK: - Helper Methods
    
    private static func getCellValue(motor: Motor, field: EditableCellState.EditableField) -> String {
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
            return Self.editDateFormatter.string(from: motor.arrivalDate)
        case .soldDate:
            if let soldDate = motor.soldDate {
                return Self.editDateFormatter.string(from: soldDate)
            } else {
                return ""
            }
        }
    }
    
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
                    
                    // MARK: Spreadsheet Grid
                    SpreadsheetGrid(
                        motors: motors,
                        selectedMotorIDs: $selectedMotorIDs,
                        selectedMotorID: $selectedMotorID,
                        activeCell: $activeCell,
                        lastSelectedMotorIDForRange: $lastSelectedMotorIDForRange,
                        editViewModel: editViewModel,
                        onToggleSold: onToggleSold,
                        onDuplicate: onDuplicate,
                        onExportSelected: onExportSelected,
                        onOpenDetails: onOpenDetails,
                        onCellSave: onCellSave
                    )
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
                            onTab: { }, // Tab не используется в read-only режиме
                            onShiftTab: { }, // Shift-Tab не используется
                            onEnter: {
                                // Enter → начать редактирование текущей строки (первое поле)
                                if let selectedID = selectedMotorID,
                                   let motor = motors.first(where: { $0.id == selectedID }) {
                                    let value = Self.getCellValue(motor: motor, field: .serialCode)
                                    editViewModel.startEditing(motorID: motor.id, field: .serialCode, currentValue: value)
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
    
    // MARK: - Spreadsheet Grid Implementation
    
    /// Кастомная grid-реализация в стиле Excel
    private struct SpreadsheetGrid: View {
        let motors: [Motor]
        @Binding var selectedMotorIDs: Set<Int64>
        @Binding var selectedMotorID: Int64?
        @Binding var activeCell: MotorListView.ActiveCell?
        @Binding var lastSelectedMotorIDForRange: Int64?
        
        let editViewModel: InlineEditViewModel
        let onToggleSold: (Motor) -> Void
        let onDuplicate: ((Motor) -> Void)?
        let onExportSelected: ((Motor) -> Void)?
        let onOpenDetails: ((Motor) -> Void)?
        let onCellSave: (Int64, EditableCellState.EditableField, String) -> Void
        
        #if os(macOS)
        private let gridLineColor = Color(NSColor.separatorColor)
        #else
        private let gridLineColor = Color.gray.opacity(0.3)
        #endif
        
        var body: some View {
            VStack(spacing: 0) {
                headerRow
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(motors.enumerated()), id: \.1.id) { index, motor in
                            gridRow(index: index, motor: motor)
                        }
                    }
                }
            }
            #if os(macOS)
            .background(Color(NSColor.textBackgroundColor))
            #else
            .background(Color(uiColor: .systemBackground))
            #endif
        }
        
        // MARK: Header
        
        private var headerRow: some View {
            HStack(spacing: 0) {
                // Row header (пустая ячейка для угла, как в Excel)
                Rectangle()
                    .fill(Color(NSColor.windowBackgroundColor))
                    .frame(width: 40, height: 24)
                    .overlay(
                        Rectangle()
                            .stroke(gridLineColor, lineWidth: 0.5)
                    )
                
                ForEach(MotorListView.Column.allCases) { column in
                    Text(column.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: column.width, height: 24, alignment: .center)
                        .background(Color(NSColor.windowBackgroundColor))
                        .overlay(
                            Rectangle()
                                .stroke(gridLineColor, lineWidth: 0.5)
                        )
                }
            }
        }
        
        // MARK: Row
        
        private func gridRow(index: Int, motor: Motor) -> some View {
            let isRowSelected = selectedMotorIDs.contains(motor.id)
            
            return HStack(spacing: 0) {
                // Row header: номер строки
                rowHeaderCell(index: index, motor: motor, isRowSelected: isRowSelected)
                
                ForEach(MotorListView.Column.allCases) { column in
                    gridCell(motor: motor, column: column, isRowSelected: isRowSelected)
                }
            }
            .background(isRowSelected ? Color(NSColor.controlAccentColor).opacity(0.06) : Color.clear)
        }
        
        private func rowHeaderCell(index: Int, motor: Motor, isRowSelected: Bool) -> some View {
            let isActive = activeCell?.motorID == motor.id && activeCell?.column == nil
            
            return Text("\(index + 1)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 24, alignment: .trailing)
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(
                    Rectangle()
                        .stroke(isActive ? Color.accentColor : gridLineColor, lineWidth: isActive ? 1.5 : 0.5)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    handleRowSelectionClick(motor: motor)
                }
        }
        
        // MARK: Cell
        
        private func gridCell(motor: Motor, column: MotorListView.Column, isRowSelected: Bool) -> some View {
            let isActive = activeCell?.motorID == motor.id && activeCell?.column == column
            
            return Group {
                if column == .action {
                    actionCell(motor: motor)
                } else {
                    dataCell(motor: motor, column: column)
                }
            }
            .frame(width: column.width, height: 24, alignment: column.alignment)
            .background(Color.clear)
            .overlay(
                Rectangle()
                    .stroke(isActive ? Color.accentColor : gridLineColor, lineWidth: isActive ? 1.5 : 0.5)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectedMotorID = motor.id
                activeCell = MotorListView.ActiveCell(motorID: motor.id, column: column)
                handleRowSelectionClick(motor: motor)
            }
            .onTapGesture(count: 2) {
                // Double-click → редактирование
                startEditing(motor: motor, column: column)
            }
        }
        
        private func dataCell(motor: Motor, column: MotorListView.Column) -> some View {
            let field: EditableCellState.EditableField
            switch column {
            case .serial: field = .serialCode
            case .configuration: field = .configuration
            case .notes: field = .notes
            case .quantity: field = .quantity
            case .transmission: field = .transmission
            case .arrivalDate: field = .arrivalDate
            case .soldDate: field = .soldDate
            case .action:
                // сюда не попадаем
                field = .serialCode
            }
            
            return EditableCell(
                motor: motor,
                field: field,
                editingCell: editViewModel.editingCell,
                onStartEditing: { motorID, field in
                    guard let motor = motors.first(where: { $0.id == motorID }) else { return }
                    let value = MotorListView.getCellValue(motor: motor, field: field)
                    editViewModel.startEditing(motorID: motorID, field: field, currentValue: value)
                },
                onSave: { motorID, field, value in
                    editViewModel.saveCell(motorID: motorID, field: field, value: value)
                    onCellSave(motorID, field, value)
                },
                onCopy: { value in
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(value, forType: .string)
                },
                isSold: motor.availability == .sold
            )
        }
        
        private func actionCell(motor: Motor) -> some View {
            HStack(spacing: 6) {
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
            .frame(maxWidth: .infinity, alignment: .center)
        }
        
        // MARK: Selection Logic
        
        private func handleRowSelectionClick(motor: Motor) {
            let flags = NSEvent.modifierFlags
            
            if flags.contains(.command) {
                // ⌘ — добавление/удаление из множества
                if selectedMotorIDs.contains(motor.id) {
                    selectedMotorIDs.remove(motor.id)
                } else {
                    selectedMotorIDs.insert(motor.id)
                    lastSelectedMotorIDForRange = motor.id
                }
            } else if flags.contains(.shift), let lastID = lastSelectedMotorIDForRange,
                      let startIndex = motors.firstIndex(where: { $0.id == lastID }),
                      let endIndex = motors.firstIndex(where: { $0.id == motor.id }) {
                // ⇧ — диапазон
                let range = startIndex <= endIndex ? startIndex...endIndex : endIndex...startIndex
                let ids = range.map { motors[$0].id }
                selectedMotorIDs.formUnion(ids)
            } else {
                // Обычный клик — одна строка
                selectedMotorIDs = [motor.id]
                lastSelectedMotorIDForRange = motor.id
            }
        }
        
        private func startEditing(motor: Motor, column: MotorListView.Column) {
            guard column != .action else { return }
            
            let field: EditableCellState.EditableField
            switch column {
            case .serial: field = .serialCode
            case .configuration: field = .configuration
            case .notes: field = .notes
            case .quantity: field = .quantity
            case .transmission: field = .transmission
            case .arrivalDate: field = .arrivalDate
            case .soldDate: field = .soldDate
            case .action:
                return
            }
            
            let value = MotorListView.getCellValue(motor: motor, field: field)
            editViewModel.startEditing(motorID: motor.id, field: field, currentValue: value)
            activeCell = MotorListView.ActiveCell(motorID: motor.id, column: column)
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
}

#endif
