#if os(macOS)

import AppKit

/// Многострочный ввод: Enter — завершить и вниз, Shift+Enter — завершить и вверх, Option+Return — перенос строки в ячейке, Esc — отмена.
@MainActor
final class GridCellEditingTextView: NSTextView {
    var onUserReturn: (() -> Void)?
    var onUserShiftReturn: (() -> Void)?
    var onUserTab: (() -> Void)?
    var onUserBackTab: (() -> Void)?
    var onUserCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags
        if event.keyCode == 53 { // Esc
            onUserCancel?()
            return
        }
        if event.keyCode == 36 { // Return / Enter
            if flags.contains(.option) {
                super.insertText("\n", replacementRange: selectedRange())
                return
            }
            if flags.contains(.shift) {
                onUserShiftReturn?()
                return
            }
            onUserReturn?()
            return
        }
        if event.keyCode == 48 { // Tab
            if flags.contains(.shift) {
                onUserBackTab?()
            } else {
                onUserTab?()
            }
            return
        }
        if flags.contains(.command) {
            if event.charactersIgnoringModifiers == "c" {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(self.string, forType: .string)
                return
            }
            if event.charactersIgnoringModifiers == "v" {
                if let s = NSPasteboard.general.string(forType: .string) {
                    self.insertText(s, replacementRange: selectedRange())
                }
                return
            }
        }
        super.keyDown(with: event)
    }
}

#endif
