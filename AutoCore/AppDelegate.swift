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
    private var hasUnsavedMotorGridChanges = false
    private var isWaitingForSaveBeforeTerminate = false

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnsavedMotorGridChangesNotification(_:)),
            name: .motorGridUnsavedChangesChanged,
            object: nil
        )
    }

    @objc private func dismissTesterPanel() {
        testerPanelController?.close()
        testerPanelController = nil
    }

    @objc private func handleUnsavedMotorGridChangesNotification(_ notification: Notification) {
        if let hasChanges = notification.object as? Bool {
            hasUnsavedMotorGridChanges = hasChanges
            if isWaitingForSaveBeforeTerminate && !hasChanges {
                isWaitingForSaveBeforeTerminate = false
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("AutoCoreTesterPanelDismiss"), object: nil)
        NotificationCenter.default.removeObserver(self, name: .motorGridUnsavedChangesChanged, object: nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Закрывать приложение при закрытии последнего окна
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard hasUnsavedMotorGridChanges else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "Есть несохраненные изменения"
        alert.informativeText = "В таблице моторов есть несохраненные правки."
        alert.addButton(withTitle: "Сохранить и выйти")
        alert.addButton(withTitle: "Отмена")
        alert.addButton(withTitle: "Закрыть без сохранения")
        alert.alertStyle = .warning

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            isWaitingForSaveBeforeTerminate = true
            NotificationCenter.default.post(name: .motorGridSaveRequested, object: nil)

            // Fallback: если по какой-то причине статус не обновился, не висим бесконечно.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self else { return }
                guard self.isWaitingForSaveBeforeTerminate else { return }
                self.isWaitingForSaveBeforeTerminate = false
                NSApp.reply(toApplicationShouldTerminate: !self.hasUnsavedMotorGridChanges)
            }
            return .terminateLater
        case .alertSecondButtonReturn:
            return .terminateCancel
        case .alertThirdButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }
}
#endif
