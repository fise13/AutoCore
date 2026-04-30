#if os(macOS)

import Foundation

/// Draft values for one motor row (mirrors `MotorInlineDraft` fields).
struct GridMotorRowDraft: Equatable {
    var serialCode: String
    var configuration: String
    var notes: String
    var quantity: String
    var transmission: String
    var arrivalDate: String
    var soldDate: String

    static let empty = GridMotorRowDraft(
        serialCode: "",
        configuration: "",
        notes: "",
        quantity: "",
        transmission: "",
        arrivalDate: "",
        soldDate: ""
    )

    var hasAnyData: Bool {
        [serialCode, configuration, notes, quantity, transmission, arrivalDate, soldDate]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

/// One logical row: optional persisted motor id + seven editable fields.
struct GridRowState: Equatable {
    var motorID: Int64?
    var draft: GridMotorRowDraft
}

/// 2D motor sheet data (no formulas). Not ObservableObject — host view drives refresh.
final class GridDataStore {
    private(set) var rows: [GridRowState] = []
    private(set) var revision: Int = 0
    private let baseVisibleEmptyRows = 120
    private let expandBatchSize = 120
    private let expandThreshold = 48

    var rowCount: Int { rows.count }

    func ensureRowCount(_ minimum: Int) {
        let need = minimum - rows.count
        guard need > 0 else { return }
        rows.append(contentsOf: (0..<need).map { _ in GridRowState(motorID: nil, draft: .empty) })
        revision &+= 1
    }

    func row(at index: Int) -> GridRowState? {
        guard index >= 0 && index < rows.count else { return nil }
        return rows[index]
    }

    func value(at address: GridCellAddress) -> String {
        guard let row = row(at: address.row) else { return "" }
        switch address.column {
        case MotorSheetColumn.engineNumber.rawValue: return row.draft.serialCode
        case MotorSheetColumn.configuration.rawValue: return row.draft.configuration
        case MotorSheetColumn.notes.rawValue: return row.draft.notes
        case MotorSheetColumn.quantity.rawValue: return row.draft.quantity
        case MotorSheetColumn.transmission.rawValue: return row.draft.transmission
        case MotorSheetColumn.arrivalDate.rawValue: return row.draft.arrivalDate
        case MotorSheetColumn.soldDate.rawValue: return row.draft.soldDate
        default: return ""
        }
    }

    func setValue(_ text: String, at address: GridCellAddress) {
        guard address.row >= 0 && address.row < rows.count else { return }
        let oldValue = value(at: address)
        guard oldValue != text else { return }
        switch address.column {
        case MotorSheetColumn.engineNumber.rawValue: rows[address.row].draft.serialCode = text
        case MotorSheetColumn.configuration.rawValue: rows[address.row].draft.configuration = text
        case MotorSheetColumn.notes.rawValue: rows[address.row].draft.notes = text
        case MotorSheetColumn.quantity.rawValue: rows[address.row].draft.quantity = text
        case MotorSheetColumn.transmission.rawValue: rows[address.row].draft.transmission = text
        case MotorSheetColumn.arrivalDate.rawValue: rows[address.row].draft.arrivalDate = text
        case MotorSheetColumn.soldDate.rawValue: rows[address.row].draft.soldDate = text
        default: break
        }
        revision &+= 1
    }

    func motorID(atRow row: Int) -> Int64? {
        guard row >= 0 && row < rows.count else { return nil }
        return rows[row].motorID
    }

    /// Reload from server DTOs + pending create drafts + filler empty rows.
    /// `mergePending` returns draft override per motor id if any.
    func reload(
        from motors: [MotorRowDTO],
        mergePending: (Int64) -> GridMotorRowDraft?,
        pendingCreateDrafts: [GridMotorRowDraft] = []
    ) {
        var mapped: [GridRowState] = motors.map { dto in
            let serverDraft = GridMotorRowDraft(
                serialCode: dto.serialCode,
                configuration: dto.configuration,
                notes: dto.notes,
                quantity: dto.quantity,
                transmission: dto.transmission,
                arrivalDate: dto.arrivalDate,
                soldDate: dto.soldDate
            )
            let draft = mergePending(dto.id) ?? serverDraft
            return GridRowState(motorID: dto.id, draft: draft)
        }

        if !pendingCreateDrafts.isEmpty {
            mapped.append(contentsOf: pendingCreateDrafts.map { draft in
                GridRowState(motorID: nil, draft: draft)
            })
        }

        let fillers = max(baseVisibleEmptyRows - mapped.count, 0)
        if fillers > 0 {
            mapped.append(contentsOf: (0..<fillers).map { _ in GridRowState(motorID: nil, draft: .empty) })
        }
        rows = mapped
        revision &+= 1
    }

    @discardableResult
    func expandIfNeeded(visibleRowIndex: Int) -> Bool {
        guard !rows.isEmpty else { return false }
        let distanceToEnd = rows.count - visibleRowIndex - 1
        guard distanceToEnd <= expandThreshold else { return false }
        rows.append(contentsOf: (0..<expandBatchSize).map { _ in GridRowState(motorID: nil, draft: .empty) })
        revision &+= 1
        return true
    }

    /// Paste tab/newline separated text starting at origin; returns affected rects (row,col pairs).
    func pasteMatrix(_ lines: [[String]], origin: GridCellAddress) -> [GridCellAddress] {
        var changed: [GridCellAddress] = []
        for (rOffset, line) in lines.enumerated() {
            let row = origin.row + rOffset
            while row >= rows.count {
                rows.append(GridRowState(motorID: nil, draft: .empty))
            }
            for (cOffset, text) in line.enumerated() {
                let col = origin.column + cOffset
                guard MotorSheetColumn.editableRange.contains(col) else { continue }
                let addr = GridCellAddress(row: row, column: col)
                setValue(text, at: addr)
                changed.append(addr)
            }
        }
        return changed
    }

    func deleteRange(_ range: GridRange) -> [GridCellAddress] {
        var changed: [GridCellAddress] = []
        for r in range.minRow...range.maxRow {
            for c in range.minColumn...range.maxColumn {
                guard MotorSheetColumn.editableRange.contains(c) else { continue }
                let addr = GridCellAddress(row: r, column: c)
                setValue("", at: addr)
                changed.append(addr)
            }
        }
        return changed
    }
}

#endif
