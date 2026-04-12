#if os(macOS)

import AppKit

struct GridPalette {
    let background: NSColor
    let headerBackground: NSColor
    let gridLine: NSColor
    let textPrimary: NSColor
    let textSecondary: NSColor
    let selectionFill: NSColor
    let activeFill: NSColor
    let activeBorder: NSColor
}

extension GridPalette {
    static func current(for appearance: NSAppearance) -> GridPalette {
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let excelGreen = NSColor.systemGreen
        if isDark {
            return GridPalette(
                background: NSColor(calibratedWhite: 0.09, alpha: 1),
                headerBackground: NSColor(calibratedWhite: 0.13, alpha: 1),
                gridLine: NSColor.separatorColor.withAlphaComponent(0.55),
                textPrimary: .labelColor,
                textSecondary: .secondaryLabelColor,
                selectionFill: excelGreen.withAlphaComponent(0.18),
                activeFill: excelGreen.withAlphaComponent(0.08),
                activeBorder: excelGreen.withAlphaComponent(0.95)
            )
        }
        return GridPalette(
            background: NSColor(calibratedWhite: 1.0, alpha: 1),
            headerBackground: NSColor(calibratedWhite: 0.97, alpha: 1),
            gridLine: NSColor.separatorColor.withAlphaComponent(0.42),
            textPrimary: .labelColor,
            textSecondary: .secondaryLabelColor,
            selectionFill: excelGreen.withAlphaComponent(0.14),
            activeFill: excelGreen.withAlphaComponent(0.06),
            activeBorder: excelGreen.withAlphaComponent(0.92)
        )
    }
}

/// Draws 1px grid lines for visible area.
final class GridLineDrawingView: NSView {
    var layout: GridLayoutEngine?
    var rowCount: Int = 0
    var columnCount: Int = 9
    var lineColor: NSColor = NSColor.separatorColor.withAlphaComponent(0.55)

    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let layout else { return }
        let rowH = layout.rowHeight
        let totalW = layout.totalWidth()
        let totalH = CGFloat(rowCount) * rowH
        lineColor.setStroke()
        guard rowCount > 0, rowH > 0 else { return }

        let minX = max(0, dirtyRect.minX)
        let maxX = min(totalW, dirtyRect.maxX)
        let minY = max(0, dirtyRect.minY)
        let maxY = min(totalH, dirtyRect.maxY)
        guard minX <= maxX, minY <= maxY else { return }

        let firstRowLine = max(0, Int(floor(minY / rowH)))
        let lastRowLine = min(rowCount, Int(ceil(maxY / rowH)) + 1)
        for rowLine in firstRowLine...lastRowLine {
            let y = CGFloat(rowLine) * rowH
            let path = NSBezierPath()
            path.move(to: NSPoint(x: minX, y: y))
            path.line(to: NSPoint(x: maxX, y: y))
            path.lineWidth = 1
            path.stroke()
        }

        var x: CGFloat = 0
        for c in 0..<columnCount {
            let w = layout.columnWidth(at: c)
            if x >= minX - 1 && x <= maxX + 1 {
                let path = NSBezierPath()
                path.move(to: NSPoint(x: x, y: minY))
                path.line(to: NSPoint(x: x, y: maxY))
                path.lineWidth = 1
                path.stroke()
            }
            x += w
        }

        if totalW >= minX - 1 && totalW <= maxX + 1 {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: totalW, y: minY))
            path.line(to: NSPoint(x: totalW, y: maxY))
            path.lineWidth = 1
            path.stroke()
        }
    }
}

/// Semi-transparent fills for selected ranges (drawn under grid lines).
final class GridSelectionFillView: NSView {
    var layout: GridLayoutEngine?
    var selection: SelectionController?
    var selectionColor: NSColor = NSColor.controlAccentColor.withAlphaComponent(0.08)
    var activeColor: NSColor = NSColor.controlAccentColor.withAlphaComponent(0.03)

    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let layout, let selection else { return }
        let ranges = selection.allRanges()
        for range in ranges {
            let rect = boundingRect(for: range, layout: layout)
            selectionColor.setFill()
            NSBezierPath(rect: rect).fill()
        }
        let active = selection.activeCell
        let activeRect = layout.cellFrame(row: active.row, column: active.column)
        activeColor.setFill()
        NSBezierPath(rect: activeRect).fill()
    }

    private func boundingRect(for range: GridRange, layout: GridLayoutEngine) -> CGRect {
        let topLeft = layout.cellFrame(row: range.minRow, column: range.minColumn)
        let bottomRight = layout.cellFrame(row: range.maxRow, column: range.maxColumn)
        return topLeft.union(bottomRight)
    }
}

/// Active cell border on top of grid lines.
final class GridActiveCellBorderView: NSView {
    var layout: GridLayoutEngine?
    var selection: SelectionController?
    var borderColor: NSColor = .controlAccentColor

    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let layout, let selection else { return }

        let primary = selection.primaryRange
        let topLeft = layout.cellFrame(row: primary.minRow, column: primary.minColumn)
        let bottomRight = layout.cellFrame(row: primary.maxRow, column: primary.maxColumn)
        let rangeRect = topLeft.union(bottomRight).insetBy(dx: 0.5, dy: 0.5)

        borderColor.setStroke()
        let border = NSBezierPath(rect: rangeRect)
        border.lineWidth = 2
        border.stroke()

        let handleSize = max(5, min(8, layout.rowHeight * 0.2))
        let handleRect = CGRect(
            x: rangeRect.maxX - handleSize * 0.5,
            y: rangeRect.maxY - handleSize * 0.5,
            width: handleSize,
            height: handleSize
        )
        borderColor.setFill()
        NSBezierPath(rect: handleRect).fill()
    }
}

#endif
