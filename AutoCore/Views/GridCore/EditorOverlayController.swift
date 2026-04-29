#if os(macOS)

import AppKit

@MainActor
final class EditorOverlayController: NSObject {
    private weak var hostView: NSView?
    private let scroll: NSScrollView
    private let textView: GridCellEditingTextView
    private(set) var address: GridCellAddress?

    var onCommit: ((GridCellAddress, String) -> Void)?
    var onCancel: (() -> Void)?
    var onUserMovedAfterCommit: ((MoveAfterCommit) -> Void)?

    enum MoveAfterCommit {
        case down, up, tab, backTab
    }

    var isEditing: Bool { address != nil && !textView.isHidden }

    override init() {
        scroll = NSScrollView(frame: .zero)
        textView = GridCellEditingTextView(frame: .zero)
        super.init()
        scroll.translatesAutoresizingMaskIntoConstraints = true
        scroll.drawsBackground = true
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.documentView = textView
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 11)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.heightTracksTextView = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 4
        textView.minSize = NSSize(width: 0, height: 0)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.wantsLayer = true
        textView.layer?.borderWidth = 1
        textView.onUserReturn = { [weak self] in self?.finishCommitThen(.down) }
        textView.onUserShiftReturn = { [weak self] in self?.finishCommitThen(.up) }
        textView.onUserTab = { [weak self] in self?.finishCommitThen(.tab) }
        textView.onUserBackTab = { [weak self] in self?.finishCommitThen(.backTab) }
        textView.onUserCancel = { [weak self] in
            self?.endEditing(commit: false)
        }
    }

    func attach(host: NSView) {
        self.hostView = host
        if scroll.superview !== host {
            scroll.removeFromSuperview()
            host.addSubview(scroll)
        }
        scroll.isHidden = true
    }

    func beginEdit(address: GridCellAddress, frame: CGRect, text: String, selectAll: Bool = true) {
        self.address = address
        scroll.frame = frame.insetBy(dx: 0.5, dy: 0.5)
        textView.string = text
        textView.layer?.borderColor = NSColor.separatorColor.cgColor
        let innerW = max(1, frame.width - 2)
        textView.minSize = NSSize(width: innerW, height: 0)
        textView.maxSize = NSSize(width: innerW, height: 400)
        textView.isHidden = false
        scroll.isHidden = false
        hostView?.window?.makeFirstResponder(textView)
        if selectAll {
            textView.selectAll(nil)
        } else {
            textView.setSelectedRange(NSRange(location: text.utf16.count, length: 0))
        }
    }

    func endEditing(commit: Bool) {
        guard let addr = address else {
            textView.isHidden = true
            scroll.isHidden = true
            return
        }
        if commit {
            onCommit?(addr, textView.string)
        } else {
            onCancel?()
        }
        textView.isHidden = true
        scroll.isHidden = true
        self.address = nil
    }

    private func finishCommitThen(_ move: MoveAfterCommit) {
        guard let addr = address else { return }
        let t = textView.string
        onCommit?(addr, t)
        textView.isHidden = true
        scroll.isHidden = true
        address = nil
        onUserMovedAfterCommit?(move)
    }
}

#endif
