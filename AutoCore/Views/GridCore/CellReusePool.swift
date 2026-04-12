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
    private var palette = GridPalette.current(for: NSAppearance(named: .aqua)!)

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
        layer?.backgroundColor = palette.background.cgColor
        textField.textColor = palette.textPrimary
    }

    override func mouseDown(with event: NSEvent) {
        guard let address else {
            super.mouseDown(with: event)
            return
        }
        onMouseDown?(event, address)
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
        textField.isHidden = false
        sellButton.isHidden = true
        textField.alignment = .center
        textField.stringValue = "\(number)"
        textField.textColor = palette.textSecondary
    }

    func configureAsText(_ text: String, alignment: NSTextAlignment) {
        textField.isHidden = false
        sellButton.isHidden = true
        textField.alignment = alignment
        textField.stringValue = text
        textField.textColor = palette.textPrimary
    }

    func configureAsSellButton(row: Int, visible: Bool) {
        textField.isHidden = true
        sellButton.isHidden = !visible
        rowIndex = row
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
        if v.superview !== parent {
            v.removeFromSuperview()
            parent.addSubview(v)
        }
        return v
    }

    func recycle(_ view: PooledGridCellView) {
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
