#if os(macOS)

import Foundation

/// Навигация вдоль одной строки/столбца по ненастоящему «пусто / не пусто», как в Excel (упрощённо — только ячейки с данными, без merge).
enum GridDataRegionNavigation {

    static func isDataEmpty(
        at row: Int,
        visualColumn: Int,
        layout: GridLayoutEngine,
        store: GridDataStore
    ) -> Bool {
        let model = layout.modelColumnIndex(at: visualColumn)
        guard MotorSheetColumn(rawValue: model)?.isEditable == true else { return true }
        return store.value(at: GridCellAddress(row: row, column: model))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    /// Край блока в строке: влево/вправо по `navigable` (только визуальные колонки с данными).
    static func jumpColumnInRow(
        row: Int,
        fromVisual: Int,
        direction: Int,
        navigable: [Int],
        layout: GridLayoutEngine,
        store: GridDataStore
    ) -> Int? {
        guard !navigable.isEmpty, let i0 = navigable.firstIndex(of: fromVisual) else { return fromVisual }
        let n = navigable.count
        if direction > 0 {
            return jumpRightInRow(
                row: row,
                startIndex: i0,
                navigable: navigable,
                n: n,
                layout: layout,
                store: store
            )
        } else {
            return jumpLeftInRow(
                row: row,
                startIndex: i0,
                navigable: navigable,
                n: n,
                layout: layout,
                store: store
            )
        }
    }

    private static func jumpRightInRow(
        row: Int,
        startIndex: Int,
        navigable: [Int],
        n: Int,
        layout: GridLayoutEngine,
        store: GridDataStore
    ) -> Int? {
        let v = navigable[startIndex]
        if !isDataEmpty(at: row, visualColumn: v, layout: layout, store: store) {
            if startIndex + 1 < n, !isDataEmpty(at: row, visualColumn: navigable[startIndex + 1], layout: layout, store: store) {
                var j = startIndex
                while j + 1 < n, !isDataEmpty(at: row, visualColumn: navigable[j + 1], layout: layout, store: store) {
                    j += 1
                }
                return navigable[j]
            } else {
                var j = startIndex + 1
                while j < n, isDataEmpty(at: row, visualColumn: navigable[j], layout: layout, store: store) { j += 1 }
                return j < n ? navigable[j] : navigable[startIndex]
            }
        } else {
            var j = startIndex + 1
            while j < n, isDataEmpty(at: row, visualColumn: navigable[j], layout: layout, store: store) { j += 1 }
            return j < n ? navigable[j] : navigable[startIndex]
        }
    }

    private static func jumpLeftInRow(
        row: Int,
        startIndex: Int,
        navigable: [Int],
        n: Int,
        layout: GridLayoutEngine,
        store: GridDataStore
    ) -> Int? {
        let v = navigable[startIndex]
        if !isDataEmpty(at: row, visualColumn: v, layout: layout, store: store) {
            if startIndex > 0, !isDataEmpty(at: row, visualColumn: navigable[startIndex - 1], layout: layout, store: store) {
                var j = startIndex
                while j > 0, !isDataEmpty(at: row, visualColumn: navigable[j - 1], layout: layout, store: store) {
                    j -= 1
                }
                return navigable[j]
            } else {
                var j = startIndex - 1
                while j >= 0, isDataEmpty(at: row, visualColumn: navigable[j], layout: layout, store: store) { j -= 1 }
                return j >= 0 ? navigable[j] : navigable[startIndex]
            }
        } else {
            var j = startIndex - 1
            while j >= 0, isDataEmpty(at: row, visualColumn: navigable[j], layout: layout, store: store) { j -= 1 }
            return j >= 0 ? navigable[j] : navigable[startIndex]
        }
    }

    static func jumpRowInColumn(
        column: Int,
        fromRow: Int,
        direction: Int,
        rowCount: Int,
        layout: GridLayoutEngine,
        store: GridDataStore
    ) -> Int? {
        guard rowCount > 0, fromRow >= 0, fromRow < rowCount else { return fromRow }
        if direction > 0 {
            return jumpDownInColumn(
                column: column,
                startRow: fromRow,
                rowCount: rowCount,
                layout: layout,
                store: store
            )
        } else {
            return jumpUpInColumn(
                column: column,
                startRow: fromRow,
                rowCount: rowCount,
                layout: layout,
                store: store
            )
        }
    }

    private static func jumpDownInColumn(
        column: Int,
        startRow: Int,
        rowCount: Int,
        layout: GridLayoutEngine,
        store: GridDataStore
    ) -> Int? {
        if !isDataEmpty(at: startRow, visualColumn: column, layout: layout, store: store) {
            if startRow + 1 < rowCount, !isDataEmpty(at: startRow + 1, visualColumn: column, layout: layout, store: store) {
                var r = startRow
                while r + 1 < rowCount, !isDataEmpty(at: r + 1, visualColumn: column, layout: layout, store: store) {
                    r += 1
                }
                return r
            } else {
                var r = startRow + 1
                while r < rowCount, isDataEmpty(at: r, visualColumn: column, layout: layout, store: store) { r += 1 }
                return r < rowCount ? r : startRow
            }
        } else {
            var r = startRow + 1
            while r < rowCount, isDataEmpty(at: r, visualColumn: column, layout: layout, store: store) { r += 1 }
            return r < rowCount ? r : startRow
        }
    }

    private static func jumpUpInColumn(
        column: Int,
        startRow: Int,
        rowCount: Int,
        layout: GridLayoutEngine,
        store: GridDataStore
    ) -> Int? {
        if !isDataEmpty(at: startRow, visualColumn: column, layout: layout, store: store) {
            if startRow > 0, !isDataEmpty(at: startRow - 1, visualColumn: column, layout: layout, store: store) {
                var r = startRow
                while r > 0, !isDataEmpty(at: r - 1, visualColumn: column, layout: layout, store: store) {
                    r -= 1
                }
                return r
            } else {
                var r = startRow - 1
                while r >= 0, isDataEmpty(at: r, visualColumn: column, layout: layout, store: store) { r -= 1 }
                return r >= 0 ? r : startRow
            }
        } else {
            var r = startRow - 1
            while r >= 0, isDataEmpty(at: r, visualColumn: column, layout: layout, store: store) { r -= 1 }
            return r >= 0 ? r : startRow
        }
    }

    /// Крайний правый/нижний угол, где есть данные (для пары Ctrl+A / bounding box).
    static func boundingDataRange(
        navigable: [Int],
        rowCount: Int,
        layout: GridLayoutEngine,
        store: GridDataStore
    ) -> GridRange? {
        var minR = Int.max, maxR = -1, minC = Int.max, maxC = -1
        for r in 0..<rowCount {
            for v in navigable {
                if !isDataEmpty(at: r, visualColumn: v, layout: layout, store: store) {
                    minR = min(minR, r)
                    maxR = max(maxR, r)
                    minC = min(minC, v)
                    maxC = max(maxC, v)
                }
            }
        }
        guard maxR >= 0, maxC >= 0 else { return nil }
        return GridRange(minRow: minR, maxRow: maxR, minColumn: minC, maxColumn: maxC)
    }

    static func lastUsedCell(
        navigable: [Int],
        rowCount: Int,
        layout: GridLayoutEngine,
        store: GridDataStore
    ) -> GridCellAddress? {
        for r in (0..<rowCount).reversed() {
            for v in navigable.reversed() {
                if !isDataEmpty(at: r, visualColumn: v, layout: layout, store: store) {
                    return GridCellAddress(row: r, column: v)
                }
            }
        }
        return nil
    }
}

#endif
