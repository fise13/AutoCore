//
//  IOSMoreTabView.swift
//  AutoCore
//
//  Вкладка «Ещё» на iPhone: профиль, настройки, выход. Только iOS.
//

import SwiftUI

#if os(iOS)

struct IOSMoreTabView: View {
    @ObservedObject var appState: AppState
    let onSettings: () -> Void
    let onProfile: () -> Void
    let onCreateInvite: () -> Void
    let onShowMembers: () -> Void
    var onShowTutorial: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            iOSMoreView(
                onSettings: onSettings,
                onProfile: onProfile,
                onCreateInvite: onCreateInvite,
                onShowMembers: onShowMembers,
                onShowTutorial: onShowTutorial,
                onLogout: appState.authViewModel?.signOut,
                currentUser: appState.authViewModel?.currentUser
            )
        }
    }
}

#endif
