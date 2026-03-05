//
//  iOSMoreView.swift
//  AutoCore
//
//  Ещё: настройки, профиль, выход. Для iPhone.
//

import SwiftUI

struct iOSMoreView: View {
    let onSettings: () -> Void
    let onProfile: () -> Void
    let onLogout: (() -> Void)?
    let currentUser: UserEntity?
    
    var body: some View {
        List {
            Section {
                if let user = currentUser {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName ?? user.email)
                                .font(.headline)
                            Text(user.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(user.role.displayName)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section {
                Button(action: onProfile) {
                    Label("Профиль", systemImage: "person.circle")
                }
                Button(action: onSettings) {
                    Label("Настройки", systemImage: "gearshape")
                }
            }
            
            if onLogout != nil {
                Section {
                    Button(role: .destructive, action: { onLogout?() }) {
                        Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
        .navigationTitle("Ещё")
    }
}
