#if os(macOS)

import AppKit

/// Document coordinates with origin at top-left (spreadsheet style).
final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

#endif
