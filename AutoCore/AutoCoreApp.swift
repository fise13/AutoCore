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
            // Меню "Правка"
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
            
            // Меню "Файл"
            CommandGroup(replacing: .newItem) {
                Button("Новый мотор") {
                    if let appViewModel = appState.appViewModel {
                        // Открываем окно добавления мотора
                        NotificationCenter.default.post(name: NSNotification.Name("OpenAddMotor"), object: nil)
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Divider()
                
                Button("Импорт Excel") {
                    if let appViewModel = appState.appViewModel {
                        NotificationCenter.default.post(name: NSNotification.Name("OpenImport"), object: nil)
                    }
                }
                .keyboardShortcut("i", modifiers: .command)
                
                Button("Экспорт Excel") {
                    if let appViewModel = appState.appViewModel {
                        NotificationCenter.default.post(name: NSNotification.Name("OpenExport"), object: nil)
                    }
                }
                .keyboardShortcut("e", modifiers: .command)
            }
            
            // Меню "Вид"
            CommandGroup(after: .toolbar) {
                Divider()
                
                Button("Панель тестировщика") {
                    openTesterWindow()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
            
            // Меню "Моторы"
            CommandMenu("Моторы") {
                Button("Добавить мотор") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenAddMotor"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Divider()
                
                Button("Пометить как проданный") {
                    NotificationCenter.default.post(name: NSNotification.Name("SellMotor"), object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
                
                Button("Дублировать") {
                    NotificationCenter.default.post(name: NSNotification.Name("DuplicateMotor"), object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)
                
                Divider()
                
                Button("Импорт из Excel") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenImport"), object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)
                
                Button("Экспорт в Excel") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenExport"), object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
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

