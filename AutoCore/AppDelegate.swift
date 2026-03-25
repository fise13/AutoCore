//
//  AppDelegate.swift
//  AutoCore
//
//  Created by Виктор on 15.01.2026.
//

import Foundation
#if os(macOS)
import AppKit
#endif

/// AppDelegate для системных сервисов (только macOS)
#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {

    private var testerPanelController: TesterPanelWindowController?

    func presentTesterPanel(database: DatabaseService, companyId: String, onDataChanged: @escaping () -> Void) {
        if let existing = testerPanelController, let window = existing.window, window.isVisible {
            existing.showPanel()
            return
        }
        if let w = NSApplication.shared.windows.first(where: { $0.identifier == TesterPanelWindowController.panelIdentifier }) {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = TesterPanelWindowController(database: database, companyId: companyId, onDataChanged: onDataChanged)
        testerPanelController = controller
        controller.showPanel()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dismissTesterPanel),
            name: NSNotification.Name("AutoCoreTesterPanelDismiss"),
            object: nil
        )
    }

    @objc private func dismissTesterPanel() {
        testerPanelController?.close()
        testerPanelController = nil
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("AutoCoreTesterPanelDismiss"), object: nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Закрывать приложение при закрытии последнего окна
        return true
    }
}
#endif
