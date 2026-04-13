#if os(macOS)

import AppKit

final class EditorOverlayController: NSObject, NSTextFieldDelegate {
    private weak var hostView: NSView?
    private let field: NSTextField
    private(set) var address: GridCellAddress?
    var onCommit: ((GridCellAddress, String) -> Void)?
    var onCancel: (() -> Void)?
    var onNavigate: ((Bool) -> Void)?
    var isEditing: Bool { address != nil && !field.isHidden }

    override init() {
        field = NSTextField(string: "")
        super.init()
        field.isEditable = true
        field.isBordered = true
        field.drawsBackground = true
        field.font = NSFont.systemFont(ofSize: 11)
        field.delegate = self
        field.cell?.sendsActionOnEndEditing = false
    }

    func attach(host: NSView) {
        self.hostView = host
        if field.superview !== host {
            field.removeFromSuperview()
            host.addSubview(field)
        }
        field.isHidden = true
    }

    func beginEdit(address: GridCellAddress, frame: CGRect, text: String, selectAll: Bool = true) {
        self.address = address
        field.frame = frame.insetBy(dx: 1, dy: 1)
        field.stringValue = text
        field.isHidden = false
        hostView?.window?.makeFirstResponder(field)
        if selectAll {
            field.currentEditor()?.selectAll(nil)
        } else {
            if let editor = field.currentEditor() {
                editor.selectedRange = NSRange(location: field.stringValue.count, length: 0)
            }
        }
    }

    func endEditing(commit: Bool) {
        guard let addr = address else {
            field.isHidden = true
            return
        }
        if commit {
            onCommit?(addr, field.stringValue)
        } else {
            onCancel?()
        }
        field.isHidden = true
        address = nil
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            endEditing(commit: true)
            onNavigate?(false)
            return true
        }
        if commandSelector == #selector(NSResponder.insertTab(_:)) {
            endEditing(commit: true)
            onNavigate?(true)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            endEditing(commit: false)
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if field.isHidden { return }
        endEditing(commit: true)
    }
}

#endif
