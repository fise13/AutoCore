#if os(macOS)

import AppKit

@MainActor
protocol ExcelGridViewDelegate: AnyObject {
    func excelGridDataDidChange(_ grid: ExcelGridView)
    func excelGrid(_ grid: ExcelGridView, toggleSoldMotorID: Int64)
    func excelGridZoomDidChange(_ grid: ExcelGridView, zoom: CGFloat)
}

@MainActor
final class ExcelGridView: NSView {
    weak var delegate: ExcelGridViewDelegate?

    let store = GridDataStore()
    let layout = GridLayoutEngine()
    private let viewport = ViewportEngine()
    private var commandBus: GridCommandBus!

    private var selection: SelectionController!
    private let editor = EditorOverlayController()
    private let pool = CellReusePool()

    private let scrollView = NSScrollView()
    private let documentView = FlippedDocumentView()
    private let cellContainer = FlippedDocumentView()
    private let selectionFillView = GridSelectionFillView()
    private let lineView = GridLineDrawingView()
    private let activeBorderView = GridActiveCellBorderView()

    private let headerContainer = NSView()
    private let headerDocumentView = NSView()
    private var headerFields: [NSTextField] = []
    private var headerHeightConstraint: NSLayoutConstraint!

    private var visibleCellViews: [GridCellAddress: PooledGridCellView] = [:]
    private var isDraggingSelection = false
    private var pinchZoomStart: CGFloat = 1
    private var baselineDTOs: [Int64: MotorRowDTO] = [:]

    private var boundsObservation: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        commandBus = GridCommandBus(store: store, undoManager: nil)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.documentView = documentView
        scrollView.contentView.postsBoundsChangedNotifications = true

        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        cellContainer.autoresizingMask = [.width, .height]

        selectionFillView.autoresizingMask = [.width, .height]
        lineView.autoresizingMask = [.width, .height]
        activeBorderView.autoresizingMask = [.width, .height]

        documentView.addSubview(cellContainer)
        documentView.addSubview(selectionFillView)
        documentView.addSubview(lineView)
        documentView.addSubview(activeBorderView)

        selectionFillView.layout = layout
        lineView.layout = layout
        activeBorderView.layout = layout
        applyTheme()

        editor.attach(host: documentView)
        editor.onCommit = { [weak self] addr, text in
            self?.commitCell(addr, text: text)
        }
        editor.onCancel = { [weak self] in
            self?.redrawAll()
        }
        editor.onNavigate = { [weak self] isTab in
            guard let self else { return }
            if isTab {
                self.advanceTab(forward: true)
            } else {
                self.moveSelection(deltaRow: 1, deltaCol: 0, extend: false)
            }
            self.redrawAll()
        }

        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerContainer)
        addSubview(scrollView)

        headerHeightConstraint = headerContainer.heightAnchor.constraint(equalToConstant: layout.headerHeight)
        NSLayoutConstraint.activate([
            headerContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerContainer.topAnchor.constraint(equalTo: topAnchor),
            headerHeightConstraint,

            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        buildHeader()
        applyTheme()
        selection = SelectionController(start: GridCellAddress(row: 0, column: MotorSheetColumn.engineNumber.rawValue))

        boundsObservation = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.syncHeaderScroll()
                self.layoutVisibleCells()
            }
        }

        let pinch = NSMagnificationGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        scrollView.addGestureRecognizer(pinch)
    }

    deinit {
        if let boundsObservation {
            NotificationCenter.default.removeObserver(boundsObservation)
        }
    }

    private func buildHeader() {
        headerContainer.wantsLayer = true
        headerContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        headerDocumentView.wantsLayer = true
        headerDocumentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let clip = NSView()
        clip.translatesAutoresizingMaskIntoConstraints = false
        clip.wantsLayer = true
        clip.layer?.masksToBounds = true
        headerContainer.addSubview(clip)
        headerDocumentView.translatesAutoresizingMaskIntoConstraints = false
        clip.addSubview(headerDocumentView)

        NSLayoutConstraint.activate([
            clip.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            clip.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            clip.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            clip.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            headerDocumentView.topAnchor.constraint(equalTo: clip.topAnchor),
            headerDocumentView.heightAnchor.constraint(equalTo: clip.heightAnchor)
        ])

        let titles = [
            "#", "Номер двигателя", "Комплектация", "Особые отметки", "Кол-во", "Коробка", "Дата прихода", "Дата продажи", ""
        ]
        headerFields = titles.map { title in
            let f = NSTextField(labelWithString: title)
            f.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            f.textColor = .secondaryLabelColor
            f.alignment = .left
            f.translatesAutoresizingMaskIntoConstraints = false
            headerDocumentView.addSubview(f)
            return f
        }
    }

    private func layoutHeaderFields() {
        let h = layout.headerHeight
        var x: CGFloat = 0
        for i in 0..<headerFields.count {
            let w = layout.columnWidth(at: i)
            headerFields[i].frame = CGRect(x: x, y: 0, width: w, height: h)
            headerFields[i].alignment = i == 0 || i == 4 || i == 6 || i == 7 ? .center : .left
            x += w
        }
        headerDocumentView.frame = CGRect(x: 0, y: 0, width: layout.totalWidth(), height: h)
    }

    private func syncHeaderScroll() {
        let ox = scrollView.contentView.bounds.origin.x
        headerDocumentView.frame.origin.x = -ox
    }

    func reload(motors: [MotorRowDTO], mergePending: (Int64) -> GridMotorRowDraft?) {
        editor.endEditing(commit: false)
        baselineDTOs = Dictionary(uniqueKeysWithValues: motors.map { ($0.id, $0) })
        store.reload(from: motors, mergePending: mergePending)
        if store.rowCount > 0 {
            let start = GridCellAddress(row: 0, column: MotorSheetColumn.engineNumber.rawValue)
            selection = SelectionController(start: start)
        }
        resizeDocument()
        layoutHeaderFields()
        layoutVisibleCells()
        redrawOverlays()
    }

    func setZoom(_ z: CGFloat) {
        let clamped = min(max(z, 0.75), 1.6)
        layout.setZoom(clamped)
        headerHeightConstraint.constant = layout.headerHeight
        layoutHeaderFields()
        resizeDocument()
        layoutVisibleCells()
        redrawOverlays()
    }

    private func resizeDocument() {
        let w = layout.totalWidth()
        let h = CGFloat(store.rowCount) * layout.rowHeight
        documentView.frame = CGRect(x: 0, y: 0, width: w, height: h)
        cellContainer.frame = documentView.bounds
        selectionFillView.frame = documentView.bounds
        lineView.frame = documentView.bounds
        activeBorderView.frame = documentView.bounds
        lineView.rowCount = store.rowCount
        lineView.layout = layout
        lineView.needsDisplay = true
        selectionFillView.layout = layout
        selectionFillView.selection = selection
        activeBorderView.layout = layout
        activeBorderView.selection = selection
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        commandBus.setUndoManager(window?.undoManager)
        applyTheme()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyTheme()
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let pt = convertToDocument(event)
        guard let cell = layout.cellAt(point: pt, rowCount: store.rowCount) else { return }
        handlePointerDown(event: event, cell: cell)
    }

    override func mouseDragged(with event: NSEvent) {
        let pt = convertToDocument(event)
        guard let cell = layout.cellAt(point: pt, rowCount: store.rowCount) else { return }
        handlePointerDrag(event: event, cell: cell)
    }

    override func mouseUp(with event: NSEvent) {
        let pt = convertToDocument(event)
        guard let cell = layout.cellAt(point: pt, rowCount: store.rowCount) else {
            isDraggingSelection = false
            selection.resetAnchorToHead()
            return
        }
        handlePointerUp(event: event, cell: cell)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags
        let shift = flags.contains(.shift)

        if flags.contains(.command), event.charactersIgnoringModifiers == "c" {
            copySelection()
            return
        }
        if flags.contains(.command), event.charactersIgnoringModifiers == "v" {
            pasteAtSelection()
            return
        }
        if flags.contains(.command), event.charactersIgnoringModifiers == "z" {
            window?.undoManager?.undo()
            redrawAll()
            delegate?.excelGridDataDidChange(self)
            return
        }

        switch event.specialKey {
        case .leftArrow:
            moveSelection(deltaRow: 0, deltaCol: -1, extend: shift)
            redrawOverlays()
        case .rightArrow:
            moveSelection(deltaRow: 0, deltaCol: 1, extend: shift)
            redrawOverlays()
        case .upArrow:
            moveSelection(deltaRow: -1, deltaCol: 0, extend: shift)
            redrawOverlays()
        case .downArrow:
            moveSelection(deltaRow: 1, deltaCol: 0, extend: shift)
            redrawOverlays()
        case .tab:
            if shift {
                advanceTab(forward: false)
            } else {
                advanceTab(forward: true)
            }
            redrawOverlays()
        case .carriageReturn, .newline:
            moveSelection(deltaRow: 1, deltaCol: 0, extend: false)
            redrawOverlays()
        case .delete, .backspace, .deleteForward:
            deletePrimaryRange()
            redrawAll()
        case .f2:
            beginEditIfEditable(selection.activeCell)
        default:
            super.keyDown(with: event)
        }
    }

    @objc private func handlePinch(_ gr: NSMagnificationGestureRecognizer) {
        switch gr.state {
        case .began:
            pinchZoomStart = layout.zoom
        case .changed:
            var z = pinchZoomStart * gr.magnification
            z = min(max(z, 0.75), 1.6)
            setZoom(z)
            pinchZoomStart = z
            gr.magnification = 1
            delegate?.excelGridZoomDidChange(self, zoom: z)
        default:
            break
        }
    }

    func performSaveAll(
        onSaveMotorRow: (Int64, MotorInlineDraft) -> Void,
        onCreateMotor: (MotorInlineDraft) -> Void
    ) -> Bool {
        editor.endEditing(commit: true)
        var did = false
        for r in 0..<store.rowCount {
            guard let row = store.row(at: r), let mid = row.motorID else { continue }
            guard let base = baselineDTOs[mid] else { continue }
            if row.draft != GridMotorRowDraft(motorDTO: base) {
                onSaveMotorRow(mid, MotorInlineDraft(grid: row.draft))
                did = true
            }
        }
        for r in 0..<store.rowCount {
            guard let row = store.row(at: r), row.motorID == nil, row.draft.hasAnyData else { continue }
            onCreateMotor(MotorInlineDraft(grid: row.draft))
            did = true
        }
        return did
    }

    // MARK: - Internals

    private func convertToDocument(_ event: NSEvent) -> CGPoint {
        let win = event.locationInWindow
        let inClip = scrollView.contentView.convert(win, from: nil)
        return documentView.convert(inClip, from: scrollView.contentView)
    }

    private func layoutVisibleCells() {
        guard store.rowCount > 0 else { return }

        let visible = scrollView.documentVisibleRect
        var rowRange = viewport.visibleRowRange(
            scrollY: visible.origin.y,
            viewportHeight: visible.height,
            rowHeight: layout.rowHeight,
            totalRows: store.rowCount
        )
        if let lastVisibleRow = rowRange.last {
            let oldCount = store.rowCount
            store.expandIfNeeded(visibleRowIndex: lastVisibleRow)
            if store.rowCount != oldCount {
                resizeDocument()
                rowRange = viewport.visibleRowRange(
                    scrollY: visible.origin.y,
                    viewportHeight: visible.height,
                    rowHeight: layout.rowHeight,
                    totalRows: store.rowCount
                )
            }
        }
        let widths = (0..<layout.columnCount).map { layout.columnWidth(at: $0) }
        let colRange = viewport.visibleColumnRange(
            scrollX: visible.origin.x,
            viewportWidth: visible.width,
            columnWidths: widths
        )

        var needed = Set<GridCellAddress>()
        needed.reserveCapacity(rowRange.count * colRange.count)
        for r in rowRange {
            for c in colRange {
                needed.insert(GridCellAddress(row: r, column: c))
            }
        }

        let staleAddresses = visibleCellViews.keys.filter { !needed.contains($0) }
        for addr in staleAddresses {
            guard let view = visibleCellViews.removeValue(forKey: addr) else { continue }
            pool.recycle(view)
        }

        for addr in needed {
            let frame = layout.cellFrame(row: addr.row, column: addr.column)
            let view: PooledGridCellView
            if let existing = visibleCellViews[addr] {
                view = existing
            } else {
                view = pool.dequeue(into: cellContainer)
                visibleCellViews[addr] = view
            }
            if view.frame != frame {
                view.frame = frame
            }
            configurePooledCell(view, row: addr.row, column: addr.column)
        }
    }

    private func configurePooledCell(_ v: PooledGridCellView, row: Int, column: Int) {
        v.applyPalette(GridPalette.current(for: effectiveAppearance))
        let address = GridCellAddress(row: row, column: column)
        v.address = address
        v.onMouseDown = { [weak self] event, tappedCell in
            self?.handlePointerDown(event: event, cell: tappedCell)
        }
        v.onMouseDragged = { [weak self] event, tappedCell in
            self?.handlePointerDrag(event: event, cell: tappedCell)
        }
        v.onMouseUp = { [weak self] event, tappedCell in
            self?.handlePointerUp(event: event, cell: tappedCell)
        }
        switch column {
        case MotorSheetColumn.rowNumber.rawValue:
            v.configureAsRowNumber(row + 1)
        case MotorSheetColumn.action.rawValue:
            let mid = store.motorID(atRow: row)
            v.configureAsSellButton(row: row, visible: mid != nil)
            v.onSell = { [weak self] r in
                guard let self, let id = self.store.motorID(atRow: r) else { return }
                self.delegate?.excelGrid(self, toggleSoldMotorID: id)
            }
        default:
            let text = store.value(at: GridCellAddress(row: row, column: column))
            let align: NSTextAlignment = (column == MotorSheetColumn.quantity.rawValue
                || column == MotorSheetColumn.arrivalDate.rawValue
                || column == MotorSheetColumn.soldDate.rawValue) ? .center : .left
            v.configureAsText(text, alignment: align)
        }
    }

    private func redrawOverlays() {
        selectionFillView.selection = selection
        activeBorderView.selection = selection
        selectionFillView.needsDisplay = true
        activeBorderView.needsDisplay = true
    }

    private func redrawAll() {
        redrawOverlays()
        layoutVisibleCells()
    }

    private func applyTheme() {
        let palette = GridPalette.current(for: effectiveAppearance)
        documentView.layer?.backgroundColor = palette.background.cgColor
        headerContainer.layer?.backgroundColor = palette.headerBackground.cgColor
        headerDocumentView.layer?.backgroundColor = palette.headerBackground.cgColor
        lineView.lineColor = palette.gridLine
        selectionFillView.selectionColor = palette.selectionFill
        selectionFillView.activeColor = palette.activeFill
        activeBorderView.borderColor = palette.activeBorder
        for field in headerFields {
            field.textColor = palette.textSecondary
        }
        for view in visibleCellViews.values {
            view.applyPalette(palette)
        }
        lineView.needsDisplay = true
        redrawOverlays()
    }

    private func handlePointerDown(event: NSEvent, cell: GridCellAddress) {
        window?.makeFirstResponder(self)
        if event.clickCount == 2 {
            editor.endEditing(commit: false)
            beginEditIfEditable(cell)
            return
        }

        editor.endEditing(commit: false)
        let shift = event.modifierFlags.contains(.shift)
        let cmd = event.modifierFlags.contains(.command)
        selection.click(at: cell, shift: shift, cmd: cmd)
        isDraggingSelection = true
        redrawOverlays()
    }

    private func handlePointerDrag(event: NSEvent, cell: GridCellAddress) {
        _ = event
        guard isDraggingSelection else { return }
        selection.dragUpdate(to: cell)
        redrawOverlays()
    }

    private func handlePointerUp(event: NSEvent, cell: GridCellAddress) {
        _ = event
        _ = cell
        isDraggingSelection = false
        selection.resetAnchorToHead()
    }

    private func beginEditIfEditable(_ cell: GridCellAddress) {
        guard MotorSheetColumn.editableRange.contains(cell.column) else { return }
        let frame = layout.cellFrame(row: cell.row, column: cell.column)
        let text = store.value(at: cell)
        editor.beginEdit(address: cell, frame: frame, text: text)
    }

    private func commitCell(_ address: GridCellAddress, text: String) {
        commandBus.applyCellEdit(address: address, newValue: text, actionName: "Edit Cell")
        delegate?.excelGridDataDidChange(self)
        redrawAll()
    }

    private func moveSelection(deltaRow: Int, deltaCol: Int, extend: Bool) {
        let cur = selection.activeCell
        var r = cur.row + deltaRow
        var c = cur.column + deltaCol
        r = max(0, min(max(0, store.rowCount - 1), r))
        c = max(0, min(MotorSheetColumn.action.rawValue, c))
        if deltaRow > 0, r >= store.rowCount - 1 {
            store.expandIfNeeded(visibleRowIndex: r)
            resizeDocument()
        }
        let next = GridCellAddress(row: r, column: c)
        selection.moveHead(to: next, extendSelection: extend)
        editor.endEditing(commit: false)
    }

    private func advanceTab(forward: Bool) {
        var r = selection.activeCell.row
        var c = selection.activeCell.column
        if forward {
            if c < MotorSheetColumn.soldDate.rawValue {
                c = max(MotorSheetColumn.engineNumber.rawValue, c + 1)
            } else {
                r += 1
                c = MotorSheetColumn.engineNumber.rawValue
                store.expandIfNeeded(visibleRowIndex: r)
                resizeDocument()
            }
        } else {
            if c > MotorSheetColumn.engineNumber.rawValue {
                c -= 1
            } else {
                r = max(0, r - 1)
                c = MotorSheetColumn.soldDate.rawValue
            }
        }
        r = max(0, min(store.rowCount - 1, r))
        selection.moveHead(to: GridCellAddress(row: r, column: c), extendSelection: false)
        editor.endEditing(commit: false)
    }

    private func copySelection() {
        let range = selection.primaryRange
        var lines: [String] = []
        for r in range.minRow...range.maxRow {
            var cols: [String] = []
            for c in range.minColumn...range.maxColumn {
                if MotorSheetColumn.editableRange.contains(c) {
                    cols.append(store.value(at: GridCellAddress(row: r, column: c)))
                } else {
                    cols.append("")
                }
            }
            lines.append(cols.joined(separator: "\t"))
        }
        let str = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
    }

    private func pasteAtSelection() {
        guard let str = NSPasteboard.general.string(forType: .string) else { return }
        let matrix = parseTSV(str)
        let origin = selection.activeCell
        var ops: [(GridCellAddress, String)] = []
        for (rOff, line) in matrix.enumerated() {
            for (cOff, val) in line.enumerated() {
                let r = origin.row + rOff
                let c = origin.column + cOff
                guard MotorSheetColumn.editableRange.contains(c) else { continue }
                ops.append((GridCellAddress(row: r, column: c), val))
            }
        }
        guard !ops.isEmpty else { return }
        let maxRow = ops.map(\.0.row).max() ?? 0
        store.ensureRowCount(maxRow + 1)
        resizeDocument()
        window?.undoManager?.beginUndoGrouping()
        for (addr, val) in ops {
            commandBus.applyCellEdit(address: addr, newValue: val, actionName: "Paste")
        }
        window?.undoManager?.endUndoGrouping()
        window?.undoManager?.setActionName("Paste")
        delegate?.excelGridDataDidChange(self)
        redrawAll()
    }

    private func parseTSV(_ str: String) -> [[String]] {
        str.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            line.split(separator: "\t", omittingEmptySubsequences: false).map { String($0) }
        }
    }

    private func deletePrimaryRange() {
        let range = selection.primaryRange
        var toClear: [(GridCellAddress, String)] = []
        for r in range.minRow...range.maxRow {
            for c in range.minColumn...range.maxColumn {
                guard MotorSheetColumn.editableRange.contains(c) else { continue }
                let addr = GridCellAddress(row: r, column: c)
                guard r < store.rowCount else { continue }
                let cur = store.value(at: addr)
                guard !cur.isEmpty else { continue }
                toClear.append((addr, cur))
            }
        }
        guard !toClear.isEmpty else { return }
        window?.undoManager?.beginUndoGrouping()
        for (addr, _) in toClear {
            commandBus.applyCellEdit(address: addr, newValue: "", actionName: "Delete")
        }
        window?.undoManager?.endUndoGrouping()
        window?.undoManager?.setActionName("Delete")
        delegate?.excelGridDataDidChange(self)
        redrawAll()
    }
}

// MARK: - Draft bridging

extension GridMotorRowDraft {
    init(motorDTO: MotorRowDTO) {
        self.init(
            serialCode: motorDTO.serialCode,
            configuration: motorDTO.configuration,
            notes: motorDTO.notes,
            quantity: motorDTO.quantity,
            transmission: motorDTO.transmission,
            arrivalDate: motorDTO.arrivalDate,
            soldDate: motorDTO.soldDate
        )
    }
}

extension MotorInlineDraft {
    init(grid: GridMotorRowDraft) {
        self.init(
            serialCode: grid.serialCode,
            configuration: grid.configuration,
            notes: grid.notes,
            quantity: grid.quantity,
            transmission: grid.transmission,
            arrivalDate: grid.arrivalDate,
            soldDate: grid.soldDate
        )
    }
}

#endif
