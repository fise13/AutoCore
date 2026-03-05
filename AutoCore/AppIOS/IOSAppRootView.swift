//
//  IOSAppRootView.swift
//  AutoCore
//
//  Отдельное приложение для iPhone. Использует только общую БД и слой данных (AppState/AppViewModel).
//  Весь UI — только для iOS, без привязки к macOS.
//

import SwiftUI

#if os(iOS)

private let iosTabItems: [FintechTabBarItem] = [
    FintechTabBarItem(id: 0, title: "Бухгалтерия", systemImage: "dollarsign.circle"),
    FintechTabBarItem(id: 1, title: "Ещё", systemImage: "ellipsis.circle")
]

struct IOSAppRootView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var appViewModel: AppViewModel
    
    @State private var selectedTab = 0
    @State private var showSettings = false
    @State private var showProfile = false
    
    var body: some View {
        iosTabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $showSettings) {
                if let backupService = appState.backupService,
                   let featureFlagService = appState.featureFlagService,
                   let settingsService = appState.settingsService {
                    SettingsView(
                        backupService: backupService,
                        featureFlagService: featureFlagService,
                        settingsService: settingsService,
                        recoveryState: appState.recoveryState,
                        databaseService: appViewModel.database
                    )
                }
            }
            .sheet(isPresented: $showProfile) {
                if let auth = appState.authViewModel {
                    ProfileView(authViewModel: auth, onDismiss: { showProfile = false })
                }
            }
    }
    
    private var iosTabContent: some View {
        TabView(selection: $selectedTab) {
            IOSAccountingTabView(database: appViewModel.database)
                .tag(0)
            IOSMoreTabView(appState: appState, onSettings: { showSettings = true }, onProfile: { showProfile = true })
                .tag(1)
        }
    }
}

#endif
