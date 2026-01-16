//
//  AutoCoreApp.swift
//  AutoCore
//
//  Created by Виктор on 15.01.2026.
//

import SwiftUI
import AppKit

@main
struct AutoCoreApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if let appViewModel = appState.appViewModel {
                RootView(appViewModel: appViewModel)
            } else {
                ContentUnavailableView("Ошибка базы данных", systemImage: "exclamationmark.triangle.fill")
                    .overlay(alignment: .bottom) {
                        if let message = appState.errorMessage {
                            Text(message)
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
            }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Отменить") {
                    if let appViewModel = appState.appViewModel {
                        appViewModel.undoManager.undo()
                    }
                }
                .keyboardShortcut("z", modifiers: .command)
                
                Button("Повторить") {
                    if let appViewModel = appState.appViewModel {
                        appViewModel.undoManager.redo()
                    }
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            
            CommandGroup(after: .toolbar) {
                Divider()
                
                Button("Панель тестировщика") {
                    openTesterWindow()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
        
    }
    
    private func openTesterWindow() {
        guard let appViewModel = appState.appViewModel else { return }
        
        // Ищем окно среди открытых окон приложения
        for window in NSApplication.shared.windows {
            if window.title == "Панель тестировщика" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
        
        // Создаем новое окно
        let viewModel = TesterViewModel(database: appViewModel.database) {
            appViewModel.refreshAll()
        }
        let contentView = TesterWindowView(viewModel: viewModel)
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 500, height: 600)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "Панель тестировщика"
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}

