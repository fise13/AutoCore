#if os(macOS)

import Foundation

/// Applies grid mutations with NSUndoManager integration.
final class GridCommandBus {
    private weak var undoManager: UndoManager?
    private let store: GridDataStore

    init(store: GridDataStore, undoManager: UndoManager?) {
        self.store = store
        self.undoManager = undoManager
    }

    private var manager: UndoManager? { undoManager }

    func setUndoManager(_ undoManager: UndoManager?) {
        self.undoManager = undoManager
    }

    /// Sets cell value with undo; no-op if unchanged.
    func applyCellEdit(address: GridCellAddress, newValue: String, actionName: String = "Edit") {
        let old = store.value(at: address)
        guard old != newValue else { return }
        store.setValue(newValue, at: address)
        manager?.registerUndo(withTarget: self) { bus in
            bus.applyCellEdit(address: address, newValue: old, actionName: actionName)
        }
        manager?.setActionName(actionName)
    }

    /// Batch apply with single undo step.
    func applyBatch(_ entries: [(GridCellAddress, String)], actionName: String) {
        var pairs: [(GridCellAddress, old: String, new: String)] = []
        for (addr, newVal) in entries {
            let old = store.value(at: addr)
            guard old != newVal else { continue }
            pairs.append((addr, old, newVal))
        }
        guard !pairs.isEmpty else { return }
        for p in pairs {
            store.setValue(p.new, at: p.0)
        }
        let snapshot = pairs
        manager?.registerUndo(withTarget: self) { bus in
            var revert: [(GridCellAddress, String)] = []
            for p in snapshot {
                revert.append((p.0, p.old))
            }
            bus.applyBatch(revert, actionName: actionName)
        }
        manager?.setActionName(actionName)
    }
}

#endif
