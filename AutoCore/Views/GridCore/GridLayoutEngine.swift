#if os(macOS)

import CoreGraphics

/// Fixed row height and per-column widths (points), scaled by zoom.
final class GridLayoutEngine {
    private(set) var zoom: CGFloat
    private let baseRowHeight: CGFloat = 30
    private let baseHeaderHeight: CGFloat = 28
    private let baseColumnWidths: [CGFloat] = [
        40, 180, 180, 220, 80, 120, 140, 140, 110
    ]

    init(zoom: CGFloat = 1) {
        self.zoom = zoom
    }

    private var columnOrder: [Int] = Array(0..<9)

    var rowHeight: CGFloat { baseRowHeight * zoom }
    var headerHeight: CGFloat { baseHeaderHeight * zoom }
    var columnCount: Int { columnOrder.count }

    func setZoom(_ z: CGFloat) {
        zoom = z
    }

    func setColumnOrder(_ order: [Int]) {
        let normalized = order.filter { $0 >= 0 && $0 < baseColumnWidths.count }
        columnOrder = normalized.isEmpty ? Array(0..<baseColumnWidths.count) : normalized
    }

    func modelColumnIndex(at visualIndex: Int) -> Int {
        guard visualIndex >= 0 && visualIndex < columnOrder.count else { return 0 }
        return columnOrder[visualIndex]
    }

    func columnWidth(at index: Int) -> CGFloat {
        guard index >= 0 && index < columnOrder.count else { return 0 }
        return baseColumnWidths[columnOrder[index]] * zoom
    }

    func totalWidth() -> CGFloat {
        (0..<columnCount).reduce(0) { $0 + columnWidth(at: $1) }
    }

    /// X origin of column in document coordinates.
    func xOrigin(ofColumn column: Int) -> CGFloat {
        var x: CGFloat = 0
        for c in 0..<min(column, columnCount) {
            x += columnWidth(at: c)
        }
        return x
    }

    func cellFrame(row: Int, column: Int) -> CGRect {
        let x = xOrigin(ofColumn: column)
        let y = CGFloat(row) * rowHeight
        let w = columnWidth(at: column)
        let h = rowHeight
        return CGRect(x: x, y: y, width: w, height: h)
    }

    func cellAt(point: CGPoint, rowCount: Int) -> GridCellAddress? {
        guard rowCount > 0 else { return nil }
        let row = Int(floor(point.y / rowHeight))
        if row < 0 || row >= rowCount { return nil }
        var x: CGFloat = 0
        for c in 0..<columnCount {
            let w = columnWidth(at: c)
            if point.x >= x && point.x < x + w {
                return GridCellAddress(row: row, column: c)
            }
            x += w
        }
        return nil
    }
}

#endif
