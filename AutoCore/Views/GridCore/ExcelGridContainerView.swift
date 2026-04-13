#if os(macOS)

import SwiftUI

/// SwiftUI bridge for `ExcelGridView` with the same callbacks as `MotorListViewExcel`.
struct ExcelGridMotorSheetRepresentable: NSViewRepresentable {
    var motors: [MotorRowDTO]
    var userConfig: UserConfig?
    var zoom: CGFloat
    let onToggleSold: (Int64) -> Void
    let onUnsavedChange: (Bool) -> Void
    let onZoomChange: (CGFloat) -> Void
    let onSaveMotorRow: (Int64, MotorInlineDraft) -> Void
    let onCreateMotor: (MotorInlineDraft) -> Void
    let onSaveFinished: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> ExcelGridView {
        let grid = ExcelGridView()
        grid.delegate = context.coordinator
        context.coordinator.gridView = grid
        context.coordinator.applyParent(self)
        context.coordinator.lastMotors = motors
        grid.applyUserConfig(userConfig)
        grid.reload(motors: motors, mergePending: { context.coordinator.pendingByMotor[$0] })
        grid.setZoom(zoom)
        return grid
    }

    func updateNSView(_ grid: ExcelGridView, context: Context) {
        context.coordinator.applyParent(self)
        grid.applyUserConfig(userConfig)
        if context.coordinator.lastMotors != motors {
            context.coordinator.lastMotors = motors
            grid.reload(motors: motors, mergePending: { context.coordinator.pendingByMotor[$0] })
        }
        if abs(grid.layout.zoom - zoom) > 0.001 {
            grid.setZoom(zoom)
        }
    }

    @MainActor
    final class Coordinator: ExcelGridViewDelegate {
        private var parent: ExcelGridMotorSheetRepresentable
        weak var gridView: ExcelGridView?
        var pendingByMotor: [Int64: GridMotorRowDraft] = [:]
        var lastMotors: [MotorRowDTO] = []
        private var saveObserver: NSObjectProtocol?

        init(parent: ExcelGridMotorSheetRepresentable) {
            self.parent = parent
            saveObserver = NotificationCenter.default.addObserver(
                forName: .motorGridSaveRequested,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.runSaveAll()
                }
            }
        }

        deinit {
            if let saveObserver {
                NotificationCenter.default.removeObserver(saveObserver)
            }
        }

        func applyParent(_ p: ExcelGridMotorSheetRepresentable) {
            parent = p
        }

        func excelGridDataDidChange(_ grid: ExcelGridView) {
            let unsaved = rebuildPendingAndUnsaved(from: grid)
            parent.onUnsavedChange(unsaved)
            NotificationCenter.default.post(name: .motorGridUnsavedChangesChanged, object: unsaved)
        }

        func excelGrid(_ grid: ExcelGridView, toggleSoldMotorID: Int64) {
            parent.onToggleSold(toggleSoldMotorID)
        }

        func excelGridZoomDidChange(_ grid: ExcelGridView, zoom: CGFloat) {
            parent.onZoomChange(zoom)
        }

        @discardableResult
        private func rebuildPendingAndUnsaved(from grid: ExcelGridView) -> Bool {
            pendingByMotor.removeAll()
            let baseById = Dictionary(uniqueKeysWithValues: lastMotors.map { ($0.id, $0) })
            var hasUnsaved = false
            for r in 0..<grid.store.rowCount {
                guard let row = grid.store.row(at: r) else { continue }
                if let mid = row.motorID {
                    guard let base = baseById[mid] else { continue }
                    if row.draft != GridMotorRowDraft(motorDTO: base) {
                        pendingByMotor[mid] = row.draft
                        hasUnsaved = true
                    }
                } else if row.draft.hasAnyData {
                    hasUnsaved = true
                }
            }
            return hasUnsaved
        }

        func runSaveAll() {
            guard let grid = gridView else { return }
            let did = grid.performSaveAll(
                onSaveMotorRow: { [weak self] id, draft in
                    self?.parent.onSaveMotorRow(id, draft)
                },
                onCreateMotor: { [weak self] draft in
                    self?.parent.onCreateMotor(draft)
                }
            )
            pendingByMotor.removeAll()
            parent.onUnsavedChange(false)
            NotificationCenter.default.post(name: .motorGridUnsavedChangesChanged, object: false)
            parent.onSaveFinished(did)
        }
    }
}

#endif
