#if os(macOS)

import Foundation

protocol GridUndoCommand {
    func apply(to store: GridDataStore)
    func revert(to store: GridDataStore)
}

struct UpdateCellCommand: GridUndoCommand {
    let address: GridCellAddress
    let oldValue: String
    let newValue: String

    func apply(to store: GridDataStore) {
        store.setValue(newValue, at: address)
    }

    func revert(to store: GridDataStore) {
        store.setValue(oldValue, at: address)
    }
}

struct BatchUpdateCellsCommand: GridUndoCommand {
    let entries: [(GridCellAddress, old: String, new: String)]

    func apply(to store: GridDataStore) {
        for e in entries {
            store.setValue(e.new, at: e.0)
        }
    }

    func revert(to store: GridDataStore) {
        for e in entries {
            store.setValue(e.old, at: e.0)
        }
    }
}

#endif
