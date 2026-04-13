import SwiftUI
import Combine

#if false

struct MotorListViewExcel: View {
    let motors: [MotorRowDTO]
    let isLoading: Bool
    let totalCount: Int
    let onToggleSold: (Int64) -> Void
    let onLoadMore: () -> Void
    let onDuplicate: ((Int64) -> Void)?
    let onExportSelected: ((Int64) -> Void)?
    let onOpenDetails: ((Int64) -> Void)?
    let onSaveMotorRow: (Int64, MotorInlineDraft) -> Void
    let onCreateMotor: ((MotorInlineDraft) -> Void)?

    @StateObject private var tableViewModel = MotorGridTableViewModel(minVisibleRows: 20)
    @FocusState private var focusedCell: EditableCellID?
    @State private var tableScale: CGFloat = 1.0
    private var rowHeight: CGFloat { 38 * tableScale }
    private var headerHeight: CGFloat { 34 * tableScale }
    private let actionsWidth: CGFloat = 140
    private let maxTableContentWidth: CGFloat = 1320

    init(
        motors: [MotorRowDTO],
        selectedMotorIDs: Set<Int64> = [],
        isLoading: Bool,
        totalCount: Int,
        onToggleSold: @escaping (Int64) -> Void,
        onLoadMore: @escaping () -> Void,
        onDuplicate: ((Int64) -> Void)?,
        onExportSelected: ((Int64) -> Void)?,
        onOpenDetails: ((Int64) -> Void)?,
        onSaveMotorRow: @escaping (Int64, MotorInlineDraft) -> Void,
        onCreateMotor: ((MotorInlineDraft) -> Void)? = nil
    ) {
        self.motors = motors
        self.isLoading = isLoading
        self.totalCount = totalCount
        self.onToggleSold = onToggleSold
        self.onLoadMore = onLoadMore
        self.onDuplicate = onDuplicate
        self.onExportSelected = onExportSelected
        self.onOpenDetails = onOpenDetails
        self.onSaveMotorRow = onSaveMotorRow
        self.onCreateMotor = onCreateMotor
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .padding(.vertical, 8)
            }

            ZStack(alignment: .bottomTrailing) {
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(spacing: 0) {
                        gridHeader
                            .background(Platform.windowBackgroundColor)
                            .zIndex(1)
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(tableViewModel.rows.enumerated()), id: \.element.id) { index, row in
                                    MotorGridRowView(
                                        row: row,
                                        rowIndex: index + 1,
                                        rowHeight: rowHeight,
                                        actionsWidth: actionsWidth * tableScale,
                                        focusedCell: $focusedCell,
                                        onChange: { column, value in
                                            tableViewModel.handleCellChange(
                                                rowID: row.id,
                                                column: column,
                                                value: value,
                                                onExistingMotorEdit: { motorID, field, newValue in
                                                    onCellSave(motorID, field, newValue)
                                                },
                                                onCreateFromDraft: { draft in
                                                    onCreateMotor?(draft)
                                                }
                                            )
                                        },
                                        onSubmit: { column in
                                            moveFocus(from: row.id, column: column, direction: .down)
                                        },
                                        onTapCell: { column in
                                            focusedCell = EditableCellID(rowID: row.id, column: column)
                                        },
                                        onToggleSold: {
                                            if let motorID = row.motorID {
                                                onToggleSold(motorID)
                                            }
                                        },
                                        onOpenDetails: {
                                            if let motorID = row.motorID {
                                                onOpenDetails?(motorID)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .frame(width: min(maxTableContentWidth, tableTotalWidth), alignment: .leading)
                }
                .background(Platform.textBackgroundColor)
                .padding(.leading, 12)

                zoomSlider
                    .padding(.trailing, 14)
                    .padding(.bottom, 10)
            }

            HStack {
                Text("Показано \(motors.count) из \(totalCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Platform.windowBackgroundColor)
        }
        .onAppear {
            tableViewModel.reload(from: motors)
            if let first = tableViewModel.rows.first {
                focusedCell = EditableCellID(rowID: first.id, column: .serial)
            }
        }
        .onChange(of: motors) { _, newValue in
            tableViewModel.reload(from: newValue)
        }
        .background(
            KeyboardHandler(
                onTab: { moveFocusedCell(.right) },
                onShiftTab: { moveFocusedCell(.left) },
                onEnter: { moveFocusedCell(.down) },
                onEscape: { focusedCell = nil },
                onArrowUp: { moveFocusedCell(.up) },
                onArrowDown: { moveFocusedCell(.down) },
                onArrowLeft: { moveFocusedCell(.left) },
                onArrowRight: { moveFocusedCell(.right) }
            )
        )
    }

    private var gridHeader: some View {
        HStack(spacing: 0) {
            Text("#")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: headerHeight)
                .background(Platform.windowBackgroundColor)
                .overlay(alignment: .trailing) { divider }

            ForEach(MotorGridColumn.allCases) { column in
                Text(column.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: column.width * tableScale, height: headerHeight, alignment: .leading)
                    .padding(.horizontal, 6)
                    .background(Platform.windowBackgroundColor)
                    .overlay(alignment: .trailing) { divider }
            }

            Text("Действие")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: actionsWidth * tableScale, height: headerHeight, alignment: .leading)
                .padding(.horizontal, 6)
                .background(Platform.windowBackgroundColor)
        }
    }

    private var tableTotalWidth: CGFloat {
        let columnsWidth = MotorGridColumn.allCases.reduce(CGFloat(0)) { $0 + ($1.width * tableScale) }
        return 40 + columnsWidth + (actionsWidth * tableScale)
    }

    private var zoomSlider: some View {
        HStack(spacing: 8) {
            Image(systemName: "minus.magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Slider(value: $tableScale, in: 0.85...1.25, step: 0.01)
                .frame(width: 110)
            Image(systemName: "plus.magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Platform.windowBackgroundColor.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Platform.separatorColor.opacity(0.35), lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Platform.separatorColor.opacity(0.45))
            .frame(width: 1)
    }

    private enum FocusDirection {
        case up, down, left, right
    }

    private func moveFocusedCell(_ direction: FocusDirection) {
        guard let current = focusedCell else { return }
        moveFocus(from: current.rowID, column: current.column, direction: direction)
    }

    private func moveFocus(from rowID: UUID, column: MotorGridColumn, direction: FocusDirection) {
        guard let rowIndex = tableViewModel.rows.firstIndex(where: { $0.id == rowID }),
              let columnIndex = MotorGridColumn.allCases.firstIndex(of: column) else { return }

        var newRow = rowIndex
        var newColumn = columnIndex

        switch direction {
        case .up:
            newRow = max(0, rowIndex - 1)
        case .down:
            newRow = min(tableViewModel.rows.count - 1, rowIndex + 1)
        case .left:
            newColumn = max(0, columnIndex - 1)
        case .right:
            newColumn = min(MotorGridColumn.allCases.count - 1, columnIndex + 1)
        }

        let targetRowID = tableViewModel.rows[newRow].id
        let targetColumn = MotorGridColumn.allCases[newColumn]
        focusedCell = EditableCellID(rowID: targetRowID, column: targetColumn)
    }
}

// MARK: - Table ViewModel

@MainActor
final class MotorGridTableViewModel: ObservableObject {
    @Published private(set) var rows: [MotorGridRowViewModel] = []

    private let minVisibleRows: Int
    private var saveTasks: [String: Task<Void, Never>] = [:]
    private var pendingCreateRows: Set<UUID> = []

    init(minVisibleRows: Int) {
        self.minVisibleRows = minVisibleRows
    }

    func reload(from motors: [MotorRowDTO]) {
        let existing = Dictionary(uniqueKeysWithValues: rows.compactMap { row in
            row.motorID.map { ($0, row) }
        })

        var mapped = motors.map { dto -> MotorGridRowViewModel in
            if let cached = existing[dto.id] {
                cached.update(from: dto)
                return cached
            }
            return MotorGridRowViewModel(dto: dto)
        }

        let fillerCount = max(minVisibleRows - mapped.count, 0)
        if fillerCount > 0 {
            mapped.append(contentsOf: (0..<fillerCount).map { _ in MotorGridRowViewModel.empty() })
        }

        rows = mapped
        pendingCreateRows = pendingCreateRows.filter { rowID in rows.contains(where: { $0.id == rowID }) }
    }

    func handleCellChange(
        rowID: UUID,
        column: MotorGridColumn,
        value: String,
        onExistingMotorEdit: @escaping (Int64, EditableCellState.EditableField, String) -> Void,
        onCreateFromDraft: @escaping (MotorInlineDraft) -> Void
    ) {
        guard let row = rows.first(where: { $0.id == rowID }) else { return }
        row.setValue(value, for: column)

        if let motorID = row.motorID {
            let field = column.field
            let key = "\(motorID)-\(field.rawValue)"
            saveTasks[key]?.cancel()
            saveTasks[key] = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !Task.isCancelled else { return }
                onExistingMotorEdit(motorID, field, row.value(for: column))
            }
            return
        }

        guard row.motorID == nil, !pendingCreateRows.contains(row.id) else { return }
        if row.hasAnyData {
            pendingCreateRows.insert(row.id)
            onCreateFromDraft(row.draftInput)
        }
    }
}

// MARK: - Row View

private struct MotorGridRowView: View {
    @ObservedObject var row: MotorGridRowViewModel
    let rowIndex: Int
    let rowHeight: CGFloat
    let actionsWidth: CGFloat
    @FocusState.Binding var focusedCell: EditableCellID?
    let onChange: (MotorGridColumn, String) -> Void
    let onSubmit: (MotorGridColumn) -> Void
    let onTapCell: (MotorGridColumn) -> Void
    let onToggleSold: () -> Void
    let onOpenDetails: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Text("\(rowIndex)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: rowHeight)
                .background(rowBackground)
                .overlay(alignment: .trailing) { divider }

            ForEach(MotorGridColumn.allCases) { column in
                EditableCellView(
                    text: Binding(
                        get: { row.value(for: column) },
                        set: { onChange(column, $0) }
                    ),
                    column: column,
                    tableScale: rowHeight / 38.0,
                    rowID: row.id,
                    rowHeight: rowHeight,
                    focusedCell: $focusedCell,
                    onSubmit: { onSubmit(column) },
                    onTap: { onTapCell(column) }
                )
                .background(rowBackground)
                .overlay(alignment: .trailing) { divider }
            }

            HStack(spacing: 6) {
                if row.motorID != nil {
                    Button(row.isSold ? "Вернуть" : "Продать", action: onToggleSold)
                        .buttonStyle(.borderless)
                    Button("Детали", action: onOpenDetails)
                        .buttonStyle(.borderless)
                }
            }
            .font(.system(size: 11, weight: .medium))
            .frame(width: actionsWidth, height: rowHeight)
            .padding(.horizontal, 6)
            .background(rowBackground)
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    private var rowBackground: Color {
        if isHovered {
            return Platform.controlAccentColor.opacity(0.06)
        }
        return Color.clear
    }

    private var divider: some View {
        Rectangle().fill(Platform.separatorColor.opacity(0.35)).frame(width: 1)
    }
}

// MARK: - Cell View

private struct EditableCellView: View {
    @Binding var text: String
    let column: MotorGridColumn
    let tableScale: CGFloat
    let rowID: UUID
    let rowHeight: CGFloat
    @FocusState.Binding var focusedCell: EditableCellID?
    let onSubmit: () -> Void
    let onTap: () -> Void

    var body: some View {
        let isFocused = focusedCell == EditableCellID(rowID: rowID, column: column)
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 6)
            .frame(width: column.width * tableScale, height: rowHeight, alignment: column.alignment)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isFocused ? Platform.controlAccentColor.opacity(0.14) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(isFocused ? Platform.controlAccentColor.opacity(0.8) : .clear, lineWidth: 1)
            )
            .focused($focusedCell, equals: EditableCellID(rowID: rowID, column: column))
            .onTapGesture { onTap() }
            .onSubmit(onSubmit)
    }
}

// MARK: - Models

struct MotorInlineDraft {
    let serialCode: String
    let configuration: String
    let notes: String
    let quantity: String
    let transmission: String
    let arrivalDate: String
    let soldDate: String
}

private struct EditableCellID: Hashable {
    let rowID: UUID
    let column: MotorGridColumn
}

enum MotorGridColumn: String, CaseIterable, Identifiable {
    case serial
    case configuration
    case notes
    case quantity
    case transmission
    case arrivalDate
    case soldDate

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
        }
    }

    var width: CGFloat {
        switch self {
        case .serial: return 180
        case .configuration: return 180
        case .notes: return 260
        case .quantity: return 80
        case .transmission: return 120
        case .arrivalDate, .soldDate: return 140
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

    var field: EditableCellState.EditableField {
        switch self {
        case .serial: return .serialCode
        case .configuration: return .configuration
        case .notes: return .notes
        case .quantity: return .quantity
        case .transmission: return .transmission
        case .arrivalDate: return .arrivalDate
        case .soldDate: return .soldDate
        }
    }
}

@MainActor
final class MotorGridRowViewModel: ObservableObject, Identifiable {
    let id: UUID
    let motorID: Int64?

    @Published var serialCode: String
    @Published var configuration: String
    @Published var notes: String
    @Published var quantity: String
    @Published var transmission: String
    @Published var arrivalDate: String
    @Published var soldDate: String
    @Published var isSold: Bool

    init(
        id: UUID = UUID(),
        motorID: Int64?,
        serialCode: String,
        configuration: String,
        notes: String,
        quantity: String,
        transmission: String,
        arrivalDate: String,
        soldDate: String,
        isSold: Bool
    ) {
        self.id = id
        self.motorID = motorID
        self.serialCode = serialCode
        self.configuration = configuration
        self.notes = notes
        self.quantity = quantity
        self.transmission = transmission
        self.arrivalDate = arrivalDate
        self.soldDate = soldDate
        self.isSold = isSold
    }

    convenience init(dto: MotorRowDTO) {
        self.init(
            motorID: dto.id,
            serialCode: dto.serialCode,
            configuration: dto.configuration,
            notes: dto.notes,
            quantity: dto.quantity,
            transmission: dto.transmission,
            arrivalDate: dto.arrivalDate,
            soldDate: dto.soldDate,
            isSold: dto.isSold
        )
    }

    static func empty() -> MotorGridRowViewModel {
        MotorGridRowViewModel(
            motorID: nil,
            serialCode: "",
            configuration: "",
            notes: "",
            quantity: "",
            transmission: "",
            arrivalDate: "",
            soldDate: "",
            isSold: false
        )
    }

    var hasAnyData: Bool {
        !serialCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !configuration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !transmission.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !arrivalDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !soldDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var draftInput: MotorInlineDraft {
        MotorInlineDraft(
            serialCode: serialCode,
            configuration: configuration,
            notes: notes,
            quantity: quantity,
            transmission: transmission,
            arrivalDate: arrivalDate,
            soldDate: soldDate
        )
    }

    func value(for column: MotorGridColumn) -> String {
        switch column {
        case .serial: return serialCode
        case .configuration: return configuration
        case .notes: return notes
        case .quantity: return quantity
        case .transmission: return transmission
        case .arrivalDate: return arrivalDate
        case .soldDate: return soldDate
        }
    }

    func setValue(_ value: String, for column: MotorGridColumn) {
        switch column {
        case .serial: serialCode = value
        case .configuration: configuration = value
        case .notes: notes = value
        case .quantity: quantity = value
        case .transmission: transmission = value
        case .arrivalDate: arrivalDate = value
        case .soldDate: soldDate = value
        }
    }

    func update(from dto: MotorRowDTO) {
        serialCode = dto.serialCode
        configuration = dto.configuration
        notes = dto.notes
        quantity = dto.quantity
        transmission = dto.transmission
        arrivalDate = dto.arrivalDate
        soldDate = dto.soldDate
        isSold = dto.isSold
    }
}
#endif

import SwiftUI
import Combine

struct MotorListViewExcel: View {
#if os(macOS)
    /// AppKit Excel-like grid (virtualized); set `false` to use legacy SwiftUI `LazyVGrid`.
    private static let useAppKitGridCore = true
#endif

    let motors: [MotorRowDTO]
    let isLoading: Bool
    let totalCount: Int
    let userConfig: UserConfig?
    let onToggleSold: (Int64) -> Void
    let onLoadMore: () -> Void
    let onDuplicate: ((Int64) -> Void)?
    let onExportSelected: ((Int64) -> Void)?
    let onOpenDetails: ((Int64) -> Void)?
    let onSaveMotorRow: (Int64, MotorInlineDraft) -> Void
    let onCreateMotor: ((MotorInlineDraft) -> Void)?

    @StateObject private var viewModel = MotorGridTableViewModel()
    @FocusState private var focusedCell: GridFocusID?
    @State private var tableZoom: CGFloat = 1.0
    @State private var saveStatusText: String = "Все сохранено"
#if os(macOS)
    @State private var appKitHasUnsavedChanges = false
#endif

    private var rowHeight: CGFloat { 38 * tableZoom }
    private var headerHeight: CGFloat { 34 * tableZoom }

    private var baseColumns: [ColumnDef] {
        [
            .init(key: .rowNumber, title: "#", width: 40 * tableZoom, alignment: .center, editableField: nil),
            .init(key: .engineNumber, title: "Номер двигателя", width: 180 * tableZoom, alignment: .leading, editableField: .serialCode),
            .init(key: .configuration, title: "Комплектация", width: 180 * tableZoom, alignment: .leading, editableField: .configuration),
            .init(key: .notes, title: "Особые отметки", width: 220 * tableZoom, alignment: .leading, editableField: .notes),
            .init(key: .quantity, title: "Кол-во", width: 80 * tableZoom, alignment: .center, editableField: .quantity),
            .init(key: .transmission, title: "Коробка", width: 120 * tableZoom, alignment: .leading, editableField: .transmission),
            .init(key: .arrivalDate, title: "Дата прихода", width: 140 * tableZoom, alignment: .center, editableField: .arrivalDate),
            .init(key: .soldDate, title: "Дата продажи", width: 140 * tableZoom, alignment: .center, editableField: .soldDate),
            .init(key: .action, title: "", width: 110 * tableZoom, alignment: .center, editableField: nil)
        ]
    }

    private var columns: [ColumnDef] {
        guard let userConfig else { return baseColumns }

        var map = Dictionary(uniqueKeysWithValues: baseColumns.map { ($0.key, $0) })
        var dynamic: [ColumnDef] = [map.removeValue(forKey: .rowNumber)!]

        for item in userConfig.columns where item.isVisible {
            guard let key = ColumnKey(userConfigID: item.id), var col = map[key] else { continue }
            col = .init(
                key: col.key,
                title: item.title,
                width: col.width,
                alignment: col.alignment,
                editableField: col.editableField
            )
            dynamic.append(col)
            map.removeValue(forKey: key)
        }

        if userConfig.showSaleDate == false {
            dynamic.removeAll(where: { $0.key == .soldDate })
        }
        if !dynamic.contains(where: { $0.key != .rowNumber && $0.key != .action }) {
            if let engine = baseColumns.first(where: { $0.key == .engineNumber }) {
                dynamic.append(engine)
            }
        }
        if let action = baseColumns.first(where: { $0.key == .action }) {
            dynamic.append(action)
        }
        return dynamic
    }

    private var gridItems: [GridItem] {
        columns.map { GridItem(.fixed($0.width), spacing: 0, alignment: .leading) }
    }

    private var tableContentWidth: CGFloat {
        columns.reduce(CGFloat(0)) { $0 + $1.width }
    }

    init(
        motors: [MotorRowDTO],
        selectedMotorIDs: Set<Int64> = [],
        isLoading: Bool,
        totalCount: Int,
        userConfig: UserConfig? = nil,
        onToggleSold: @escaping (Int64) -> Void,
        onLoadMore: @escaping () -> Void,
        onDuplicate: ((Int64) -> Void)?,
        onExportSelected: ((Int64) -> Void)?,
        onOpenDetails: ((Int64) -> Void)?,
        onSaveMotorRow: @escaping (Int64, MotorInlineDraft) -> Void,
        onCreateMotor: ((MotorInlineDraft) -> Void)? = nil
    ) {
        self.motors = motors
        self.isLoading = isLoading
        self.totalCount = totalCount
        self.userConfig = userConfig
        self.onToggleSold = onToggleSold
        self.onLoadMore = onLoadMore
        self.onDuplicate = onDuplicate
        self.onExportSelected = onExportSelected
        self.onOpenDetails = onOpenDetails
        self.onSaveMotorRow = onSaveMotorRow
        self.onCreateMotor = onCreateMotor
    }

    var body: some View {
        Group {
#if os(macOS)
            if Self.useAppKitGridCore {
                appKitGridContent
            } else {
                legacyGridContent
            }
#else
            legacyGridContent
#endif
        }
    }

#if os(macOS)
    @ViewBuilder
    private var appKitGridContent: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView().padding(.vertical, 8)
            }
            ZStack(alignment: .bottomTrailing) {
                ExcelGridMotorSheetRepresentable(
                    motors: motors,
                    userConfig: userConfig,
                    zoom: tableZoom,
                    onToggleSold: onToggleSold,
                    onUnsavedChange: { appKitHasUnsavedChanges = $0 },
                    onZoomChange: { tableZoom = $0 },
                    onSaveMotorRow: onSaveMotorRow,
                    onCreateMotor: { draft in onCreateMotor?(draft) },
                    onSaveFinished: { didSave in
                        saveStatusText = didSave ? "Сохранено" : (appKitHasUnsavedChanges ? "Не сохранено" : "Все сохранено")
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                appKitZoomControl
            }
            .background(Platform.textBackgroundColor)

            HStack {
                Text("Показано \(motors.count) из \(totalCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("• \(saveStatusText)")
                    .font(.caption)
                    .foregroundStyle(appKitHasUnsavedChanges ? .orange : .secondary)
                Button("Сохранить (Cmd+S)") {
                    NotificationCenter.default.post(name: .motorGridSaveRequested, object: nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .disabled(!appKitHasUnsavedChanges)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Platform.windowBackgroundColor)
        }
        .onChange(of: appKitHasUnsavedChanges) { _, newValue in
            if !newValue {
                saveStatusText = "Все сохранено"
            } else {
                saveStatusText = "Не сохранено"
            }
        }
    }

    private var appKitZoomControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { tableZoom },
                    set: { tableZoom = min(max($0, 0.75), 1.6) }
                ),
                in: 0.75...1.6,
                step: 0.01
            )
            .frame(width: 110)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Platform.windowBackgroundColor.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Platform.separatorColor.opacity(0.4), lineWidth: 1)
        )
        .padding(.trailing, 12)
        .padding(.bottom, 10)
    }
#endif

    @ViewBuilder
    private var legacyGridContent: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView().padding(.vertical, 8)
            }

            ZStack(alignment: .bottomTrailing) {
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(spacing: 0) {
                        headerRow
                            .background(Platform.windowBackgroundColor)
                            .zIndex(1)

                        Divider().overlay(Platform.separatorColor.opacity(0.35))

                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(viewModel.rows.enumerated()), id: \.element.id) { index, row in
                                    MotorGridDataRow(
                                        row: row,
                                        rowNumber: index + 1,
                                        columns: columns,
                                        gridItems: gridItems,
                                        rowHeight: rowHeight,
                                        focusedCell: $focusedCell,
                                        onCellTap: { columnKey in
                                            focusedCell = GridFocusID(rowID: row.id, column: columnKey)
                                        },
                                        onCellSubmit: { columnKey in
                                            moveFocus(from: row.id, column: columnKey, direction: .down)
                                        },
                                        onCellChange: { columnKey, value in
                                            viewModel.handleCellChange(
                                                rowID: row.id,
                                                column: columnKey,
                                                value: value
                                            )
                                        },
                                        onSellTap: {
                                            if let motorID = row.motorID {
                                                onToggleSold(motorID)
                                            }
                                        },
                                        onAppear: {
                                            viewModel.expandIfNeeded(visibleRowID: row.id)
                                        }
                                    )
                                }
                            }
                            .frame(width: tableContentWidth, alignment: .leading)
                        }
                    }
                    .frame(width: tableContentWidth, alignment: .leading)
                }
                zoomControl
            }
            .background(Platform.textBackgroundColor)

            HStack {
                Text("Показано \(motors.count) из \(totalCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("• \(saveStatusText)")
                    .font(.caption)
                    .foregroundStyle(viewModel.hasUnsavedChanges ? .orange : .secondary)
                Button("Сохранить (Cmd+S)") {
                    saveAllChanges()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .disabled(!viewModel.hasUnsavedChanges)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Platform.windowBackgroundColor)
        }
        .onAppear {
            viewModel.reload(from: motors)
            publishUnsavedState()
            if let first = viewModel.rows.first {
                focusedCell = GridFocusID(rowID: first.id, column: .engineNumber)
            }
        }
        .onChange(of: motors) { _, newValue in
            viewModel.reload(from: newValue)
        }
        .onChange(of: viewModel.hasUnsavedChanges) { _, _ in
            publishUnsavedState()
            saveStatusText = viewModel.hasUnsavedChanges ? "Не сохранено" : "Все сохранено"
        }
        .onReceive(NotificationCenter.default.publisher(for: .motorGridSaveRequested)) { _ in
            saveAllChanges()
        }
        .background(
            KeyboardHandler(
                onTab: { moveFocusedCell(.right) },
                onShiftTab: { moveFocusedCell(.left) },
                onEnter: { moveFocusedCell(.down) },
                onEscape: { focusedCell = nil },
                onArrowUp: { moveFocusedCell(.up) },
                onArrowDown: { moveFocusedCell(.down) },
                onArrowLeft: { moveFocusedCell(.left) },
                onArrowRight: { moveFocusedCell(.right) }
            )
        )
    }

    private var zoomControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Slider(value: $tableZoom, in: 0.85...1.25, step: 0.01)
                .frame(width: 110)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Platform.windowBackgroundColor.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Platform.separatorColor.opacity(0.4), lineWidth: 1)
        )
        .padding(.trailing, 12)
        .padding(.bottom, 10)
    }

    private var headerRow: some View {
        LazyVGrid(columns: gridItems, spacing: 0) {
            ForEach(columns) { column in
                Text(column.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: column.alignment)
                    .padding(.horizontal, 6)
                    .background(Platform.windowBackgroundColor)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Platform.separatorColor.opacity(0.35))
                            .frame(width: 1)
                    }
            }
        }
        .frame(width: tableContentWidth, height: headerHeight, alignment: .leading)
    }

    private enum FocusDirection { case up, down, left, right }

    private func moveFocusedCell(_ direction: FocusDirection) {
        guard let current = focusedCell else { return }
        moveFocus(from: current.rowID, column: current.column, direction: direction)
    }

    private func moveFocus(from rowID: UUID, column: ColumnKey, direction: FocusDirection) {
        guard let rowIndex = viewModel.rows.firstIndex(where: { $0.id == rowID }),
              let columnIndex = columns.firstIndex(where: { $0.key == column }) else { return }

        var newRow = rowIndex
        var newColumn = columnIndex

        switch direction {
        case .up: newRow = max(0, rowIndex - 1)
        case .down: newRow = min(viewModel.rows.count - 1, rowIndex + 1)
        case .left: newColumn = max(1, columnIndex - 1) // skip #
        case .right: newColumn = min(columns.count - 1, columnIndex + 1)
        }

        if direction == .down {
            viewModel.expandIfNeeded(visibleRowIndex: newRow)
        }

        let target = columns[newColumn].key
        if target == .rowNumber { return }
        focusedCell = GridFocusID(rowID: viewModel.rows[newRow].id, column: target)
    }

    private func saveAllChanges() {
        let didSave = viewModel.saveAllChanges(
            onExistingMotorSave: { motorID, draft in
                onSaveMotorRow(motorID, draft)
            },
            onCreateFromDraft: { draft in
                onCreateMotor?(draft)
            }
        )
        saveStatusText = didSave ? "Сохранено" : (viewModel.hasUnsavedChanges ? "Не сохранено" : "Все сохранено")
    }

    private func publishUnsavedState() {
        NotificationCenter.default.post(name: .motorGridUnsavedChangesChanged, object: viewModel.hasUnsavedChanges)
    }
}

@MainActor
final class MotorGridTableViewModel: ObservableObject {
    @Published private(set) var rows: [MotorGridRowViewModel] = []
    @Published private(set) var hasUnsavedChanges: Bool = false

    private let baseVisibleEmptyRows = 120
    private let expandBatchSize = 80
    private let expandThreshold = 24
    private var pendingDraftByMotorID: [Int64: MotorInlineDraft] = [:]
    private var pendingCreateRows: Set<UUID> = []

    init() {}

    func reload(from motors: [MotorRowDTO]) {
        let existingByMotorID = Dictionary(uniqueKeysWithValues: rows.compactMap { row in
            row.motorID.map { ($0, row) }
        })
        var mapped = motors.map { dto -> MotorGridRowViewModel in
            if let existing = existingByMotorID[dto.id] {
                existing.update(from: dto)
                if let pendingDraft = pendingDraftByMotorID[dto.id] {
                    existing.engineNumber = pendingDraft.serialCode
                    existing.configuration = pendingDraft.configuration
                    existing.notes = pendingDraft.notes
                    existing.quantity = pendingDraft.quantity
                    existing.transmission = pendingDraft.transmission
                    existing.arrivalDate = pendingDraft.arrivalDate
                    existing.soldDate = pendingDraft.soldDate
                }
                return existing
            }
            return MotorGridRowViewModel(dto: dto)
        }
        let fillers = max(baseVisibleEmptyRows - mapped.count, 0)
        if fillers > 0 {
            mapped.append(contentsOf: (0..<fillers).map { _ in .empty() })
        }
        rows = mapped
        pendingCreateRows = pendingCreateRows.filter { id in rows.contains(where: { $0.id == id }) }
        updateDirtyState()
    }

    func handleCellChange(
        rowID: UUID,
        column: ColumnKey,
        value: String
    ) {
        guard let row = rows.first(where: { $0.id == rowID }) else { return }
        row.setValue(value, for: column)

        guard column != .rowNumber else { return }

        if let motorID = row.motorID {
            pendingDraftByMotorID[motorID] = row.draftInput
            updateDirtyState()
            return
        }

        guard row.motorID == nil else { return }
        if row.hasAnyData {
            pendingCreateRows.insert(row.id)
        } else {
            pendingCreateRows.remove(row.id)
        }
        updateDirtyState()
        expandIfNeeded(visibleRowID: rowID)
    }

    func expandIfNeeded(visibleRowID: UUID) {
        guard let index = rows.firstIndex(where: { $0.id == visibleRowID }) else { return }
        expandIfNeeded(visibleRowIndex: index)
    }

    func expandIfNeeded(visibleRowIndex: Int) {
        guard !rows.isEmpty else { return }
        let distanceToEnd = rows.count - visibleRowIndex - 1
        guard distanceToEnd <= expandThreshold else { return }
        rows.append(contentsOf: (0..<expandBatchSize).map { _ in .empty() })
    }

    func saveAllChanges(
        onExistingMotorSave: @escaping (Int64, MotorInlineDraft) -> Void,
        onCreateFromDraft: @escaping (MotorInlineDraft) -> Void
    ) -> Bool {
        var didSaveAnything = false

        for (motorID, draft) in pendingDraftByMotorID {
            onExistingMotorSave(motorID, draft)
            didSaveAnything = true
        }

        for row in rows where row.motorID == nil && row.hasAnyData {
            onCreateFromDraft(row.draftInput)
            didSaveAnything = true
        }

        pendingDraftByMotorID.removeAll()
        pendingCreateRows.removeAll()
        updateDirtyState()
        return didSaveAnything
    }

    private func updateDirtyState() {
        hasUnsavedChanges = !pendingDraftByMotorID.isEmpty || !pendingCreateRows.isEmpty
    }
}

private struct MotorGridDataRow: View {
    @ObservedObject var row: MotorGridRowViewModel
    let rowNumber: Int
    let columns: [ColumnDef]
    let gridItems: [GridItem]
    let rowHeight: CGFloat
    @FocusState.Binding var focusedCell: GridFocusID?
    let onCellTap: (ColumnKey) -> Void
    let onCellSubmit: (ColumnKey) -> Void
    let onCellChange: (ColumnKey, String) -> Void
    let onSellTap: () -> Void
    let onAppear: () -> Void

    @State private var isHovering = false

    var body: some View {
        LazyVGrid(columns: gridItems, spacing: 0) {
            ForEach(columns) { column in
                cell(for: column)
            }
        }
        .frame(height: rowHeight)
        .background(isHovering ? Platform.controlAccentColor.opacity(0.05) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Platform.separatorColor.opacity(0.2)).frame(height: 1)
        }
        .onHover { isHovering = $0 }
        .onAppear(perform: onAppear)
    }

    @ViewBuilder
    private func cell(for column: ColumnDef) -> some View {
        if column.key == .rowNumber {
            Text("\(rowNumber)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .overlay(alignment: .trailing) { verticalDivider }
        } else if column.key == .action {
            Button("Продать") {
                onSellTap()
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11, weight: .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .overlay(alignment: .trailing) { verticalDivider }
        } else {
            MotorGridEditableCell(
                text: Binding(
                    get: { row.value(for: column.key) },
                    set: { onCellChange(column.key, $0) }
                ),
                placeholder: column.key.placeholder,
                column: column,
                rowID: row.id,
                focusedCell: $focusedCell,
                onTap: { onCellTap(column.key) },
                onSubmit: { onCellSubmit(column.key) }
            )
            .overlay(alignment: .trailing) { verticalDivider }
        }
    }

    private var verticalDivider: some View {
        Rectangle().fill(Platform.separatorColor.opacity(0.25)).frame(width: 1)
    }
}

private struct MotorGridEditableCell: View {
    @Binding var text: String
    let placeholder: String
    let column: ColumnDef
    let rowID: UUID
    @FocusState.Binding var focusedCell: GridFocusID?
    let onTap: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        let focusID = GridFocusID(rowID: rowID, column: column.key)
        let isActive = focusedCell == focusID

        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: column.alignment)
            .padding(.horizontal, 6)
            .background(
                Rectangle()
                    .fill(isActive ? Platform.controlAccentColor.opacity(0.18) : .clear)
            )
            .overlay(
                Rectangle()
                    .stroke(isActive ? Platform.controlAccentColor.opacity(0.85) : .clear, lineWidth: isActive ? 1.5 : 0)
            )
            .focused($focusedCell, equals: focusID)
            .onTapGesture { onTap() }
            .onSubmit(onSubmit)
    }
}

struct MotorInlineDraft {
    let serialCode: String
    let configuration: String
    let notes: String
    let quantity: String
    let transmission: String
    let arrivalDate: String
    let soldDate: String
}

struct GridFocusID: Hashable {
    let rowID: UUID
    let column: ColumnKey
}

struct ColumnDef: Identifiable {
    let key: ColumnKey
    let title: String
    let width: CGFloat
    let alignment: Alignment
    let editableField: EditableCellState.EditableField?
    var id: ColumnKey { key }
}

enum ColumnKey: String, CaseIterable, Hashable {
    case rowNumber
    case engineNumber
    case configuration
    case notes
    case quantity
    case transmission
    case arrivalDate
    case soldDate
    case action

    init?(userConfigID: String) {
        switch userConfigID {
        case "engineNumber": self = .engineNumber
        case "configuration": self = .configuration
        case "notes": self = .notes
        case "quantity": self = .quantity
        case "transmission": self = .transmission
        case "arrivalDate": self = .arrivalDate
        case "soldDate": self = .soldDate
        default: return nil
        }
    }

    var editableField: EditableCellState.EditableField? {
        switch self {
        case .rowNumber: return nil
        case .engineNumber: return .serialCode
        case .configuration: return .configuration
        case .notes: return .notes
        case .quantity: return .quantity
        case .transmission: return .transmission
        case .arrivalDate: return .arrivalDate
        case .soldDate: return .soldDate
        case .action: return nil
        }
    }

    var placeholder: String {
        ""
    }
}

@MainActor
final class MotorGridRowViewModel: ObservableObject, Identifiable {
    let id: UUID
    let motorID: Int64?

    @Published var engineNumber: String
    @Published var configuration: String
    @Published var notes: String
    @Published var quantity: String
    @Published var transmission: String
    @Published var arrivalDate: String
    @Published var soldDate: String

    init(
        id: UUID = UUID(),
        motorID: Int64?,
        engineNumber: String,
        configuration: String,
        notes: String,
        quantity: String,
        transmission: String,
        arrivalDate: String,
        soldDate: String
    ) {
        self.id = id
        self.motorID = motorID
        self.engineNumber = engineNumber
        self.configuration = configuration
        self.notes = notes
        self.quantity = quantity
        self.transmission = transmission
        self.arrivalDate = arrivalDate
        self.soldDate = soldDate
    }

    convenience init(dto: MotorRowDTO) {
        self.init(
            motorID: dto.id,
            engineNumber: dto.serialCode,
            configuration: dto.configuration,
            notes: dto.notes,
            quantity: dto.quantity,
            transmission: dto.transmission,
            arrivalDate: dto.arrivalDate,
            soldDate: dto.soldDate
        )
    }

    static func empty() -> MotorGridRowViewModel {
        .init(
            motorID: nil,
            engineNumber: "",
            configuration: "",
            notes: "",
            quantity: "",
            transmission: "",
            arrivalDate: "",
            soldDate: ""
        )
    }

    var hasAnyData: Bool {
        !engineNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !configuration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !transmission.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !arrivalDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !soldDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var draftInput: MotorInlineDraft {
        .init(
            serialCode: engineNumber,
            configuration: configuration,
            notes: notes,
            quantity: quantity,
            transmission: transmission,
            arrivalDate: arrivalDate,
            soldDate: soldDate
        )
    }

    func value(for key: ColumnKey) -> String {
        switch key {
        case .rowNumber: return ""
        case .engineNumber: return engineNumber
        case .configuration: return configuration
        case .notes: return notes
        case .quantity: return quantity
        case .transmission: return transmission
        case .arrivalDate: return arrivalDate
        case .soldDate: return soldDate
        case .action: return ""
        }
    }

    func setValue(_ newValue: String, for key: ColumnKey) {
        switch key {
        case .rowNumber: break
        case .engineNumber: engineNumber = newValue
        case .configuration: configuration = newValue
        case .notes: notes = newValue
        case .quantity: quantity = newValue
        case .transmission: transmission = newValue
        case .arrivalDate: arrivalDate = newValue
        case .soldDate: soldDate = newValue
        case .action: break
        }
    }

    func update(from dto: MotorRowDTO) {
        engineNumber = dto.serialCode
        configuration = dto.configuration
        notes = dto.notes
        quantity = dto.quantity
        transmission = dto.transmission
        arrivalDate = dto.arrivalDate
        soldDate = dto.soldDate
    }
}
