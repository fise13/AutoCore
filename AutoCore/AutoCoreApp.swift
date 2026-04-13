//
//  AutoCoreApp.swift
//  AutoCore
//
//  Created by Виктор on 15.01.2026.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

#if os(macOS)
import AppKit

@main
struct AutoCoreApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState: AppState
    @State private var hasCompletedUserConfigOnboarding = UserConfigStore.shared.hasCompletedOnboarding
    
    init() {
        // Инициализируем Firebase до создания AppState / сервисов.
        FirebaseApp.configure()
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
                        if appState.companyId.isEmpty {
                            OnboardingView(authViewModel: authViewModel)
                                .id("onboardingView")
                        } else if !hasCompletedUserConfigOnboarding {
                            UserConfigOnboardingView {
                                hasCompletedUserConfigOnboarding = true
                            }
                            .id("userConfigOnboardingView")
                        } else if let appViewModel = appState.appViewModel {
                            RootView(appViewModel: appViewModel, appState: appState)
                                .id("rootView")
                        } else {
                            ContentUnavailableView(L10n.App.databaseErrorTitle, systemImage: "exclamationmark.triangle.fill")
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
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
        .windowStyle(.automatic)
        .commands {
            // Меню "Правка"
            CommandGroup(replacing: .undoRedo) {
                Button(L10n.Menu.undo) {
                    if let appViewModel = appState.appViewModel {
                        appViewModel.undoManager.undo()
                    }
                }
                .keyboardShortcut("z", modifiers: .command)

                Button(L10n.Menu.redo) {
                    if let appViewModel = appState.appViewModel {
                        appViewModel.undoManager.redo()
                    }
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            
            // Меню "Файл"
            CommandGroup(replacing: .newItem) {
                Button(L10n.Menu.newMotor) {
                    if appState.appViewModel != nil {
                        NotificationCenter.default.post(name: NSNotification.Name("OpenAddMotor"), object: nil)
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Divider()

                Button(L10n.Menu.importExcel) {
                    if appState.appViewModel != nil {
                        NotificationCenter.default.post(name: NSNotification.Name("OpenImport"), object: nil)
                    }
                }
                .keyboardShortcut("i", modifiers: .command)

                Button(L10n.Menu.exportExcel) {
                    if appState.appViewModel != nil {
                        NotificationCenter.default.post(name: NSNotification.Name("OpenExport"), object: nil)
                    }
                }
                .keyboardShortcut("e", modifiers: .command)
            }
            
            #if DEBUG
            CommandGroup(after: .toolbar) {
                Divider()
                
                Button(L10n.Menu.testerPanel) {
                    openTesterWindow()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
            #endif

            CommandMenu(L10n.Menu.motorsMenu) {
                Button(L10n.Menu.addMotor) {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenAddMotor"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button(L10n.Menu.markSold) {
                    NotificationCenter.default.post(name: NSNotification.Name("SellMotor"), object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button(L10n.Menu.duplicate) {
                    NotificationCenter.default.post(name: NSNotification.Name("DuplicateMotor"), object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)

                Divider()

                Button(L10n.Menu.importFromExcel) {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenImport"), object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button(L10n.Menu.exportToExcel) {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenExport"), object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Сохранить изменения") {
                    NotificationCenter.default.post(name: .motorGridSaveRequested, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        
    }
    
    private func openTesterWindow() {
        guard let appViewModel = appState.appViewModel else { return }
        appDelegate.presentTesterPanel(
            database: appViewModel.database,
            companyId: appState.companyId,
            onDataChanged: { appViewModel.refreshAll() }
        )
    }
}

#endif

