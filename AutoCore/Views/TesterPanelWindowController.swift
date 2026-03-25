#if os(macOS)
import AppKit
import SwiftUI

/// Управляет отдельным окном панели тестировщика и корректным закрытием.
final class TesterPanelWindowController: NSWindowController, NSWindowDelegate {
    static let panelIdentifier = NSUserInterfaceItemIdentifier("AutoCore.TesterPanel")

    private let testerViewModel: TesterViewModel

    init(database: DatabaseService, companyId: String, onDataChanged: @escaping () -> Void) {
        let vm = TesterViewModel(database: database, companyId: companyId, onDataChanged: onDataChanged)
        self.testerViewModel = vm

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.identifier = Self.panelIdentifier
        window.title = L10n.Tester.windowTitle
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self

        let root = TesterWindowView(viewModel: vm) { [weak self] in
            self?.testerViewModel.invalidatePendingWork()
            self?.close()
        }
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 520, height: 640)
        window.contentView = hosting
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        testerViewModel.invalidatePendingWork()
    }

    func showPanel() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

#endif
