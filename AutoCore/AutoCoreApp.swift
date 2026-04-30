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

    enum WindowMode {
        case login
        case app
    }
    
    init() {
        // Инициализируем Firebase до создания AppState / сервисов.
        FirebaseApp.configure()
        _appState = StateObject(wrappedValue: AppState())
    }

    var body: some Scene {
        WindowGroup {
            let windowMode = resolvedWindowMode
            Group {
                // Проверка аутентификации
                if let authViewModel = appState.authViewModel {
                    // Используем authState напрямую для реактивности
                    switch authViewModel.authState {
                    case .loading:
                        SplashView()
                            .id("splashView")
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
                    case .authenticating:
                        SplashView()
                            .id("splashView_authenticating")
                    case .unauthenticated:
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
            .background(FixedMainWindowConfigurator(mode: windowMode))
        }
        .windowStyle(.automatic)
        .windowResizability(resolvedWindowMode == .login ? .contentSize : .automatic)
        .commands {
            // Меню "Правка"
            CommandGroup(replacing: .undoRedo) {
                Button(L10n.Menu.undo) {
                    if let windowUndoManager = NSApp.keyWindow?.undoManager, windowUndoManager.canUndo {
                        windowUndoManager.undo()
                    } else if let appViewModel = appState.appViewModel {
                        appViewModel.undoManager.undo()
                    }
                }
                .keyboardShortcut("z", modifiers: .command)

                Button(L10n.Menu.redo) {
                    if let windowUndoManager = NSApp.keyWindow?.undoManager, windowUndoManager.canRedo {
                        windowUndoManager.redo()
                    } else if let appViewModel = appState.appViewModel {
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

    private var resolvedWindowMode: WindowMode {
        guard let authState = appState.authViewModel?.authState else {
            return .login
        }

        switch authState {
        case .authenticated:
            return .app
        case .loading, .authenticating, .unauthenticated:
            return .login
        }
    }
}

private struct SplashView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.07, green: 0.09, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image("LoginLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 78, height: 78)
                    .shadow(color: Color.red.opacity(0.2), radius: 12, x: 0, y: 0)
                    .scaleEffect(pulse ? 1.03 : 0.97)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)

                Text("AutoCore")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)

                Text("Подготовка рабочего пространства...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))

                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .frame(width: 220)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 24)
        }
        .onAppear { pulse = true }
    }
}

private struct FixedMainWindowConfigurator: NSViewRepresentable {
    let mode: AutoCoreApp.WindowMode

    final class Coordinator: NSObject, NSWindowDelegate {
        var lastMode: AutoCoreApp.WindowMode?
        var didAutoFullscreen = false
        var lockedSize: NSSize?
        var isExitingFullscreenForLogin = false
        var pendingLoginApplyWorkItem: DispatchWorkItem?

        func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
            lockedSize ?? frameSize
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            applyWindowConfiguration(for: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyWindowConfiguration(for: nsView.window, coordinator: context.coordinator)
        }
    }

    private func applyWindowConfiguration(for window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        let loginSize = NSSize(width: 420, height: 520)

        if coordinator.lastMode == mode {
            // Режим не менялся — избегаем повторной конфигурации окна во время layout-pass.
            if mode == .login {
                coordinator.lockedSize = loginSize
                if window.delegate !== coordinator {
                    window.delegate = coordinator
                }
            }
            return
        }

        switch mode {
        case .login:
            coordinator.didAutoFullscreen = false

            if window.styleMask.contains(.fullScreen) {
                if !coordinator.isExitingFullscreenForLogin {
                    coordinator.isExitingFullscreenForLogin = true
                    coordinator.lastMode = .login
                    DispatchQueue.main.async {
                        if window.styleMask.contains(.fullScreen) {
                            window.toggleFullScreen(nil)
                        }
                    }
                }
                return
            }
            coordinator.isExitingFullscreenForLogin = false
            coordinator.pendingLoginApplyWorkItem?.cancel()
            let work = DispatchWorkItem {
                guard !window.styleMask.contains(.fullScreen) else { return }
                window.minSize = loginSize
                window.maxSize = loginSize
                if abs(window.frame.size.width - loginSize.width) > 0.5 || abs(window.frame.size.height - loginSize.height) > 0.5 {
                    window.setContentSize(loginSize)
                }

                window.styleMask.remove(.resizable)
                window.styleMask.insert(.closable)
                window.styleMask.insert(.miniaturizable)
                window.collectionBehavior.remove(.fullScreenPrimary)
                window.collectionBehavior.remove(.fullScreenAuxiliary)
                window.standardWindowButton(.zoomButton)?.isEnabled = false
                window.standardWindowButton(.zoomButton)?.isHidden = true
                coordinator.lockedSize = loginSize
                if window.delegate !== coordinator {
                    window.delegate = coordinator
                }
                if coordinator.lastMode != .login {
                    window.center()
                }
            }
            coordinator.pendingLoginApplyWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)

        case .app:
            coordinator.isExitingFullscreenForLogin = false
            coordinator.pendingLoginApplyWorkItem?.cancel()
            coordinator.pendingLoginApplyWorkItem = nil
            window.minSize = NSSize(width: 900, height: 600)
            window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            window.styleMask.insert(.resizable)
            window.styleMask.insert(.closable)
            window.styleMask.insert(.miniaturizable)
            window.collectionBehavior.insert(.fullScreenPrimary)
            window.standardWindowButton(.zoomButton)?.isEnabled = true
            window.standardWindowButton(.zoomButton)?.isHidden = false
            coordinator.lockedSize = nil
            if window.delegate === coordinator {
                window.delegate = nil
            }

            if !coordinator.didAutoFullscreen && !window.styleMask.contains(.fullScreen) {
                coordinator.didAutoFullscreen = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    guard !window.styleMask.contains(.fullScreen) else { return }
                    window.toggleFullScreen(nil)
                }
            }
        }

        coordinator.lastMode = mode
    }
}

#endif

