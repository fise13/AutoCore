import SwiftUI
import AppKit

/// Таблица моторов в стиле Excel - с фиксированными заголовками, выделением ячеек и редактированием
struct MotorListViewExcel: View {
    let motors: [MotorRowDTO]
    @Binding var selectedMotorIDs: Set<Int64>
    let isLoading: Bool
    let totalCount: Int
    let onToggleSold: (Int64) -> Void
    let onLoadMore: () -> Void
    let onDuplicate: ((Int64) -> Void)?
    let onExportSelected: ((Int64) -> Void)?
    let onOpenDetails: ((Int64) -> Void)?
    let onCellSave: (Int64, EditableCellState.EditableField, String) -> Void
    
    // Состояние активной ячейки (как в Excel)
    @State private var activeCell: ActiveCell?
    @State private var editingCell: EditingCell?
    @State private var editingValue: String = ""
    @FocusState private var isEditingFocused: Bool
    
    // Selection state
    @State private var lastSelectedMotorIDForRange: Int64?
    
    // Колонки таблицы
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
        
        var field: EditableCellState.EditableField? {
            switch self {
            case .serial: return .serialCode
            case .configuration: return .configuration
            case .notes: return .notes
            case .quantity: return .quantity
            case .transmission: return .transmission
            case .arrivalDate: return .arrivalDate
            case .soldDate: return .soldDate
            case .action: return nil
            }
        }
        
        var alignment: Alignment {
            switch self {
            case .quantity, .arrivalDate, .soldDate:
                return .center
            default:
                return .leading
            }
        }
        
        var width: CGFloat {
            switch self {
            case .serial: return 150
            case .configuration: return 200
            case .notes: return 250
            case .quantity: return 80
            case .transmission: return 130
            case .arrivalDate, .soldDate: return 130
            case .action: return 180
            }
        }
    }
    
    struct ActiveCell: Equatable {
        let motorID: Int64
        let column: Column
    }
    
    private let rowHeight: CGFloat = 25
    private let headerHeight: CGFloat = 28
    private let gridLineColor = Color(NSColor.separatorColor)
    private let activeCellColor = Color(NSColor.controlAccentColor)
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingIndicator
            }
            
            if motors.isEmpty && !isLoading {
                emptyState
            } else {
                VStack(spacing: 0) {
                    // Batch операции toolbar
                    if !selectedMotorIDs.isEmpty {
                        batchToolbar
                    }
                    
                    // Таблица с фиксированными заголовками
                    excelTable
                    
                    // Footer
                    if !isLoading && totalCount > 0 {
                        footer
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .background(
            KeyboardHandler(
                onTab: {
                    moveToCell(direction: .right)
                },
                onShiftTab: {
                    moveToCell(direction: .left)
                },
                onEnter: {
                    if let active = activeCell {
                        if editingCell == nil, let field = active.column.field {
                            handleCellDoubleTap(motorID: active.motorID, column: active.column)
                        } else {
                            // Сохранить и перейти вниз
                            if let editing = editingCell {
                                onCellSave(editing.motorID, editing.field, editingValue)
                                editingCell = nil
                                editingValue = ""
                                moveToCell(direction: .down)
                            }
                        }
                    }
                },
                onEscape: {
                    editingCell = nil
                    editingValue = ""
                },
                onArrowUp: {
                    moveToCell(direction: .up)
                },
                onArrowDown: {
                    moveToCell(direction: .down)
                },
                onArrowLeft: {
                    moveToCell(direction: .left)
                },
                onArrowRight: {
                    moveToCell(direction: .right)
                }
            )
        )
    }
    
    // MARK: - Excel Table с фиксированными заголовками
    
    private var excelTable: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Фиксированный заголовок
                headerRow
                    .background(Color(NSColor.windowBackgroundColor))
                    .zIndex(1)
                
                Divider()
                
                // Скроллируемое содержимое
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(motors.enumerated()), id: \.element.id) { index, motor in
                            ExcelRowView(
                                motor: motor,
                                rowIndex: index,
                                isRowSelected: selectedMotorIDs.contains(motor.id),
                                activeCell: activeCell,
                                editingCell: editingCell,
                                editingValue: $editingValue,
                                isEditingFocused: $isEditingFocused,
                                columns: Column.allCases,
                                rowHeight: rowHeight,
                                gridLineColor: gridLineColor,
                                activeCellColor: activeCellColor,
                                onCellTap: { column in
                                    handleCellTap(motorID: motor.id, column: column)
                                },
                                onCellDoubleTap: { column in
                                    handleCellDoubleTap(motorID: motor.id, column: column)
                                },
                                onCellSave: { field, value in
                                    onCellSave(motor.id, field, value)
                                    editingCell = nil
                                    editingValue = ""
                                },
                                onRowSelect: {
                                    handleRowSelection(motorID: motor.id)
                                },
                                onToggleSold: { onToggleSold(motor.id) },
                                onOpenDetails: onOpenDetails.map { callback in { callback(motor.id) } }
                            )
                        }
                    }
                    .padding(.bottom, 1) // Небольшой отступ для последней строки
                }
            }
        }
    }
    
    private var headerRow: some View {
        HStack(spacing: 0) {
            // Row header (номер строки)
            ZStack {
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor))
                Text("#")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50, height: headerHeight)
            .overlay(
                Rectangle()
                    .stroke(gridLineColor, lineWidth: 1)
            )
            
            ForEach(Column.allCases) { column in
                ZStack {
                    Rectangle()
                        .fill(Color(NSColor.controlBackgroundColor))
                    Text(column.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(width: column.width, height: headerHeight, alignment: .center)
                .overlay(
                    Rectangle()
                        .stroke(gridLineColor, lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Components
    
    private var loadingIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.7)
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var emptyState: some View {
        Text("Моторов пока нет")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var batchToolbar: some View {
        HStack {
            Text("Выбрано: \(selectedMotorIDs.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button("Отменить выбор") {
                selectedMotorIDs.removeAll()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var footer: some View {
        HStack {
            Text("Показано \(motors.count) из \(totalCount)")
                .foregroundStyle(.secondary)
                .font(.caption)
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Selection Logic
    
    private func handleRowSelection(motorID: Int64) {
        let flags = NSEvent.modifierFlags
        
        if flags.contains(.command) {
            if selectedMotorIDs.contains(motorID) {
                selectedMotorIDs.remove(motorID)
            } else {
                selectedMotorIDs.insert(motorID)
                lastSelectedMotorIDForRange = motorID
            }
        } else if flags.contains(.shift), let lastID = lastSelectedMotorIDForRange,
                  let startIndex = motors.firstIndex(where: { $0.id == lastID }),
                  let endIndex = motors.firstIndex(where: { $0.id == motorID }) {
            let range = startIndex <= endIndex ? startIndex...endIndex : endIndex...startIndex
            let ids = range.map { motors[$0].id }
            selectedMotorIDs.formUnion(ids)
        } else {
            selectedMotorIDs = [motorID]
            lastSelectedMotorIDForRange = motorID
        }
    }
    
    private func handleCellTap(motorID: Int64, column: Column) {
        guard column != .action else { return }
        activeCell = ActiveCell(motorID: motorID, column: column)
        handleRowSelection(motorID: motorID)
    }
    
    private func handleCellDoubleTap(motorID: Int64, column: Column) {
        guard column != .action, let field = column.field else { return }
        guard let motor = motors.first(where: { $0.id == motorID }) else { return }
        
        let currentValue: String
        switch field {
        case .serialCode: currentValue = motor.serialCode
        case .configuration: currentValue = motor.configuration
        case .notes: currentValue = motor.notes
        case .quantity: currentValue = motor.quantity
        case .transmission: currentValue = motor.transmission
        case .arrivalDate: currentValue = motor.arrivalDate
        case .soldDate: currentValue = motor.soldDate
        }
        
        editingCell = EditingCell(motorID: motorID, field: field, initialValue: currentValue)
        editingValue = currentValue
        activeCell = ActiveCell(motorID: motorID, column: column)
    }
    
    enum MoveDirection {
        case up, down, left, right
    }
    
    private func moveToCell(direction: MoveDirection) {
        guard let active = activeCell else { return }
        guard let currentRowIndex = motors.firstIndex(where: { $0.id == active.motorID }) else { return }
        guard let currentColumnIndex = Column.allCases.firstIndex(where: { $0 == active.column }) else { return }
        
        var newRowIndex = currentRowIndex
        var newColumnIndex = currentColumnIndex
        
        switch direction {
        case .up:
            if currentRowIndex > 0 {
                newRowIndex = currentRowIndex - 1
            }
        case .down:
            if currentRowIndex < motors.count - 1 {
                newRowIndex = currentRowIndex + 1
            }
        case .left:
            if currentColumnIndex > 0 {
                newColumnIndex = currentColumnIndex - 1
            }
        case .right:
            if currentColumnIndex < Column.allCases.count - 1 {
                newColumnIndex = currentColumnIndex + 1
            }
        }
        
        let newMotor = motors[newRowIndex]
        let newColumn = Column.allCases[newColumnIndex]
        
        if newColumn != .action {
            activeCell = ActiveCell(motorID: newMotor.id, column: newColumn)
            selectedMotorIDs = [newMotor.id]
        }
    }
}

// MARK: - Excel Row View

struct ExcelRowView: View {
    let motor: MotorRowDTO
    let rowIndex: Int
    let isRowSelected: Bool
    let activeCell: MotorListViewExcel.ActiveCell?
    let editingCell: EditingCell?
    @Binding var editingValue: String
    @FocusState.Binding var isEditingFocused: Bool
    let columns: [MotorListViewExcel.Column]
    let rowHeight: CGFloat
    let gridLineColor: Color
    let activeCellColor: Color
    let onCellTap: (MotorListViewExcel.Column) -> Void
    let onCellDoubleTap: (MotorListViewExcel.Column) -> Void
    let onCellSave: (EditableCellState.EditableField, String) -> Void
    let onRowSelect: () -> Void
    let onToggleSold: () -> Void
    let onOpenDetails: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 0) {
            // Row header
            rowHeaderCell
            
            // Data cells
            ForEach(columns) { column in
                if column == .action {
                    actionCell
                } else {
                    dataCell(column: column)
                }
            }
        }
        .background(
            isRowSelected ? Color(NSColor.controlAccentColor).opacity(0.15) : Color.clear
        )
    }
    
    private var rowHeaderCell: some View {
        ZStack {
            Rectangle()
                .fill(Color(NSColor.controlBackgroundColor))
            Text("\(rowIndex + 1)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(width: 50, height: rowHeight)
        .overlay(
            Rectangle()
                .stroke(gridLineColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onRowSelect()
        }
    }
    
    private func dataCell(column: MotorListViewExcel.Column) -> some View {
        let isActive = activeCell?.motorID == motor.id && activeCell?.column == column
        let isEditing = editingCell?.motorID == motor.id && editingCell?.field == column.field
        
        let text: String
        switch column {
        case .serial: text = motor.serialCode
        case .configuration: text = motor.configuration
        case .notes: text = motor.notes
        case .quantity: text = motor.quantity
        case .transmission: text = motor.transmission
        case .arrivalDate: text = motor.arrivalDate
        case .soldDate: text = motor.soldDate
        case .action: text = ""
        }
        
        return ZStack {
            // Background
            Rectangle()
                .fill(isActive ? activeCellColor.opacity(0.1) : Color.clear)
            
            // Content
            if isEditing {
                TextField("", text: $editingValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .focused($isEditingFocused)
                    .padding(.horizontal, 4)
                    .onSubmit {
                        if let field = column.field {
                            onCellSave(field, editingValue)
                        }
                    }
            } else {
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(motor.isSold && column != .notes ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: column.alignment)
                    .padding(.horizontal, 4)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            // Border
            Rectangle()
                .stroke(
                    isActive ? activeCellColor : gridLineColor,
                    lineWidth: isActive ? 2 : 1
                )
        }
        .frame(width: column.width, height: rowHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            onCellTap(column)
        }
        .onTapGesture(count: 2) {
            onCellDoubleTap(column)
        }
        .contextMenu {
            Button("Копировать") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            }
            .keyboardShortcut("c", modifiers: .command)
        }
    }
    
    private var actionCell: some View {
        HStack(spacing: 6) {
            Button(motor.isSold ? "Вернуть" : "Продать") {
                onToggleSold()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            if let onOpenDetails = onOpenDetails {
                Button("Детали") {
                    onOpenDetails()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(width: MotorListViewExcel.Column.action.width, height: rowHeight, alignment: .center)
        .overlay(
            Rectangle()
                .stroke(gridLineColor, lineWidth: 1)
        )
    }
}
