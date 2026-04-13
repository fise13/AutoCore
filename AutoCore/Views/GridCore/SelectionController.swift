#if os(macOS)

import AppKit

/// Excel-like selection: primary range (anchor…head), optional cmd-disjoint ranges, active cell.
final class SelectionController {
    private(set) var anchor: GridCellAddress
    private(set) var head: GridCellAddress
    /// Additional rectangular regions when using Cmd (non-contiguous multi-select).
    private(set) var cmdRanges: [GridRange] = []

    init(start: GridCellAddress) {
        anchor = start
        head = start
    }

    var activeCell: GridCellAddress { head }

    var primaryRange: GridRange {
        GridRange.spanning(anchor, head)
    }

    /// All ranges to draw (primary + cmd additions).
    func allRanges() -> [GridRange] {
        if cmdRanges.isEmpty {
            return [primaryRange]
        }
        return [primaryRange] + cmdRanges
    }

    func isSelected(_ cell: GridCellAddress) -> Bool {
        if primaryRange.contains(cell) { return true }
        return cmdRanges.contains { $0.contains(cell) }
    }

    /// Whether cell lies on same row or column as active cell (Excel header highlight hint).
    func isOnActiveCrossAxis(cell: GridCellAddress) -> Bool {
        cell.row == head.row || cell.column == head.column
    }

    func click(
        at cell: GridCellAddress,
        shift: Bool,
        cmd: Bool
    ) {
        if cmd {
            if let index = cmdRanges.firstIndex(where: { $0.contains(cell) }) {
                cmdRanges.remove(at: index)
            } else if !primaryRange.contains(cell) {
                cmdRanges.append(GridRange(minRow: cell.row, maxRow: cell.row, minColumn: cell.column, maxColumn: cell.column))
            }
            head = cell
            return
        }
        cmdRanges.removeAll()
        if shift {
            head = cell
        } else {
            anchor = cell
            head = cell
        }
    }

    func dragUpdate(to cell: GridCellAddress) {
        head = cell
    }

    func resetAnchorToHead() {
        anchor = head
    }

    func moveHead(to cell: GridCellAddress, extendSelection: Bool) {
        if extendSelection {
            head = cell
        } else {
            anchor = cell
            head = cell
            cmdRanges.removeAll()
        }
    }

    func selectRange(_ range: GridRange, active: GridCellAddress? = nil) {
        let resolvedActive = active ?? GridCellAddress(row: range.minRow, column: range.minColumn)
        anchor = GridCellAddress(row: range.minRow, column: range.minColumn)
        head = resolvedActive
        cmdRanges.removeAll()
    }
}

#endif
