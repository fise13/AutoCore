#if os(macOS)

import AppKit

/// Lightweight read-only cell presentation (no per-cell editors).
final class PooledGridCellView: NSView {
    let textField: NSTextField
    let sellButton: NSButton
    var rowIndex: Int = 0
    var address: GridCellAddress?
    var onSell: ((Int) -> Void)?
    var onMouseDown: ((NSEvent, GridCellAddress) -> Void)?
    var onMouseDragged: ((NSEvent, GridCellAddress) -> Void)?
    var onMouseUp: ((NSEvent, GridCellAddress) -> Void)?
    var onHoverChanged: ((GridCellAddress?, Bool) -> Void)?
    var isEditableCell: Bool = false
    private var palette = GridPalette.current(for: NSAppearance(named: .aqua)!)
    private var isSellButtonMode = false
    private var tracking: NSTrackingArea?
    private var isHovered = false

    override init(frame frameRect: NSRect) {
        textField = NSTextField(labelWithString: "")
        sellButton = NSButton(title: "Продать", target: nil, action: nil)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.isEditable = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1
        textField.font = NSFont.systemFont(ofSize: 11)
        addSubview(textField)

        sellButton.translatesAutoresizingMaskIntoConstraints = false
        sellButton.isHidden = true
        sellButton.bezelStyle = .rounded
        sellButton.controlSize = .small
        sellButton.target = self
        sellButton.action = #selector(sellPressed)
        addSubview(sellButton)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
            sellButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            sellButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        applyPalette(palette)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func sellPressed() {
        onSell?(rowIndex)
    }

    func applyPalette(_ palette: GridPalette) {
        self.palette = palette
        refreshBackground()
        textField.textColor = palette.textPrimary
    }

    private func refreshBackground() {
        if isHovered {
            layer?.backgroundColor = palette.activeFill.cgColor
        } else {
            layer?.backgroundColor = palette.background.cgColor
        }
    }

    func setHovered(_ hovered: Bool) {
        guard isHovered != hovered else { return }
        isHovered = hovered
        refreshBackground()
    }

    func resetForReuse() {
        setHovered(false)
        address = nil
        isEditableCell = false
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let options: NSTrackingArea.Options = [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseDown(with event: NSEvent) {
        guard let address else {
            super.mouseDown(with: event)
            return
        }
        onMouseDown?(event, address)
    }

    override func mouseEntered(with event: NSEvent) {
        _ = event
        setHovered(true)
        onHoverChanged?(address, true)
        NSCursor.crosshair.set()
    }

    override func mouseExited(with event: NSEvent) {
        _ = event
        setHovered(false)
        onHoverChanged?(address, false)
        NSCursor.arrow.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let address else {
            super.mouseDragged(with: event)
            return
        }
        onMouseDragged?(event, address)
    }

    override func mouseUp(with event: NSEvent) {
        guard let address else {
            super.mouseUp(with: event)
            return
        }
        onMouseUp?(event, address)
    }

    func configureAsRowNumber(_ number: Int) {
        if isSellButtonMode {
            textField.isHidden = false
            sellButton.isHidden = true
            isSellButtonMode = false
        }
        if textField.alignment != .center {
            textField.alignment = .center
        }
        let value = "\(number)"
        if textField.stringValue != value {
            textField.stringValue = value
        }
        textField.textColor = palette.textSecondary
        isEditableCell = false
    }

    func configureAsText(_ text: String, alignment: NSTextAlignment) {
        if isSellButtonMode {
            textField.isHidden = false
            sellButton.isHidden = true
            isSellButtonMode = false
        }
        if textField.alignment != alignment {
            textField.alignment = alignment
        }
        if textField.stringValue != text {
            textField.stringValue = text
        }
        textField.textColor = palette.textPrimary
        isEditableCell = true
    }

    func configureAsSellButton(row: Int, visible: Bool) {
        if !isSellButtonMode {
            textField.isHidden = true
            isSellButtonMode = true
        }
        if sellButton.isHidden == visible {
            sellButton.isHidden = !visible
        }
        rowIndex = row
        isEditableCell = false
    }
}

final class CellReusePool {
    private var available: [PooledGridCellView] = []
    private let maxCount: Int

    init(maxCount: Int = 320) {
        self.maxCount = maxCount
    }

    func dequeue(into parent: NSView) -> PooledGridCellView {
        let v: PooledGridCellView
        if let existing = available.popLast() {
            v = existing
        } else {
            v = PooledGridCellView(frame: .zero)
        }
        v.resetForReuse()
        if v.superview !== parent {
            v.removeFromSuperview()
            parent.addSubview(v)
        }
        return v
    }

    func recycle(_ view: PooledGridCellView) {
        view.resetForReuse()
        view.removeFromSuperview()
        guard available.count < maxCount else { return }
        available.append(view)
    }

    func recycleAll(_ views: inout [PooledGridCellView]) {
        for v in views {
            recycle(v)
        }
        views.removeAll(keepingCapacity: true)
    }
}

#endif
