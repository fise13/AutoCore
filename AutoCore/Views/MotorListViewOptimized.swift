import SwiftUI
import AppKit

/// Оптимизированная таблица моторов - производительность уровня Finder/Excel
struct MotorListViewOptimized: View {
    let motors: [MotorRowDTO]
    @Binding var selectedMotorIDs: Set<Int64>
    let isLoading: Bool
    let totalCount: Int
    let onToggleSold: (Int64) -> Void
    let onLoadMore: () -> Void
    let onDuplicate: ((Int64) -> Void)?
    let onExportSelected: ((Int64) -> Void)?
    let onOpenDetails: ((Int64) -> Void)?
    
    // Selection state - только Set, без пересборки таблицы
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
    
    private let rowHeight: CGFloat = 24
    private let gridLineColor = Color(NSColor.separatorColor)
    
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
                    
                    // Таблица
                    spreadsheetGrid
                    
                    // Footer
                    if !isLoading && totalCount > 0 {
                        footer
                    }
                }
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
    
    private var spreadsheetGrid: some View {
        VStack(spacing: 0) {
            headerRow
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(motors.enumerated()), id: \.element.id) { index, motor in
                        MotorRowView(
                            motor: motor,
                            rowIndex: index,
                            isSelected: selectedMotorIDs.contains(motor.id),
                            columns: Column.allCases,
                            rowHeight: rowHeight,
                            gridLineColor: gridLineColor,
                            onSelect: { handleSelection(motorID: motor.id) },
                            onToggleSold: { onToggleSold(motor.id) },
                            onDuplicate: onDuplicate.map { callback in { callback(motor.id) } },
                            onOpenDetails: onOpenDetails.map { callback in { callback(motor.id) } }
                        )
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private var headerRow: some View {
        HStack(spacing: 0) {
            // Row header (пустая ячейка)
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor))
                .frame(width: 40, height: rowHeight)
                .overlay(
                    Rectangle()
                        .stroke(gridLineColor, lineWidth: 0.5)
                )
            
            ForEach(Column.allCases) { column in
                Text(column.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: column.width, height: rowHeight, alignment: .center)
                    .background(Color(NSColor.windowBackgroundColor))
                    .overlay(
                        Rectangle()
                            .stroke(gridLineColor, lineWidth: 0.5)
                    )
            }
        }
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
    
    private func handleSelection(motorID: Int64) {
        let flags = NSEvent.modifierFlags
        
        if flags.contains(.command) {
            // ⌘ — добавление/удаление из множества
            if selectedMotorIDs.contains(motorID) {
                selectedMotorIDs.remove(motorID)
            } else {
                selectedMotorIDs.insert(motorID)
                lastSelectedMotorIDForRange = motorID
            }
        } else if flags.contains(.shift), let lastID = lastSelectedMotorIDForRange,
                  let startIndex = motors.firstIndex(where: { $0.id == lastID }),
                  let endIndex = motors.firstIndex(where: { $0.id == motorID }) {
            // ⇧ — диапазон
            let range = startIndex <= endIndex ? startIndex...endIndex : endIndex...startIndex
            let ids = range.map { motors[$0].id }
            selectedMotorIDs.formUnion(ids)
        } else {
            // Обычный клик — одна строка
            selectedMotorIDs = [motorID]
            lastSelectedMotorIDForRange = motorID
        }
    }
    
}

// MARK: - Motor Row View (Stateless)

struct MotorRowView: View {
    let motor: MotorRowDTO
    let rowIndex: Int
    let isSelected: Bool
    let columns: [MotorListViewOptimized.Column]
    let rowHeight: CGFloat
    let gridLineColor: Color
    let onSelect: () -> Void
    let onToggleSold: () -> Void
    let onDuplicate: (() -> Void)?
    let onOpenDetails: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 0) {
            // Row header: номер строки
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
        .background(isSelected ? Color(NSColor.controlAccentColor).opacity(0.1) : Color.clear)
    }
    
    private var rowHeaderCell: some View {
        Text("\(rowIndex + 1)")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(width: 40, height: rowHeight, alignment: .trailing)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .stroke(gridLineColor, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
    }
    
    private func dataCell(column: MotorListViewOptimized.Column) -> some View {
        let text: String
        switch column {
        case .serial:
            text = motor.serialCode
        case .configuration:
            text = motor.configuration
        case .notes:
            text = motor.notes
        case .quantity:
            text = motor.quantity
        case .transmission:
            text = motor.transmission
        case .arrivalDate:
            text = motor.arrivalDate
        case .soldDate:
            text = motor.soldDate
        case .action:
            text = ""
        }
        
        return Text(text)
            .foregroundStyle(motor.isSold && column != .notes ? .secondary : .primary)
            .font(.system(size: 11))
            .frame(width: column.width, height: rowHeight, alignment: column.alignment)
            .padding(.horizontal, 4)
            .overlay(
                Rectangle()
                    .stroke(gridLineColor, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
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
        .frame(width: MotorListViewOptimized.Column.action.width, height: rowHeight, alignment: .center)
        .overlay(
            Rectangle()
                .stroke(gridLineColor, lineWidth: 0.5)
        )
    }
}
