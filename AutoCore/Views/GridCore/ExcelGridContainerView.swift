#if os(macOS)

import SwiftUI

/// SwiftUI bridge for `ExcelGridView` with the same callbacks as `MotorListViewExcel`.
struct ExcelGridMotorSheetRepresentable: NSViewRepresentable {
    var cacheKey: String
    var isActive: Bool = true
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
        context.coordinator.lastSignature = Coordinator.signature(for: motors)
        grid.applyUserConfig(userConfig)
        grid.reload(
            motors: motors,
            mergePending: { context.coordinator.pendingByMotor[$0] },
            pendingCreateDrafts: context.coordinator.pendingCreateDrafts
        )
        grid.setZoom(zoom)
        return grid
    }

    func updateNSView(_ grid: ExcelGridView, context: Context) {
        context.coordinator.applyParent(self)
        guard isActive else { return }
        grid.applyUserConfig(userConfig)
        let newSignature = Coordinator.signature(for: motors)
        var didReload = false
        if newSignature != context.coordinator.lastSignature {
            context.coordinator.lastSignature = newSignature
            context.coordinator.lastMotors = motors
            grid.reload(
                motors: motors,
                mergePending: { context.coordinator.pendingByMotor[$0] },
                pendingCreateDrafts: context.coordinator.pendingCreateDrafts
            )
            didReload = true
        }
        var didZoom = false
        if abs(grid.layout.zoom - zoom) > 0.001 {
            grid.setZoom(zoom)
            didZoom = true
        }
        if !didReload && !didZoom {
            return
        }
        grid.refreshVisibleContent()
    }

    @MainActor
    final class Coordinator: ExcelGridViewDelegate {
        private struct CachedState {
            var pendingByMotor: [Int64: GridMotorRowDraft]
            var pendingCreateDrafts: [GridMotorRowDraft]
            var signature: String
        }

        private static var stateByCacheKey: [String: CachedState] = [:]

        private var parent: ExcelGridMotorSheetRepresentable
        weak var gridView: ExcelGridView?
        var pendingByMotor: [Int64: GridMotorRowDraft] = [:]
        var pendingCreateDrafts: [GridMotorRowDraft] = []
        var lastMotors: [MotorRowDTO] = []
        var lastSignature: String = ""
        private var lastScannedRevision: Int = -1
        private var pendingRebuildTask: Task<Void, Never>?
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
            pendingRebuildTask?.cancel()
            let cacheKey = parent.cacheKey
            let cachedState = CachedState(
                pendingByMotor: pendingByMotor,
                pendingCreateDrafts: pendingCreateDrafts,
                signature: lastSignature
            )
            Task { @MainActor in
                Self.stateByCacheKey[cacheKey] = cachedState
            }
            if let saveObserver {
                NotificationCenter.default.removeObserver(saveObserver)
            }
        }

        func applyParent(_ p: ExcelGridMotorSheetRepresentable) {
            parent = p
            restoreCachedStateIfNeeded()
        }

        func excelGridDataDidChange(_ grid: ExcelGridView) {
            guard grid.store.revision != lastScannedRevision else { return }
            pendingRebuildTask?.cancel()
            pendingRebuildTask = Task { @MainActor [weak self, weak grid] in
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard let self, let grid else { return }
                let unsaved = self.rebuildPendingAndUnsaved(from: grid)
                self.parent.onUnsavedChange(unsaved)
                NotificationCenter.default.post(name: .motorGridUnsavedChangesChanged, object: unsaved)
            }
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
            pendingCreateDrafts.removeAll(keepingCapacity: true)
            lastScannedRevision = grid.store.revision
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
                    pendingCreateDrafts.append(row.draft)
                    hasUnsaved = true
                }
            }
            return hasUnsaved
        }

        private func restoreCachedStateIfNeeded() {
            guard pendingByMotor.isEmpty else { return }
            guard let cached = Self.stateByCacheKey[parent.cacheKey] else { return }
            pendingByMotor = cached.pendingByMotor
            pendingCreateDrafts = cached.pendingCreateDrafts
            lastSignature = cached.signature
        }

        static func signature(for motors: [MotorRowDTO]) -> String {
            guard !motors.isEmpty else { return "0-empty" }
            var hasher = Hasher()
            hasher.combine(motors.count)
            for row in motors {
                hasher.combine(row.id)
                hasher.combine(row.serialCode)
                hasher.combine(row.configuration)
                hasher.combine(row.notes)
                hasher.combine(row.quantity)
                hasher.combine(row.transmission)
                hasher.combine(row.arrivalDate)
                hasher.combine(row.soldDate)
                hasher.combine(row.isSold)
            }
            return "\(hasher.finalize())"
        }

        func runSaveAll() {
            guard let grid = gridView else { return }
            pendingRebuildTask?.cancel()
            let did = grid.performSaveAll(
                onSaveMotorRow: { [weak self] id, draft in
                    self?.parent.onSaveMotorRow(id, draft)
                },
                onCreateMotor: { [weak self] draft in
                    self?.parent.onCreateMotor(draft)
                }
            )
            pendingByMotor.removeAll()
            pendingCreateDrafts.removeAll()
            parent.onUnsavedChange(false)
            NotificationCenter.default.post(name: .motorGridUnsavedChangesChanged, object: false)
            parent.onSaveFinished(did)
        }
    }
}

#endif
