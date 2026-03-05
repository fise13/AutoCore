//
//  AutoCoreApp.swift
//  AutoCore
//
//  Created by Виктор on 15.01.2026.
//

import SwiftUI
import AppKit
import FirebaseCore

@main
struct AutoCoreApp: App {
    // Регистрация AppDelegate для инициализации Firebase
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appState: AppState
    
    init() {
        // КРИТИЧНО: Инициализируем Firebase СИНХРОННО до создания AppState
        // Это должно быть сделано ПЕРЕД любым использованием FirebaseAuth
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase configured in AutoCoreApp.init()")
        }
        
        // Теперь безопасно создаем AppState (который создаст FirebaseAuthAdapter)
        _appState = StateObject(wrappedValue: AppState())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                // Проверка аутентификации
                if let authViewModel = appState.authViewModel {
                    // Используем authState напрямую для реактивности
                    switch authViewModel.authState {
                    case .authenticated:
                        // Пользователь авторизован - показываем основной UI
                        if let appViewModel = appState.appViewModel {
                            RootView(appViewModel: appViewModel, appState: appState)
                                .id("rootView")
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
                    case .unauthenticated, .authenticating:
                        // Пользователь не авторизован или происходит аутентификация - показываем LoginView
                        LoginView(authViewModel: authViewModel)
                            .id("loginView")
                    }
                } else {
                    // AuthViewModel еще не инициализирован - показываем загрузку
                    ProgressView()
                        .scaleEffect(1.5)
                        .onAppear {
                            print("⏳ [AutoCoreApp] AuthViewModel not initialized yet")
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: appState.authViewModel?.authState)
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
                    if appState.appViewModel != nil {
                        // Открываем окно добавления мотора
                        NotificationCenter.default.post(name: NSNotification.Name("OpenAddMotor"), object: nil)
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Divider()
                
                Button("Импорт Excel") {
                    if appState.appViewModel != nil {
                        NotificationCenter.default.post(name: NSNotification.Name("OpenImport"), object: nil)
                    }
                }
                .keyboardShortcut("i", modifiers: .command)
                
                Button("Экспорт Excel") {
                    if appState.appViewModel != nil {
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

