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
    private let fillHandleView = GridFillHandleView()

    private let headerContainer = NSView()
    private let headerDocumentView = NSView()
    private var headerFields: [NSTextField] = []
    private var headerHeightConstraint: NSLayoutConstraint!

    private var visibleCellViews: [GridCellAddress: PooledGridCellView] = [:]
    private var isDraggingSelection = false
    private var pinchZoomStart: CGFloat = 1
    private var baselineDTOs: [Int64: MotorRowDTO] = [:]
    private var visibleModelColumns: [MotorSheetColumn] = MotorSheetColumn.allCases
    private var headerTitlesByModelColumn: [Int: String] = [
        MotorSheetColumn.rowNumber.rawValue: "#",
        MotorSheetColumn.engineNumber.rawValue: "Номер двигателя",
        MotorSheetColumn.configuration.rawValue: "Комплектация",
        MotorSheetColumn.notes.rawValue: "Особые отметки",
        MotorSheetColumn.quantity.rawValue: "Кол-во",
        MotorSheetColumn.transmission.rawValue: "Коробка",
        MotorSheetColumn.arrivalDate.rawValue: "Дата прихода",
        MotorSheetColumn.soldDate.rawValue: "Дата продажи",
        MotorSheetColumn.action.rawValue: ""
    ]
    private var hoveredCell: GridCellAddress?
    private var hoveredRow: Int?
    private var lastUserConfigSignature: String?
    /// Двойной Ctrl/Cmd+A — сначала только данные, затем весь лист.
    private var lastSelectAllAt: Date?
    private var isFillHandleDragging = false
    private var fillSourceCell: GridCellAddress?
    private var fillTargetRange: GridRange?

    private var boundsObservation: NSObjectProtocol?
    private var isVisibleLayoutScheduled = false

    private var editableVisualColumns: [Int] {
        (0..<layout.columnCount).filter { visual in
            guard let model = modelColumn(forVisual: visual) else { return false }
            return model.isEditable
        }
    }

    private func modelColumn(forVisual visual: Int) -> MotorSheetColumn? {
        MotorSheetColumn(rawValue: layout.modelColumnIndex(at: visual))
    }

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
        documentView.addSubview(fillHandleView)

        selectionFillView.layout = layout
        lineView.layout = layout
        activeBorderView.layout = layout
        fillHandleView.isHidden = true
        fillHandleView.onMouseDown = { [weak self] event in
            self?.startFillHandleDrag(with: event)
        }
        fillHandleView.onMouseDragged = { [weak self] event in
            self?.updateFillHandleDrag(with: event)
        }
        fillHandleView.onMouseUp = { [weak self] event in
            self?.finishFillHandleDrag(with: event)
        }
        applyTheme()

        editor.attach(host: documentView)
        editor.onCommit = { [weak self] addr, text in
            self?.commitCell(addr, text: text)
        }
        editor.onCancel = { [weak self] in
            self?.redrawAll()
        }
        editor.onUserMovedAfterCommit = { [weak self] move in
            guard let self else { return }
            switch move {
            case .down:
                self.moveSelection(deltaRow: 1, deltaCol: 0, extend: false)
            case .up:
                self.moveSelection(deltaRow: -1, deltaCol: 0, extend: false)
            case .tab:
                self.advanceTab(forward: true)
            case .backTab:
                self.advanceTab(forward: false)
            }
            self.requestGridSave()
            _ = self.window?.makeFirstResponder(self)
            self.redrawOverlays()
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
        selection = SelectionController(start: GridCellAddress(row: 0, column: defaultEditableVisualColumn()))

        boundsObservation = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleVisibleLayoutPass()
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

        rebuildHeaderFields()
    }

    private func rebuildHeaderFields() {
        for field in headerFields {
            field.removeFromSuperview()
        }
        headerFields.removeAll(keepingCapacity: true)

        headerFields = (0..<layout.columnCount).map { visualIndex in
            let f = NSTextField(labelWithString: titleForHeader(visualIndex: visualIndex))
            f.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            f.textColor = .secondaryLabelColor
            f.alignment = .left
            f.translatesAutoresizingMaskIntoConstraints = false
            headerDocumentView.addSubview(f)
            let tap = NSClickGestureRecognizer(target: self, action: #selector(handleHeaderClick(_:)))
            f.addGestureRecognizer(tap)
            f.tag = visualIndex
            return f
        }
    }

    private func titleForHeader(visualIndex: Int) -> String {
        let modelIndex = layout.modelColumnIndex(at: visualIndex)
        return headerTitlesByModelColumn[modelIndex] ?? ""
    }

    private func layoutHeaderFields() {
        let h = layout.headerHeight
        var x: CGFloat = 0
        for i in 0..<headerFields.count {
            let w = layout.columnWidth(at: i)
            headerFields[i].frame = CGRect(x: x, y: 0, width: w, height: h)
            headerFields[i].stringValue = titleForHeader(visualIndex: i)
            let model = modelColumn(forVisual: i)
            headerFields[i].alignment = (model == .rowNumber || model == .quantity || model == .arrivalDate || model == .soldDate || model == .action) ? .center : .left
            headerFields[i].tag = i
            x += w
        }
        headerDocumentView.frame = CGRect(x: 0, y: 0, width: layout.totalWidth(), height: h)
    }

    @objc private func handleHeaderClick(_ recognizer: NSClickGestureRecognizer) {
        guard let header = recognizer.view as? NSTextField else { return }
        let visualColumn = header.tag
        guard let model = modelColumn(forVisual: visualColumn), model.isEditable, store.rowCount > 0 else { return }
        let top = GridCellAddress(row: 0, column: visualColumn)
        let bottom = GridCellAddress(row: max(0, store.rowCount - 1), column: visualColumn)
        selection.selectRange(GridRange.spanning(top, bottom), active: top)
        redrawOverlays()
    }

    private func syncHeaderScroll() {
        let ox = scrollView.contentView.bounds.origin.x
        headerDocumentView.frame.origin.x = -ox
    }

    private func defaultEditableVisualColumn() -> Int {
        editableVisualColumns.first ?? 0
    }

    func applyUserConfig(_ config: UserConfig?) {
        let signature = config.map { cfg in
            "\(cfg.businessType.rawValue)|\(cfg.showSaleDate)|" +
            cfg.columns.map { "\($0.id):\($0.title):\($0.isVisible)" }.joined(separator: "|")
        } ?? "default"
        guard signature != lastUserConfigSignature else { return }
        lastUserConfigSignature = signature

        if let config {
            var ordered: [MotorSheetColumn] = [.rowNumber]
            var titles = headerTitlesByModelColumn
            for item in config.columns where item.isVisible {
                guard let model = modelColumn(fromUserConfigID: item.id), model != .rowNumber, model != .action else { continue }
                if model == .soldDate, config.showSaleDate == false { continue }
                if !ordered.contains(model) {
                    ordered.append(model)
                }
                titles[model.rawValue] = item.title
            }
            if !ordered.contains(where: { $0.isEditable }) {
                ordered.append(.engineNumber)
            }
            ordered.append(.action)
            visibleModelColumns = ordered
            headerTitlesByModelColumn = titles
        } else {
            visibleModelColumns = MotorSheetColumn.allCases
            headerTitlesByModelColumn = [
                MotorSheetColumn.rowNumber.rawValue: "#",
                MotorSheetColumn.engineNumber.rawValue: "Номер двигателя",
                MotorSheetColumn.configuration.rawValue: "Комплектация",
                MotorSheetColumn.notes.rawValue: "Особые отметки",
                MotorSheetColumn.quantity.rawValue: "Кол-во",
                MotorSheetColumn.transmission.rawValue: "Коробка",
                MotorSheetColumn.arrivalDate.rawValue: "Дата прихода",
                MotorSheetColumn.soldDate.rawValue: "Дата продажи",
                MotorSheetColumn.action.rawValue: ""
            ]
        }

        layout.setColumnOrder(visibleModelColumns.map(\.rawValue))
        lineView.columnCount = layout.columnCount
        rebuildHeaderFields()
        layoutHeaderFields()
        resizeDocument()
        redrawAll()
    }

    private func modelColumn(fromUserConfigID id: String) -> MotorSheetColumn? {
        switch id {
        case "engineNumber": return .engineNumber
        case "configuration": return .configuration
        case "notes": return .notes
        case "quantity": return .quantity
        case "transmission": return .transmission
        case "arrivalDate": return .arrivalDate
        case "soldDate": return .soldDate
        default: return nil
        }
    }

    private func scheduleVisibleLayoutPass() {
        guard !isVisibleLayoutScheduled else { return }
        isVisibleLayoutScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isVisibleLayoutScheduled = false
            self.hoveredCell = nil
            self.hoveredRow = nil
            self.syncHeaderScroll()
            self.layoutVisibleCells()
        }
    }

    func reload(
        motors: [MotorRowDTO],
        mergePending: (Int64) -> GridMotorRowDraft?,
        pendingCreateDrafts: [GridMotorRowDraft] = []
    ) {
        editor.endEditing(commit: false)
        baselineDTOs = Dictionary(uniqueKeysWithValues: motors.map { ($0.id, $0) })
        store.reload(
            from: motors,
            mergePending: mergePending,
            pendingCreateDrafts: pendingCreateDrafts
        )
        if store.rowCount > 0 {
            let start = GridCellAddress(row: 0, column: defaultEditableVisualColumn())
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

    /// Forces visible cells to reconfigure without waiting for scroll events.
    func refreshVisibleContent() {
        syncHeaderScroll()
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
        documentView.addSubview(fillHandleView, positioned: .above, relativeTo: activeBorderView)
        lineView.rowCount = store.rowCount
        lineView.columnCount = layout.columnCount
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
        guard let cell = cellAtOrNearestEdge(for: pt) else { return }
        handlePointerDrag(event: event, cell: cell)
    }

    override func mouseUp(with event: NSEvent) {
        let pt = convertToDocument(event)
        guard let cell = cellAtOrNearestEdge(for: pt) else {
            if isFillHandleDragging {
                isFillHandleDragging = false
                applyFillHandleIfNeeded()
                fillSourceCell = nil
                fillTargetRange = nil
                return
            }
            isDraggingSelection = false
            selection.resetAnchorToHead()
            return
        }
        handlePointerUp(event: event, cell: cell)
    }

    private func cellAtOrNearestEdge(for point: CGPoint) -> GridCellAddress? {
        if let exact = layout.cellAt(point: point, rowCount: store.rowCount) {
            return exact
        }
        guard store.rowCount > 0, layout.columnCount > 0 else { return nil }
        let clampedX = min(max(point.x, 0), max(0, layout.totalWidth() - 1))
        let totalHeight = CGFloat(store.rowCount) * layout.rowHeight
        let clampedY = min(max(point.y, 0), max(0, totalHeight - 1))
        return layout.cellAt(point: CGPoint(x: clampedX, y: clampedY), rowCount: store.rowCount)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags
        let shift = flags.contains(.shift)
        let cmd = flags.contains(.command)
        let ctrl = flags.contains(.control)
        let excelMod = cmd || ctrl
        let ch = event.charactersIgnoringModifiers?.lowercased()

        if cmd || ctrl, ch == "c" {
            copySelection()
            return
        }
        if cmd || ctrl, ch == "v" {
            pasteAtSelection()
            return
        }
        if cmd || ctrl, ch == "x" {
            copySelection()
            deletePrimaryRange()
            return
        }
        if cmd, ch == "z", !shift {
            window?.undoManager?.undo()
            redrawAll()
            delegate?.excelGridDataDidChange(self)
            return
        }
        if cmd, shift, ch == "z" {
            window?.undoManager?.redo()
            redrawAll()
            delegate?.excelGridDataDidChange(self)
            return
        }
        if ctrl, ch == "y" {
            window?.undoManager?.redo()
            redrawAll()
            delegate?.excelGridDataDidChange(self)
            return
        }
        if (cmd || ctrl), ch == "a" {
            applySelectAllSequence()
            scrollToActiveCellIfNeeded()
            redrawOverlays()
            return
        }
        if ctrl, ch == "d" {
            fillDownFromTopRow()
            return
        }
        if ctrl, ch == "r" {
            fillRightFromLeftColumn()
            return
        }
        if event.charactersIgnoringModifiers == "\u{1b}" {
            editor.endEditing(commit: false)
            redrawOverlays()
            return
        }
        if !editor.isEditing, let typed = immediateTypedInput(from: event), !typed.isEmpty {
            beginEditIfEditable(selection.activeCell, seedText: typed)
            return
        }

        // Page Up / Page Down
        if event.keyCode == 116 || event.keyCode == 121 {
            pageScroll(down: event.keyCode == 121)
            return
        }

        // Home / End (клавиши и сочетания)
        if homeEndKey(event: event, shift: shift, excelMod: excelMod) {
            scrollToActiveCellIfNeeded()
            redrawOverlays()
            return
        }

        // Ctrl+Space / Shift+Space
        if ctrl, event.keyCode == 49 { // Space
            selectEntireColumn()
            scrollToActiveCellIfNeeded()
            redrawOverlays()
            return
        }
        if shift, event.keyCode == 49, !ctrl, !cmd {
            selectEntireRow()
            scrollToActiveCellIfNeeded()
            redrawOverlays()
            return
        }

        // Enter: Shift+Enter — вверх (когда не в редакторе)
        if !editor.isEditing, (event.keyCode == 36 || event.keyCode == 76), shift {
            moveSelection(deltaRow: -1, deltaCol: 0, extend: false)
            scrollToActiveCellIfNeeded()
            redrawOverlays()
            return
        }

        // Ctrl+Enter — заполнить выделение активным значением
        if ctrl, (event.keyCode == 36 || event.keyCode == 76), !shift {
            fillSelectionWithActiveValue()
            return
        }

        if let sk = event.specialKey {
            switch sk {
            case .leftArrow:
                if excelMod {
                    applyDataBlockJump(horizontal: true, direction: -1, extend: shift)
                } else {
                    moveSelection(deltaRow: 0, deltaCol: -1, extend: shift)
                }
                scrollToActiveCellIfNeeded()
                redrawOverlays()
            case .rightArrow:
                if excelMod {
                    applyDataBlockJump(horizontal: true, direction: 1, extend: shift)
                } else {
                    moveSelection(deltaRow: 0, deltaCol: 1, extend: shift)
                }
                scrollToActiveCellIfNeeded()
                redrawOverlays()
            case .upArrow:
                if excelMod {
                    applyDataBlockJump(horizontal: false, direction: -1, extend: shift)
                } else {
                    moveSelection(deltaRow: -1, deltaCol: 0, extend: shift)
                }
                scrollToActiveCellIfNeeded()
                redrawOverlays()
            case .downArrow:
                if excelMod {
                    applyDataBlockJump(horizontal: false, direction: 1, extend: shift)
                } else {
                    moveSelection(deltaRow: 1, deltaCol: 0, extend: shift)
                }
                scrollToActiveCellIfNeeded()
                redrawOverlays()
            case .tab:
                if shift {
                    advanceTab(forward: false)
                } else {
                    advanceTab(forward: true)
                }
                scrollToActiveCellIfNeeded()
                redrawOverlays()
            case .carriageReturn, .newline:
                if !editor.isEditing {
                    moveSelection(deltaRow: 1, deltaCol: 0, extend: false)
                    scrollToActiveCellIfNeeded()
                    redrawOverlays()
                }
            case .delete, .backspace, .deleteForward:
                deletePrimaryRange()
                redrawAll()
            default:
                super.keyDown(with: event)
                return
            }
            return
        }

        if !editor.isEditing {
            let kc = event.keyCode
            if (123...126).contains(kc) {
                let goLeft = kc == 123
                let goRight = kc == 124
                let goDown = kc == 125
                let goUp = kc == 126
                if excelMod {
                    if goLeft { applyDataBlockJump(horizontal: true, direction: -1, extend: shift) }
                    if goRight { applyDataBlockJump(horizontal: true, direction: 1, extend: shift) }
                    if goUp { applyDataBlockJump(horizontal: false, direction: -1, extend: shift) }
                    if goDown { applyDataBlockJump(horizontal: false, direction: 1, extend: shift) }
                } else {
                    if goLeft { moveSelection(deltaRow: 0, deltaCol: -1, extend: shift) }
                    if goRight { moveSelection(deltaRow: 0, deltaCol: 1, extend: shift) }
                    if goUp { moveSelection(deltaRow: -1, deltaCol: 0, extend: shift) }
                    if goDown { moveSelection(deltaRow: 1, deltaCol: 0, extend: shift) }
                }
                scrollToActiveCellIfNeeded()
                redrawOverlays()
                return
            }
            if kc == 36 || kc == 76, !shift {
                moveSelection(deltaRow: 1, deltaCol: 0, extend: false)
                scrollToActiveCellIfNeeded()
                redrawOverlays()
                return
            }
        }

        if event.keyCode == 120 {
            beginEditIfEditable(selection.activeCell)
            return
        }

        super.keyDown(with: event)
    }

    private func homeEndKey(event: NSEvent, shift: Bool, excelMod: Bool) -> Bool {
        let k = event.keyCode
        let sk = event.specialKey
        // 115 Home, 119 End (часто)
        let isHome = k == 115 || sk == .home
        let isEnd = k == 119 || sk == .end
        guard isHome || isEnd else { return false }

        if excelMod, isHome {
            let a = GridCellAddress(row: 0, column: 0)
            selection.moveHead(to: a, extendSelection: shift)
            editor.endEditing(commit: false)
            return true
        }
        if excelMod, isEnd {
            if let last = GridDataRegionNavigation.lastUsedCell(
                navigable: editableVisualColumns,
                rowCount: store.rowCount,
                layout: layout,
                store: store
            ) {
                selection.moveHead(to: last, extendSelection: shift)
            } else {
                let a = GridCellAddress(row: max(0, store.rowCount - 1), column: max(0, layout.columnCount - 1))
                selection.moveHead(to: a, extendSelection: shift)
            }
            editor.endEditing(commit: false)
            return true
        }
        if isHome {
            let c = 0
            let a = GridCellAddress(row: selection.activeCell.row, column: c)
            selection.moveHead(to: a, extendSelection: shift)
            editor.endEditing(commit: false)
            return true
        }
        if isEnd {
            let c = max(0, layout.columnCount - 1)
            let a = GridCellAddress(row: selection.activeCell.row, column: c)
            selection.moveHead(to: a, extendSelection: shift)
            editor.endEditing(commit: false)
            return true
        }
        return false
    }

    private func pageScroll(down: Bool) {
        let h = scrollView.contentView.bounds.height
        var o = scrollView.contentView.bounds.origin
        o.y += (down ? 1 : -1) * max(40, h * 0.85)
        let docH = documentView.frame.height
        let maxY = max(0, docH - h)
        o.y = min(max(0, o.y), maxY)
        scrollView.contentView.setBoundsOrigin(o)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func scrollToActiveCellIfNeeded() {
        let c = selection.activeCell
        let f = layout.cellFrame(row: c.row, column: c.column)
        _ = documentView.scrollToVisible(f.insetBy(dx: -4, dy: -4))
    }

    private func applyDataBlockJump(horizontal: Bool, direction: Int, extend: Bool) {
        let nav = editableVisualColumns
        guard !nav.isEmpty else { return }
        let cur = selection.activeCell
        if horizontal {
            guard let nv = GridDataRegionNavigation.jumpColumnInRow(
                row: cur.row,
                fromVisual: cur.column,
                direction: direction,
                navigable: nav,
                layout: layout,
                store: store
            ) else { return }
            selection.moveHead(to: GridCellAddress(row: cur.row, column: nv), extendSelection: extend)
        } else {
            guard let nr = GridDataRegionNavigation.jumpRowInColumn(
                column: cur.column,
                fromRow: cur.row,
                direction: direction,
                rowCount: store.rowCount,
                layout: layout,
                store: store
            ) else { return }
            selection.moveHead(to: GridCellAddress(row: nr, column: cur.column), extendSelection: extend)
        }
        editor.endEditing(commit: false)
    }

    private func applySelectAllSequence() {
        let now = Date()
        let doubleTap = lastSelectAllAt.map { now.timeIntervalSince($0) < 0.6 } ?? false
        lastSelectAllAt = now

        let lastCol = max(0, layout.columnCount - 1)
        let lastRow = max(0, store.rowCount - 1)
        if doubleTap {
            let full = GridRange(minRow: 0, maxRow: lastRow, minColumn: 0, maxColumn: lastCol)
            selection.selectRange(full, active: GridCellAddress(row: 0, column: 0))
            return
        }
        if let box = GridDataRegionNavigation.boundingDataRange(
            navigable: editableVisualColumns,
            rowCount: store.rowCount,
            layout: layout,
            store: store
        ) {
            selection.selectRange(box, active: GridCellAddress(row: box.minRow, column: box.minColumn))
        } else if store.rowCount > 0 {
            let r = GridRange(minRow: 0, maxRow: lastRow, minColumn: navMin(), maxColumn: navMax())
            selection.selectRange(r, active: GridCellAddress(row: 0, column: navMin()))
        }
        editor.endEditing(commit: false)
    }

    private func navMin() -> Int { editableVisualColumns.first ?? 0 }
    private func navMax() -> Int { editableVisualColumns.last ?? max(0, layout.columnCount - 1) }

    private func selectEntireColumn() {
        let c = selection.activeCell.column
        guard store.rowCount > 0 else { return }
        let r = GridRange(minRow: 0, maxRow: store.rowCount - 1, minColumn: c, maxColumn: c)
        selection.selectRange(r, active: GridCellAddress(row: selection.activeCell.row, column: c))
        editor.endEditing(commit: false)
    }

    private func selectEntireRow() {
        guard store.rowCount > 0 else { return }
        let r = selection.activeCell.row
        let lo = navMin()
        let hi = navMax()
        let range = GridRange(minRow: r, maxRow: r, minColumn: lo, maxColumn: hi)
        selection.selectRange(range, active: GridCellAddress(row: r, column: lo))
        editor.endEditing(commit: false)
    }

    private func fillSelectionWithActiveValue() {
        let active = selection.activeCell
        guard let m = modelColumn(forVisual: active.column), m.isEditable else { return }
        let fill = store.value(at: GridCellAddress(row: active.row, column: m.rawValue))
        var pairs: [(GridCellAddress, String)] = []
        for rng in selection.allRanges() {
            for r in rng.minRow...rng.maxRow {
                for c in rng.minColumn...rng.maxColumn {
                    guard c != active.column || r != active.row else { continue }
                    guard let col = modelColumn(forVisual: c), col.isEditable else { continue }
                    pairs.append((GridCellAddress(row: r, column: col.rawValue), fill))
                }
            }
        }
        guard !pairs.isEmpty else { return }
        let maxR = pairs.map(\.0.row).max() ?? 0
        store.ensureRowCount(maxR + 1)
        window?.undoManager?.beginUndoGrouping()
        commandBus.applyBatch(pairs, actionName: "Fill")
        window?.undoManager?.endUndoGrouping()
        window?.undoManager?.setActionName("Ctrl+Enter")
        delegate?.excelGridDataDidChange(self)
        resizeDocument()
        redrawAll()
    }

    private func fillDownFromTopRow() {
        let range = selection.primaryRange
        guard range.maxRow > range.minRow else { return }
        var pairs: [(GridCellAddress, String)] = []
        for c in range.minColumn...range.maxColumn {
            guard let mc = modelColumn(forVisual: c), mc.isEditable else { continue }
            let v = store.value(at: GridCellAddress(row: range.minRow, column: mc.rawValue))
            for r in (range.minRow + 1)...range.maxRow {
                pairs.append((GridCellAddress(row: r, column: mc.rawValue), v))
            }
        }
        guard !pairs.isEmpty else { return }
        window?.undoManager?.beginUndoGrouping()
        commandBus.applyBatch(pairs, actionName: "Fill Down")
        window?.undoManager?.endUndoGrouping()
        delegate?.excelGridDataDidChange(self)
        redrawAll()
    }

    private func fillRightFromLeftColumn() {
        let range = selection.primaryRange
        guard range.maxColumn > range.minColumn else { return }
        var pairs: [(GridCellAddress, String)] = []
        for r in range.minRow...range.maxRow {
            for c in (range.minColumn + 1)...range.maxColumn {
                guard let dest = modelColumn(forVisual: c), let srcM = modelColumn(forVisual: range.minColumn),
                      dest.isEditable, srcM.isEditable else { continue }
                let v = store.value(at: GridCellAddress(row: r, column: srcM.rawValue))
                pairs.append((GridCellAddress(row: r, column: dest.rawValue), v))
            }
        }
        guard !pairs.isEmpty else { return }
        window?.undoManager?.beginUndoGrouping()
        commandBus.applyBatch(pairs, actionName: "Fill Right")
        window?.undoManager?.endUndoGrouping()
        delegate?.excelGridDataDidChange(self)
        redrawAll()
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
            if store.expandIfNeeded(visibleRowIndex: lastVisibleRow) {
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
        if v.address != address {
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
            v.onHoverChanged = { [weak self] cell, hovered in
                self?.handleHoverChanged(cell: cell, hovered: hovered)
            }
        }
        v.setHovered(hoveredCell == address)
        guard let modelColumn = modelColumn(forVisual: column) else { return }
        switch modelColumn {
        case .rowNumber:
            v.configureAsRowNumber(row + 1)
        case .action:
            let mid = store.motorID(atRow: row)
            v.configureAsSellButton(row: row, visible: mid != nil)
            v.onSell = { [weak self] r in
                guard let self, let id = self.store.motorID(atRow: r) else { return }
                self.delegate?.excelGrid(self, toggleSoldMotorID: id)
            }
        default:
            let text = store.value(at: GridCellAddress(row: row, column: modelColumn.rawValue))
            let align: NSTextAlignment = (modelColumn == .quantity
                || modelColumn == .arrivalDate
                || modelColumn == .soldDate) ? .center : .left
            v.configureAsText(text, alignment: align)
        }
    }

    private func handleHoverChanged(cell: GridCellAddress?, hovered: Bool) {
        if hovered {
            if let previous = hoveredCell, previous != cell {
                visibleCellViews[previous]?.setHovered(false)
            }
            hoveredCell = cell
            hoveredRow = cell?.row
        } else if hoveredCell == cell {
            hoveredCell = nil
            hoveredRow = nil
        }
    }

    private func redrawOverlays() {
        selectionFillView.selection = selection
        activeBorderView.selection = selection
        selectionFillView.needsDisplay = true
        activeBorderView.needsDisplay = true
        updateFillHandleFrame()
    }

    private func redrawAll() {
        redrawOverlays()
        layoutVisibleCells()
    }

    private func requestGridSave() {
        NotificationCenter.default.post(name: .motorGridSaveRequested, object: nil)
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
        fillHandleView.fillColor = NSColor.systemGreen
        fillHandleView.strokeColor = NSColor.white.withAlphaComponent(0.95)
        fillHandleView.needsDisplay = true
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
        if let modelColumn = modelColumn(forVisual: cell.column), modelColumn == .rowNumber {
            let firstEditable = editableVisualColumns.first ?? 0
            let lastEditable = editableVisualColumns.last ?? max(firstEditable, layout.columnCount - 1)
            let range = GridRange(minRow: cell.row, maxRow: cell.row, minColumn: firstEditable, maxColumn: lastEditable)
            selection.selectRange(range, active: GridCellAddress(row: cell.row, column: firstEditable))
            isDraggingSelection = false
            redrawOverlays()
            return
        }
        selection.click(at: cell, shift: shift, cmd: cmd)
        isDraggingSelection = true
        redrawOverlays()
    }

    private func handlePointerDrag(event: NSEvent, cell: GridCellAddress) {
        _ = event
        if isFillHandleDragging, let source = fillSourceCell {
            let target = GridRange(
                minRow: source.row,
                maxRow: max(source.row, cell.row),
                minColumn: source.column,
                maxColumn: source.column
            )
            fillTargetRange = target
            selection.selectRange(target, active: GridCellAddress(row: target.minRow, column: target.minColumn))
            redrawOverlays()
            return
        }
        guard isDraggingSelection else { return }
        selection.dragUpdate(to: cell)
        redrawOverlays()
    }

    private func handlePointerUp(event: NSEvent, cell: GridCellAddress) {
        _ = event
        if isFillHandleDragging {
            _ = cell
            isFillHandleDragging = false
            if fillTargetRange == nil, let source = fillSourceCell {
                fillTargetRange = GridRange(minRow: source.row, maxRow: source.row, minColumn: source.column, maxColumn: source.column)
            }
            applyFillHandleIfNeeded()
            fillSourceCell = nil
            fillTargetRange = nil
            return
        }
        _ = cell
        isDraggingSelection = false
        selection.resetAnchorToHead()
    }

    private func beginEditIfEditable(_ cell: GridCellAddress, seedText: String? = nil) {
        guard let modelColumn = modelColumn(forVisual: cell.column), modelColumn.isEditable else { return }
        let frame = layout.cellFrame(row: cell.row, column: cell.column)
        let baseText = store.value(at: GridCellAddress(row: cell.row, column: modelColumn.rawValue))
        let text = seedText ?? baseText
        editor.beginEdit(address: cell, frame: frame, text: text, selectAll: seedText == nil)
    }

    private func commitCell(_ address: GridCellAddress, text: String) {
        guard let modelColumn = modelColumn(forVisual: address.column), modelColumn.isEditable else { return }
        let modelAddress = GridCellAddress(row: address.row, column: modelColumn.rawValue)
        commandBus.applyCellEdit(address: modelAddress, newValue: text, actionName: "Edit Cell")
        delegate?.excelGridDataDidChange(self)
        refreshVisibleCell(at: address)
        redrawOverlays()
    }

    private func refreshVisibleCell(at address: GridCellAddress) {
        guard let view = visibleCellViews[address] else { return }
        configurePooledCell(view, row: address.row, column: address.column)
    }

    private func moveSelection(deltaRow: Int, deltaCol: Int, extend: Bool) {
        let cur = selection.activeCell
        var r = cur.row + deltaRow
        var c = cur.column + deltaCol
        r = max(0, min(max(0, store.rowCount - 1), r))
        c = max(0, min(max(0, layout.columnCount - 1), c))
        if deltaRow > 0, r >= store.rowCount - 1 {
            if store.expandIfNeeded(visibleRowIndex: r) {
                resizeDocument()
            }
        }
        let next = GridCellAddress(row: r, column: c)
        selection.moveHead(to: next, extendSelection: extend)
        editor.endEditing(commit: false)
    }

    private func advanceTab(forward: Bool) {
        let editable = editableVisualColumns
        guard !editable.isEmpty else { return }
        var r = selection.activeCell.row
        var c = selection.activeCell.column
        if !editable.contains(c) {
            c = editable.first ?? c
        }
        if forward {
            if let idx = editable.firstIndex(of: c), idx < editable.count - 1 {
                c = editable[idx + 1]
            } else {
                r += 1
                c = editable.first ?? c
                if store.expandIfNeeded(visibleRowIndex: r) {
                    resizeDocument()
                }
            }
        } else {
            if let idx = editable.firstIndex(of: c), idx > 0 {
                c = editable[idx - 1]
            } else {
                r = max(0, r - 1)
                c = editable.last ?? c
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
                if let modelColumn = modelColumn(forVisual: c), modelColumn.isEditable {
                    cols.append(store.value(at: GridCellAddress(row: r, column: modelColumn.rawValue)))
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
                guard let modelColumn = modelColumn(forVisual: c), modelColumn.isEditable else { continue }
                ops.append((GridCellAddress(row: r, column: modelColumn.rawValue), val))
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
                guard let modelColumn = modelColumn(forVisual: c), modelColumn.isEditable else { continue }
                let addr = GridCellAddress(row: r, column: modelColumn.rawValue)
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

    private func immediateTypedInput(from event: NSEvent) -> String? {
        let flags = event.modifierFlags
        if flags.contains(.command) || flags.contains(.option) || flags.contains(.control) {
            return nil
        }
        guard let chars = event.characters, chars.count == 1 else { return nil }
        guard chars != "\r", chars != "\t", chars != "\u{7f}" else { return nil }
        if chars.unicodeScalars.allSatisfy({ CharacterSet.controlCharacters.contains($0) }) {
            return nil
        }
        return chars
    }

    private func updateFillHandleFrame() {
        guard selection != nil else {
            fillHandleView.isHidden = true
            return
        }
        let active = selection.activeCell
        guard let modelColumn = modelColumn(forVisual: active.column), modelColumn.isEditable else {
            fillHandleView.isHidden = true
            return
        }
        fillHandleView.isHidden = false
        fillHandleView.frame = fillHandleRect(for: active)
    }

    private func fillHandleRect(for cell: GridCellAddress) -> CGRect {
        let cellRect = layout.cellFrame(row: cell.row, column: cell.column).insetBy(dx: 0.5, dy: 0.5)
        let size: CGFloat = 10
        return CGRect(
            x: cellRect.maxX - size,
            y: cellRect.maxY - size,
            width: size,
            height: size
        )
    }

    private func startFillHandleDrag(with event: NSEvent) {
        _ = event
        let active = selection.activeCell
        guard let modelColumn = modelColumn(forVisual: active.column), modelColumn.isEditable else { return }
        window?.makeFirstResponder(self)
        editor.endEditing(commit: true)
        isFillHandleDragging = true
        fillSourceCell = active
        fillTargetRange = GridRange(minRow: active.row, maxRow: active.row, minColumn: active.column, maxColumn: active.column)
    }

    private func updateFillHandleDrag(with event: NSEvent) {
        guard isFillHandleDragging, let source = fillSourceCell else { return }
        let point = convertToDocument(event)
        let clampedY = min(max(point.y, 0), max(0, documentView.bounds.maxY - 1))
        let probePoint = CGPoint(x: layout.cellFrame(row: source.row, column: source.column).midX, y: clampedY)
        guard let hovered = layout.cellAt(point: probePoint, rowCount: store.rowCount) else { return }
        let targetRow = max(source.row, hovered.row)
        let target = GridRange(minRow: source.row, maxRow: targetRow, minColumn: source.column, maxColumn: source.column)
        fillTargetRange = target
        selection.selectRange(target, active: GridCellAddress(row: source.row, column: source.column))
        redrawOverlays()
    }

    private func finishFillHandleDrag(with event: NSEvent) {
        _ = event
        guard isFillHandleDragging else { return }
        isFillHandleDragging = false
        if fillTargetRange == nil, let source = fillSourceCell {
            fillTargetRange = GridRange(minRow: source.row, maxRow: source.row, minColumn: source.column, maxColumn: source.column)
        }
        applyFillHandleIfNeeded()
        fillSourceCell = nil
        fillTargetRange = nil
    }

    private func applyFillHandleIfNeeded() {
        guard let sourceCell = fillSourceCell, let target = fillTargetRange else { return }
        guard target.maxRow > sourceCell.row else {
            redrawOverlays()
            return
        }

        guard let sourceModel = modelColumn(forVisual: sourceCell.column), sourceModel.isEditable else { return }
        let sourceAddress = GridCellAddress(row: sourceCell.row, column: sourceModel.rawValue)
        let sourceValue = store.value(at: sourceAddress)

        var ops: [(GridCellAddress, String)] = []
        ops.reserveCapacity(max(0, target.maxRow - sourceCell.row))
        for row in (sourceCell.row + 1)...target.maxRow {
            ops.append((GridCellAddress(row: row, column: sourceModel.rawValue), sourceValue))
        }

        guard !ops.isEmpty else {
            redrawOverlays()
            return
        }
        commandBus.applyBatch(ops, actionName: "Fill")
        delegate?.excelGridDataDidChange(self)
        selection.selectRange(target, active: sourceCell)
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
