//
//  iOSMoreView.swift
//  AutoCore
//
//  Ещё: настройки, профиль, выход. Для iPhone.
//

import SwiftUI

#if os(iOS)

struct iOSMoreView: View {
    let onSettings: () -> Void
    let onProfile: () -> Void
    let onCreateInvite: () -> Void
    let onShowMembers: (() -> Void)?
    var onShowTutorial: (() -> Void)? = nil
    let onLogout: (() -> Void)?
    let currentUser: UserEntity?

    private var canManageMembers: Bool {
        guard let user = currentUser else { return false }
        return user.role == .owner || user.role == .admin
    }

    var body: some View {
        ZStack {
            IOSScreenBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    flowlyHeaderSection
                    flowlyContentSection
                }
            }
        }
        .navigationBarHidden(true)
    }

    private var flowlyHeaderSection: some View {
        ZStack(alignment: .topLeading) {
            IOSPalette.headerGradient
                .frame(height: 140)
                .ignoresSafeArea(edges: .top)
            VStack(alignment: .leading, spacing: 4) {
                Text("Ещё")
                    .font(IOSDesign.Typography.title)
                    .foregroundStyle(.white)
                Text("Настройки и профиль")
                    .font(IOSDesign.Typography.subtitle)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.x3)
            .padding(.top, 60)
            .padding(.bottom, Spacing.x3)
        }
    }

    private var flowlyContentSection: some View {
        VStack(spacing: Spacing.x3) {
            if let user = currentUser {
                IOSFlowlyCard {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(IOSPalette.flowlyBlue.opacity(0.2))
                                .frame(width: 52, height: 52)
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(IOSPalette.flowlyBlue)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.displayName ?? user.email)
                                .font(.headline)
                                .foregroundStyle(IOSPalette.textPrimary)
                            Text(user.email)
                                .font(.caption)
                                .foregroundStyle(IOSPalette.textSecondary)
                            Text(user.role.localizedDisplayName)
                                .font(.caption2)
                                .foregroundStyle(IOSPalette.textSecondary.opacity(0.9))
                        }
                        Spacer()
                    }
                }
            }

            Button(action: onCreateInvite) {
                Label("Создать invite-код", systemImage: "plus.circle.fill")
            }
            .buttonStyle(IOSInviteCTAButtonStyle())

            if canManageMembers, let onShowMembers {
                Button(action: onShowMembers) {
                    Label("Сотрудники", systemImage: "person.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IOSInviteCTAButtonStyle())
            }

            IOSFlowlyCard {
                VStack(spacing: 0) {
                    Button(action: onProfile) {
                        settingsRow("Профиль", icon: "person.circle")
                    }
                    Divider().overlay(IOSPalette.border)
                    Button(action: onSettings) {
                        settingsRow("Настройки", icon: "gearshape")
                    }
                    if let onShowTutorial {
                        Divider().overlay(IOSPalette.border)
                        Button(action: onShowTutorial) {
                            settingsRow("Повторить обучение", icon: "graduationcap.fill")
                        }
                    }
                }
            }

            if onLogout != nil {
                Button(action: { onLogout?() }) {
                    Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(IOSPalette.negative)
                }
                .buttonStyle(IOSSecondaryButtonStyle())
            }
        }
        .padding(Spacing.x3)
    }

    @ViewBuilder
    private func settingsRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(IOSPalette.flowlyBlue)
            Text(title)
                .font(IOSDesign.Typography.body)
                .foregroundStyle(IOSPalette.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(IOSPalette.textSecondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 12)
    }
}

// MARK: - Preview

#if DEBUG
struct iOSMoreView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                iOSMoreView(
                    onSettings: {},
                    onProfile: {},
                    onCreateInvite: {},
                    onShowMembers: {},
                    onShowTutorial: {},
                    onLogout: {},
                    currentUser: UserEntity(id: "1", email: "demo@autocore.app", displayName: "Demo", provider: .email, role: .owner, companyId: "c1")
                )
            }
            .preferredColorScheme(.light)

            NavigationStack {
                iOSMoreView(
                    onSettings: {},
                    onProfile: {},
                    onCreateInvite: {},
                    onShowMembers: {},
                    onShowTutorial: {},
                    onLogout: {},
                    currentUser: UserEntity(id: "1", email: "demo@autocore.app", displayName: "Demo", provider: .email, role: .owner, companyId: "c1")
                )
            }
            .preferredColorScheme(.dark)
        }
    }
}
#endif

#endif
