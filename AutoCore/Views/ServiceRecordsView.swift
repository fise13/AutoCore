import SwiftUI
import Combine
import UniformTypeIdentifiers

#if os(macOS)

struct ServiceRecordsView: View {
    let records: [ServiceRecord]
    let specificRecords: [DatabaseService.SpecificRecord]
    let searchText: String
    let onSearchTextChange: (String) -> Void
    let isLoading: Bool
    let totalCount: Int
    let categoryName: String
    let onCellSave: ((Int64, String, String) -> Void)?
    let onDeleteRecord: ((Int64) -> Void)?

    @State private var tableZoom: CGFloat = 1.0
    @State private var saveStatusText: String = "Все сохранено"
    @State private var appKitHasUnsavedChanges = false

    fileprivate static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private var specificRows: [RecordDisplayItem] {
        records.map(RecordDisplayItem.fromServiceRecord) + specificRecords.map(RecordDisplayItem.fromSpecificRecord)
    }

    private var filteredSpecificRows: [RecordDisplayItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return specificRows }
        return specificRows.filter { item in
            item.data.contains { key, value in
                key.lowercased().contains(q) || value.lowercased().contains(q)
            }
        }
    }

    private var motorsForGrid: [MotorRowDTO] {
        let mapping = headerMapping
        return filteredSpecificRows.map { item in
            let slots = mapping.slotKeys
            return MotorRowDTO(
                id: item.id,
                serialCode: slots.indices.contains(0) ? (item.data[slots[0]] ?? "") : "",
                configuration: slots.indices.contains(1) ? (item.data[slots[1]] ?? "") : "",
                notes: slots.indices.contains(2) ? (item.data[slots[2]] ?? "") : "",
                quantity: slots.indices.contains(3) ? (item.data[slots[3]] ?? "") : "",
                transmission: slots.indices.contains(4) ? (item.data[slots[4]] ?? "") : "",
                arrivalDate: slots.indices.contains(5) ? (item.data[slots[5]] ?? "") : "",
                soldDate: slots.indices.contains(6) ? (item.data[slots[6]] ?? "") : "",
                isSold: false
            )
        }
    }

    private var byRecordID: [Int64: RecordDisplayItem] {
        Dictionary(uniqueKeysWithValues: filteredSpecificRows.map { ($0.id, $0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            if motorsForGrid.isEmpty && !isLoading {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: totalCount == 0 ? "Специфичных данных пока нет" : "Ничего не найдено",
                    message: totalCount == 0 ? "Они появятся после импорта или добавления" : "Попробуйте изменить запрос",
                    actionTitle: nil,
                    action: nil
                )
            } else {
                if isLoading {
                    ProgressView().padding(.vertical, 8)
                }

                ZStack(alignment: .bottomTrailing) {
                    ExcelGridMotorSheetRepresentable(
                        motors: motorsForGrid,
                        userConfig: headerMapping.userConfig,
                        zoom: tableZoom,
                        onToggleSold: { _ in },
                        onUnsavedChange: { appKitHasUnsavedChanges = $0 },
                        onZoomChange: { tableZoom = $0 },
                        onSaveMotorRow: { recordID, draft in
                            persistDraft(recordID: recordID, draft: draft)
                        },
                        onCreateMotor: { _ in },
                        onSaveFinished: { didSave in
                            saveStatusText = didSave ? "Сохранено" : (appKitHasUnsavedChanges ? "Не сохранено" : "Все сохранено")
                        }
                    )

                    zoomControl
                }
                .background(Platform.textBackgroundColor)

                HStack {
                    Text("Показано \(motorsForGrid.count) из \(totalCount)")
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
        }
        .background(DSColors.background)
        .searchable(text: Binding(
            get: { searchText },
            set: { onSearchTextChange($0) }
        ), prompt: "Поиск по номеру двигателя, данным, листу")
    }

    private var zoomControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Slider(value: $tableZoom, in: 0.75...1.4, step: 0.01)
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

    private func persistDraft(recordID: Int64, draft: MotorInlineDraft) {
        let header = headerMapping
        let previous = byRecordID[recordID]?.data ?? [:]
        let slots = header.slotKeys
        let values = [
            draft.serialCode,
            draft.configuration,
            draft.notes,
            draft.quantity,
            draft.transmission,
            draft.arrivalDate,
            draft.soldDate
        ]
        for (i, key) in slots.enumerated() where i < values.count {
            let value = values[i]
            if (previous[key] ?? "") != value {
                onCellSave?(recordID, key, value)
            }
        }
    }

    private var headerMapping: SpecificExcelHeaderMapping {
        SpecificExcelHeaderMapping.build(from: filteredSpecificRows)
    }
}

private struct SpecificExcelHeaderMapping {
    /// Ключи в `data`, которые занимают 7 фиксированных слотов сетки (по порядку).
    let slotKeys: [String]
    let userConfig: UserConfig
    
    private static let slotCount = 7
    private static let placeholderTitles = ["Поле 1", "Поле 2", "Поле 3", "Поле 4", "Поле 5", "Поле 6", "Поле 7"]
    private static let internalPrefixes: Set<String> = ["_"]
    private static let dateLikeNormalizedTokens: Set<String> = [
        "дата", "date", "datein", "dateout", "датаприхода", "датапродажи", "arrivaldate", "solddate"
    ]
    private static let numberLikeNormalizedTokens: Set<String> = [
        "колво", "количество", "qty", "quantity", "цена", "price", "сумма", "amount"
    ]

    static func build(from rows: [RecordDisplayItem]) -> SpecificExcelHeaderMapping {
        // 1) Prefer the explicit column order saved during import (`_columnOrder` JSON array).
        if let savedOrder = extractSavedColumnOrder(from: rows), !savedOrder.isEmpty {
            return makeMapping(from: savedOrder)
        }

        // 2) Fallback: derive an order from the actual data keys.
        var frequency: [String: Int] = [:]
        var firstSeenIndex: [String: Int] = [:]
        var counter = 0
        for row in rows {
            for key in row.data.keys where !key.hasPrefix("_") && !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                frequency[key, default: 0] += 1
                if firstSeenIndex[key] == nil {
                    firstSeenIndex[key] = counter
                    counter += 1
                }
            }
        }
        let orderedKeys = Array(frequency.keys).sorted { lhs, rhs in
            let lCount = frequency[lhs, default: 0]
            let rCount = frequency[rhs, default: 0]
            if lCount != rCount { return lCount > rCount }
            return (firstSeenIndex[lhs] ?? Int.max) < (firstSeenIndex[rhs] ?? Int.max)
        }
        return makeMapping(from: orderedKeys)
    }

    private static func makeMapping(from orderedKeys: [String]) -> SpecificExcelHeaderMapping {
        var slots: [String] = Array(orderedKeys.prefix(slotCount))
        while slots.count < slotCount {
            slots.append("")
        }

        let columns: [ColumnConfig] = (0..<slotCount).map { i in
            let title = slots[i].isEmpty ? placeholderTitles[i] : slots[i]
            let id = slots[i].isEmpty ? "field\(i)" : "col_\(slots[i])"
            return ColumnConfig(id: id, title: title, type: detectType(for: slots[i]), isVisible: true)
        }

        return SpecificExcelHeaderMapping(
            slotKeys: slots,
            userConfig: UserConfig(
                columns: columns,
                dateFormat: "dd.MM.yyyy",
                useAutoDate: false,
                showSaleDate: true,
                businessType: .custom
            )
        )
    }

    private static func extractSavedColumnOrder(from rows: [RecordDisplayItem]) -> [String]? {
        for row in rows {
            guard let json = row.data["_columnOrder"], !json.isEmpty,
                  let data = json.data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [String] else {
                continue
            }
            let cleaned = array
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.hasPrefix("_") }
            if !cleaned.isEmpty { return cleaned }
        }
        return nil
    }
    
    private static func detectType(for key: String) -> ColumnType {
        guard !key.isEmpty else { return .text }
        let normalized = key
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        for token in dateLikeNormalizedTokens where normalized.contains(token) {
            return .date
        }
        for token in numberLikeNormalizedTokens where normalized.contains(token) {
            return .number
        }
        return .text
    }
}

struct ServiceRecordsViewLegacy: View {
    let records: [ServiceRecord]
    let specificRecords: [DatabaseService.SpecificRecord]
    let searchText: String
    let onSearchTextChange: (String) -> Void
    let isLoading: Bool
    let totalCount: Int
    let categoryName: String
    let onCellSave: ((Int64, String, String) -> Void)?
    let onDeleteRecord: ((Int64) -> Void)?

    @StateObject private var viewModel = SpecificGridTableViewModel()
    @FocusState private var focusedCell: SpecificGridFocusID?
    @State private var selectionAnchor: SpecificGridFocusID?
    @State private var tableZoom: CGFloat = 1.0
    @State private var saveStatusText: String = "Все сохранено"

    fileprivate static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private var rowHeight: CGFloat { 28 * tableZoom }
    private var headerHeight: CGFloat { 30 * tableZoom }

    private var columns: [SpecificColumnDef] {
        var cols: [SpecificColumnDef] = [
            .init(key: .rowNumber, title: "#", width: 44 * tableZoom, alignment: .trailing, editable: false),
            .init(key: .serialCode, title: "Номер двигателя", width: 180 * tableZoom, alignment: .leading, editable: true),
            .init(key: .sheetName, title: "Лист", width: 150 * tableZoom, alignment: .leading, editable: true)
        ]
        cols.append(contentsOf: viewModel.dynamicFieldNames.map {
            .init(key: .dynamic($0), title: $0, width: 170 * tableZoom, alignment: .leading, editable: true)
        })
        cols.append(.init(key: .date, title: "Дата", width: 140 * tableZoom, alignment: .center, editable: false))
        return cols
    }

    private var gridItems: [GridItem] {
        columns.map { GridItem(.fixed($0.width), spacing: 0, alignment: .leading) }
    }

    private var tableContentWidth: CGFloat {
        columns.reduce(CGFloat(0)) { $0 + $1.width }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.rows.isEmpty && !isLoading {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: totalCount == 0 ? "Специфичных данных пока нет" : "Ничего не найдено",
                    message: totalCount == 0 ? "Они появятся после импорта или добавления" : "Попробуйте изменить запрос",
                    actionTitle: nil,
                    action: nil
                )
            } else {
                if isLoading {
                    ProgressView().padding(.vertical, 8)
                }

                ZStack(alignment: .bottomTrailing) {
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(spacing: 0) {
                            headerRow
                            Divider()
                            ScrollView(.vertical, showsIndicators: true) {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(viewModel.rows.enumerated()), id: \.element.id) { idx, row in
                                        SpecificGridDataRow(
                                            row: row,
                                            rowNumber: idx + 1,
                                            columns: columns,
                                            gridItems: gridItems,
                                            rowHeight: rowHeight,
                                            focusedCell: $focusedCell,
                                            onCellTap: { key in
                                                guard key.editable else { return }
                                                let newFocus = SpecificGridFocusID(rowID: row.id, column: key)
                                                let flags = NSEvent.modifierFlags
                                                if flags.contains(.shift), selectionAnchor != nil {
                                                    focusedCell = newFocus
                                                } else {
                                                    focusedCell = newFocus
                                                    selectionAnchor = newFocus
                                                }
                                            },
                                            onCellSubmit: { key in moveFocus(from: row.id, column: key, direction: .down) },
                                            onCellChange: { key, value in
                                                viewModel.handleCellChange(
                                                    rowID: row.id,
                                                    key: key,
                                                    value: value,
                                                    onCellSave: { id, field, v in
                                                        onCellSave?(id, field, v)
                                                    }
                                                )
                                            },
                                            onDelete: {
                                                if let rid = row.recordID {
                                                    onDeleteRecord?(rid)
                                                }
                                            },
                                            isSelectedInRange: { key in
                                                isCellInSelection(rowID: row.id, key: key)
                                            },
                                            onAppear: {
                                                viewModel.expandIfNeeded(visibleRowIndex: idx)
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
                    Text("Показано \(viewModel.rows.filter { $0.recordID != nil }.count) из \(totalCount)")
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
        }
        .background(DSColors.background)
        .searchable(text: Binding(
            get: { searchText },
            set: { onSearchTextChange($0) }
        ), prompt: "Поиск по номеру двигателя, данным, листу")
        .onAppear {
            viewModel.reload(records: records, specificRecords: specificRecords)
            if let firstRow = viewModel.rows.first, let firstEditable = columns.first(where: { $0.key.editable }) {
                let start = SpecificGridFocusID(rowID: firstRow.id, column: firstEditable.key)
                focusedCell = start
                selectionAnchor = start
            }
        }
        .onChange(of: records) { _, _ in
            viewModel.reload(records: records, specificRecords: specificRecords)
        }
        .onChange(of: specificRecords) { _, _ in
            viewModel.reload(records: records, specificRecords: specificRecords)
        }
        .onChange(of: viewModel.hasUnsavedChanges) { _, newValue in
            saveStatusText = newValue ? "Не сохранено" : "Все сохранено"
        }
        .onReceive(NotificationCenter.default.publisher(for: .motorGridSaveRequested)) { _ in
            saveAllChanges()
        }
        .onCopyCommand {
            copyFocusedCell()
        }
        .onPasteCommand(of: [.plainText]) { providers in
            guard let provider = providers.first else { return }
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let text = object as? String else { return }
                Task { @MainActor in pasteIntoGrid(text) }
            }
        }
        .onDeleteCommand {
            clearCurrentSelection()
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
                        Rectangle().fill(Platform.separatorColor.opacity(0.35)).frame(width: 1)
                    }
            }
        }
        .frame(width: tableContentWidth, height: headerHeight, alignment: .leading)
    }

    private var zoomControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Slider(value: $tableZoom, in: 0.75...1.4, step: 0.01)
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

    private enum FocusDirection { case up, down, left, right }

    private func moveFocusedCell(_ direction: FocusDirection) {
        guard let current = focusedCell else { return }
        moveFocus(from: current.rowID, column: current.column, direction: direction)
    }

    private func moveFocus(from rowID: UUID, column: SpecificColumnKey, direction: FocusDirection) {
        guard let rowIndex = viewModel.rows.firstIndex(where: { $0.id == rowID }),
              let columnIndex = columns.firstIndex(where: { $0.key == column }) else { return }

        var newRow = rowIndex
        var newColumn = columnIndex

        switch direction {
        case .up: newRow = max(0, rowIndex - 1)
        case .down: newRow = min(viewModel.rows.count - 1, rowIndex + 1)
        case .left: newColumn = max(1, columnIndex - 1)
        case .right: newColumn = min(columns.count - 1, columnIndex + 1)
        }

        if direction == .down { viewModel.expandIfNeeded(visibleRowIndex: newRow) }
        let target = columns[newColumn].key
        guard target.editable else { return }
        let newFocus = SpecificGridFocusID(rowID: viewModel.rows[newRow].id, column: target)
        focusedCell = newFocus
        if !NSEvent.modifierFlags.contains(.shift) {
            selectionAnchor = newFocus
        }
    }

    private func copyFocusedCell() -> [NSItemProvider] {
        guard let focusedCell else { return [] }
        let selectedCells = selectedCellCoords()
        let value: String
        if selectedCells.count <= 1 {
            guard let row = viewModel.rows.first(where: { $0.id == focusedCell.rowID }) else { return [] }
            value = row.value(for: focusedCell.column, dateFormatter: Self.dateFormatter)
        } else {
            value = makeTSV(from: selectedCells)
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        guard let data = value.data(using: .utf8) else { return [] }
        return [NSItemProvider(item: data as NSData, typeIdentifier: "public.utf8-plain-text")]
    }

    private func pasteIntoGrid(_ text: String) {
        guard let focusedCell,
              let rowStart = viewModel.rows.firstIndex(where: { $0.id == focusedCell.rowID }),
              let colStart = columns.firstIndex(where: { $0.key == focusedCell.column }) else { return }

        let matrix = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }

        for (r, line) in matrix.enumerated() {
            let rowIndex = rowStart + r
            guard viewModel.rows.indices.contains(rowIndex) else { continue }
            let row = viewModel.rows[rowIndex]
            for (c, value) in line.enumerated() {
                let colIndex = colStart + c
                guard columns.indices.contains(colIndex) else { continue }
                let key = columns[colIndex].key
                guard key.editable else { continue }
                viewModel.handleCellChange(
                    rowID: row.id,
                    key: key,
                    value: value,
                    onCellSave: { id, field, v in
                        onCellSave?(id, field, v)
                    }
                )
            }
        }
    }

    private func clearCurrentSelection() {
        let cells = selectedCellCoords()
        guard !cells.isEmpty else { return }
        for cell in cells {
            guard let row = viewModel.rows.first(where: { $0.id == cell.rowID }) else { continue }
            viewModel.handleCellChange(
                rowID: row.id,
                key: cell.column,
                value: "",
                onCellSave: { id, field, v in
                    onCellSave?(id, field, v)
                }
            )
        }
    }

    private func selectedCellCoords() -> [SpecificGridFocusID] {
        guard let focusedCell else { return [] }
        guard let anchor = selectionAnchor else { return [focusedCell] }
        guard let anchorRow = viewModel.rows.firstIndex(where: { $0.id == anchor.rowID }),
              let focusRow = viewModel.rows.firstIndex(where: { $0.id == focusedCell.rowID }),
              let anchorCol = columns.firstIndex(where: { $0.key == anchor.column }),
              let focusCol = columns.firstIndex(where: { $0.key == focusedCell.column }) else {
            return [focusedCell]
        }
        let rowRange = min(anchorRow, focusRow)...max(anchorRow, focusRow)
        let colRange = min(anchorCol, focusCol)...max(anchorCol, focusCol)
        var result: [SpecificGridFocusID] = []
        for r in rowRange {
            for c in colRange {
                let key = columns[c].key
                if key.editable {
                    result.append(SpecificGridFocusID(rowID: viewModel.rows[r].id, column: key))
                }
            }
        }
        return result
    }

    private func isCellInSelection(rowID: UUID, key: SpecificColumnKey) -> Bool {
        selectedCellCoords().contains(where: { $0.rowID == rowID && $0.column == key })
    }

    private func makeTSV(from cells: [SpecificGridFocusID]) -> String {
        guard !cells.isEmpty else { return "" }
        let rowOrder = Dictionary(uniqueKeysWithValues: viewModel.rows.enumerated().map { ($1.id, $0) })
        let colOrder = Dictionary(uniqueKeysWithValues: columns.enumerated().map { ($1.key, $0) })

        let grouped = Dictionary(grouping: cells) { rowOrder[$0.rowID] ?? 0 }
        let sortedRows = grouped.keys.sorted()
        let lines: [String] = sortedRows.map { rowIndex in
            let rowCells = (grouped[rowIndex] ?? []).sorted { (colOrder[$0.column] ?? 0) < (colOrder[$1.column] ?? 0) }
            guard let row = viewModel.rows[safe: rowIndex] else { return "" }
            return rowCells.map { row.value(for: $0.column, dateFormatter: Self.dateFormatter) }.joined(separator: "\t")
        }
        return lines.joined(separator: "\n")
    }

    private func saveAllChanges() {
        let didSave = viewModel.saveAllChanges { recordID, field, value in
            onCellSave?(recordID, field, value)
        }
        saveStatusText = didSave ? "Сохранено" : (viewModel.hasUnsavedChanges ? "Не сохранено" : "Все сохранено")
    }
}

private struct SpecificGridDataRow: View {
    @ObservedObject var row: SpecificGridRowViewModel
    let rowNumber: Int
    let columns: [SpecificColumnDef]
    let gridItems: [GridItem]
    let rowHeight: CGFloat
    @FocusState.Binding var focusedCell: SpecificGridFocusID?
    let onCellTap: (SpecificColumnKey) -> Void
    let onCellSubmit: (SpecificColumnKey) -> Void
    let onCellChange: (SpecificColumnKey, String) -> Void
    let onDelete: () -> Void
    let isSelectedInRange: (SpecificColumnKey) -> Bool
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
    private func cell(for column: SpecificColumnDef) -> some View {
        switch column.key {
        case .rowNumber:
            Text("\(rowNumber)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 6)
                .overlay(alignment: .trailing) { divider }

        case .date:
            Text(row.value(for: .date, dateFormatter: ServiceRecordsView.dateFormatter))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .overlay(alignment: .trailing) { divider }

        default:
            SpecificGridEditableCell(
                text: Binding(
                    get: { row.value(for: column.key, dateFormatter: ServiceRecordsView.dateFormatter) },
                    set: { onCellChange(column.key, $0) }
                ),
                column: column,
                isSelectedInRange: isSelectedInRange(column.key),
                rowID: row.id,
                focusedCell: $focusedCell,
                onTap: { onCellTap(column.key) },
                onSubmit: { onCellSubmit(column.key) }
            )
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Удалить запись", systemImage: "trash")
                }
            }
            .overlay(alignment: .trailing) { divider }
        }
    }

    private var divider: some View {
        Rectangle().fill(Platform.separatorColor.opacity(0.25)).frame(width: 1)
    }
}

private struct SpecificGridEditableCell: View {
    @Binding var text: String
    let column: SpecificColumnDef
    let isSelectedInRange: Bool
    let rowID: UUID
    @FocusState.Binding var focusedCell: SpecificGridFocusID?
    let onTap: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        let focusID = SpecificGridFocusID(rowID: rowID, column: column.key)
        let isActive = focusedCell == focusID

        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: column.alignment)
            .padding(.horizontal, 6)
            .background(
                Rectangle()
                    .fill(
                        isActive
                            ? Platform.controlAccentColor.opacity(0.22)
                            : (isSelectedInRange ? Platform.controlAccentColor.opacity(0.10) : .clear)
                    )
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

private struct SpecificGridFocusID: Hashable {
    let rowID: UUID
    let column: SpecificColumnKey
}

private struct SpecificColumnDef: Identifiable {
    let key: SpecificColumnKey
    let title: String
    let width: CGFloat
    let alignment: Alignment
    let editable: Bool
    var id: String { key.id }
}

private enum SpecificColumnKey: Hashable {
    case rowNumber
    case serialCode
    case sheetName
    case dynamic(String)
    case date

    var editable: Bool {
        switch self {
        case .rowNumber, .date: return false
        default: return true
        }
    }

    var id: String {
        switch self {
        case .rowNumber: return "rowNumber"
        case .serialCode: return "serialCode"
        case .sheetName: return "sheetName"
        case .dynamic(let key): return "dynamic:\(key)"
        case .date: return "date"
        }
    }
}

@MainActor
private final class SpecificGridTableViewModel: ObservableObject {
    @Published private(set) var rows: [SpecificGridRowViewModel] = []
    @Published private(set) var dynamicFieldNames: [String] = []
    @Published private(set) var hasUnsavedChanges = false

    private var pendingValues: [Int64: [String: String]] = [:]

    func reload(records: [ServiceRecord], specificRecords: [DatabaseService.SpecificRecord]) {
        var fieldSet: Set<String> = []
        let all: [RecordDisplayItem] = records.map(RecordDisplayItem.fromServiceRecord) + specificRecords.map(RecordDisplayItem.fromSpecificRecord)
        for item in all {
            for key in item.data.keys where !key.hasPrefix("_") && key != "НОМЕР ДВИГАТЕЛЯ" && key != "_CATEGORY_NAME" {
                fieldSet.insert(key)
            }
        }
        dynamicFieldNames = Array(fieldSet).sorted()

        var mapped = all.map { item in
            let vm = SpecificGridRowViewModel(item: item)
            if let pending = pendingValues[item.id] {
                vm.apply(pending: pending)
            }
            return vm
        }
        let fillerCount = max(100 - mapped.count, 0)
        if fillerCount > 0 {
            mapped.append(contentsOf: (0..<fillerCount).map { _ in .empty(dynamicFieldNames: dynamicFieldNames) })
        }
        rows = mapped
        updateDirtyState()
    }

    func handleCellChange(rowID: UUID, key: SpecificColumnKey, value: String, onCellSave: (Int64, String, String) -> Void) {
        guard let row = rows.first(where: { $0.id == rowID }) else { return }
        row.setValue(value, for: key)

        guard let recordID = row.recordID, let field = key.fieldName else { return }
        if pendingValues[recordID] == nil { pendingValues[recordID] = [:] }
        pendingValues[recordID]?[field] = value
        onCellSave(recordID, field, value)
        updateDirtyState()
    }

    func saveAllChanges(onCellSave: (Int64, String, String) -> Void) -> Bool {
        guard !pendingValues.isEmpty else { return false }
        for (recordID, fields) in pendingValues {
            for (field, value) in fields {
                onCellSave(recordID, field, value)
            }
        }
        pendingValues.removeAll()
        updateDirtyState()
        return true
    }

    func expandIfNeeded(visibleRowIndex: Int) {
        let threshold = 20
        guard rows.count - visibleRowIndex - 1 <= threshold else { return }
        rows.append(contentsOf: (0..<50).map { _ in .empty(dynamicFieldNames: dynamicFieldNames) })
    }

    private func updateDirtyState() {
        hasUnsavedChanges = !pendingValues.isEmpty
    }
}

@MainActor
private final class SpecificGridRowViewModel: ObservableObject, Identifiable {
    let id: UUID
    let recordID: Int64?
    @Published private(set) var date: Date
    @Published private var values: [String: String]

    init(id: UUID = UUID(), recordID: Int64?, values: [String: String], date: Date) {
        self.id = id
        self.recordID = recordID
        self.values = values
        self.date = date
    }

    convenience init(item: RecordDisplayItem) {
        self.init(recordID: item.id, values: item.data, date: item.date)
    }

    static func empty(dynamicFieldNames: [String]) -> SpecificGridRowViewModel {
        var values: [String: String] = [
            "НОМЕР ДВИГАТЕЛЯ": "",
            "_CATEGORY_NAME": ""
        ]
        for key in dynamicFieldNames { values[key] = "" }
        return .init(recordID: nil, values: values, date: Date())
    }

    func apply(pending: [String: String]) {
        for (k, v) in pending { values[k] = v }
    }

    func setValue(_ value: String, for key: SpecificColumnKey) {
        switch key {
        case .serialCode:
            values["НОМЕР ДВИГАТЕЛЯ"] = value
        case .sheetName:
            values["_CATEGORY_NAME"] = value
        case .dynamic(let name):
            values[name] = value
        case .rowNumber, .date:
            break
        }
    }

    func value(for key: SpecificColumnKey, dateFormatter: DateFormatter) -> String {
        switch key {
        case .rowNumber:
            return ""
        case .serialCode:
            return values["НОМЕР ДВИГАТЕЛЯ"] ?? ""
        case .sheetName:
            return values["_CATEGORY_NAME"] ?? ""
        case .dynamic(let name):
            return values[name] ?? ""
        case .date:
            return dateFormatter.string(from: date)
        }
    }
}

private extension SpecificColumnKey {
    var fieldName: String? {
        switch self {
        case .serialCode: return "НОМЕР ДВИГАТЕЛЯ"
        case .sheetName: return "_CATEGORY_NAME"
        case .dynamic(let name): return name
        case .rowNumber, .date: return nil
        }
    }
}

private struct RecordDisplayItem: Identifiable {
    let id: Int64
    let data: [String: String]
    let date: Date

    static func fromServiceRecord(_ record: ServiceRecord) -> RecordDisplayItem {
        RecordDisplayItem(
            id: record.id,
            data: [
                "НОМЕР ДВИГАТЕЛЯ": record.serialCode,
                "_CATEGORY_NAME": record.sheetName,
                "Категория": record.category,
                "Заметки": record.notes
            ],
            date: record.recordDate
        )
    }

    static func fromSpecificRecord(_ record: DatabaseService.SpecificRecord) -> RecordDisplayItem {
        RecordDisplayItem(id: record.id, data: record.data, date: record.createdAt)
    }
}

#endif

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
