//
//  IOSAppRootView.swift
//  AutoCore
//
//  Отдельное приложение для iPhone. Использует только общую БД и слой данных (AppState/AppViewModel).
//  Весь UI — только для iOS, без привязки к macOS.
//

import SwiftUI

#if os(iOS)

struct IOSAppRootView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var appViewModel: AppViewModel

    @State private var selectedTab = 0 // 0 – Dashboard, 1 – Операции, 2 – Ещё
    @State private var showSettings = false
    @State private var showProfile = false
    @State private var showInviteCreator = false
    @State private var showMembers = false
    @State private var showTutorial = !TutorialStore.hasCompletedTutorial

    var body: some View {
        let companyId = appState.companyId
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0:
                    IOSDashboardView(
                        database: appViewModel.database,
                        companyId: companyId,
                        currentUser: appState.authViewModel?.currentUser,
                        onViewAllOperations: { selectedTab = 1 }
                    )
                case 1:
                    IOSAccountingTabView(
                        database: appViewModel.database,
                        companyId: companyId,
                        currentUser: appState.authViewModel?.currentUser
                    )
                    .id(companyId)
                case 2:
                    IOSMoreTabView(
                        appState: appState,
                        onSettings: { showSettings = true },
                        onProfile: { showProfile = true },
                        onCreateInvite: { showInviteCreator = true },
                        onShowMembers: { showMembers = true },
                        onShowTutorial: { showTutorial = true }
                    )
                default:
                    IOSDashboardView(
                        database: appViewModel.database,
                        companyId: companyId,
                        currentUser: appState.authViewModel?.currentUser,
                        onViewAllOperations: { selectedTab = 1 }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                removal: .opacity.combined(with: .scale(scale: 1.02))
            ))
            .animation(IOSMotion.adaptiveAnimation(IOSMotion.standard), value: selectedTab)

            IOSFlowlyTabBar(selectedIndex: selectedTab, onSelect: { selectedTab = $0 })
        }
        .ignoresSafeArea(edges: .bottom)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 70)
        }
        .tint(IOSPalette.flowlyBlue)
        .background(IOSScreenBackground())
        .sheet(isPresented: $showSettings) {
            if let backupService = appState.backupService,
               let featureFlagService = appState.featureFlagService,
               let settingsService = appState.settingsService {
                IOSSettingsView(
                    backupService: backupService,
                    featureFlagService: featureFlagService,
                    settingsService: settingsService,
                    recoveryState: appState.recoveryState,
                    databaseService: appViewModel.database,
                    companyId: companyId
                )
            }
        }
        .sheet(isPresented: $showProfile) {
            if let auth = appState.authViewModel {
                IOSProfileView(authViewModel: auth, onDismiss: { showProfile = false })
            }
        }
        .sheet(isPresented: $showInviteCreator) {
            if let auth = appState.authViewModel {
                IOSInviteManagementView(authViewModel: auth)
            }
        }
        .sheet(isPresented: $showMembers) {
            IOSCompanyMembersView(companyId: companyId)
        }
        .iosTutorialOverlay(isPresented: $showTutorial)
    }
}

#endif
