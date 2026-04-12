#if os(macOS)

import AppKit
import CoreGraphics

/// Address of one cell in the motor grid (0-based).
struct GridCellAddress: Hashable, Equatable {
    var row: Int
    var column: Int
}

/// Inclusive rectangular range in grid coordinates.
struct GridRange: Hashable, Equatable {
    var minRow: Int
    var maxRow: Int
    var minColumn: Int
    var maxColumn: Int

    static func spanning(_ a: GridCellAddress, _ b: GridCellAddress) -> GridRange {
        GridRange(
            minRow: min(a.row, b.row),
            maxRow: max(a.row, b.row),
            minColumn: min(a.column, b.column),
            maxColumn: max(a.column, b.column)
        )
    }

    func contains(_ cell: GridCellAddress) -> Bool {
        cell.row >= minRow && cell.row <= maxRow && cell.column >= minColumn && cell.column <= maxColumn
    }

    func union(_ other: GridRange) -> GridRange {
        GridRange(
            minRow: min(minRow, other.minRow),
            maxRow: max(maxRow, other.maxRow),
            minColumn: min(minColumn, other.minColumn),
            maxColumn: max(maxColumn, other.maxColumn)
        )
    }
}

/// Column indices for the motor sheet layout.
enum MotorSheetColumn: Int, CaseIterable {
    case rowNumber = 0
    case engineNumber = 1
    case configuration = 2
    case notes = 3
    case quantity = 4
    case transmission = 5
    case arrivalDate = 6
    case soldDate = 7
    case action = 8

    static let editableRange = 1...7

    var isEditable: Bool {
        Self.editableRange.contains(rawValue)
    }
}

#endif
