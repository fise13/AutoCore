#if os(macOS)

import CoreGraphics

/// Computes visible row/column index ranges from scroll position and viewport size.
struct ViewportEngine {
    func visibleRowRange(
        scrollY: CGFloat,
        viewportHeight: CGFloat,
        rowHeight: CGFloat,
        totalRows: Int
    ) -> Range<Int> {
        guard totalRows > 0, rowHeight > 0 else { return 0..<0 }
        let first = max(0, Int(floor(scrollY / rowHeight)))
        let visibleCount = Int(ceil(viewportHeight / rowHeight)) + 2
        let last = min(totalRows - 1, first + visibleCount)
        return first..<(last + 1)
    }

    func visibleColumnRange(
        scrollX: CGFloat,
        viewportWidth: CGFloat,
        columnWidths: [CGFloat]
    ) -> Range<Int> {
        guard !columnWidths.isEmpty else { return 0..<0 }
        var x: CGFloat = 0
        var first = 0
        for (i, w) in columnWidths.enumerated() {
            if x + w > scrollX {
                first = i
                break
            }
            x += w
            if i == columnWidths.count - 1 {
                first = i
            }
        }
        var acc: CGFloat = 0
        for j in 0..<first {
            acc += columnWidths[j]
        }
        var last = first
        var cursor = acc
        while last < columnWidths.count && cursor < scrollX + viewportWidth + 1 {
            cursor += columnWidths[last]
            last += 1
        }
        last = min(columnWidths.count - 1, max(first, last))
        return first..<(last + 1)
    }
}

#endif
