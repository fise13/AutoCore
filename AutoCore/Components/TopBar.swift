//
//  TopBar.swift
//  AutoCore
//
//  Custom top control bar - search, add button, settings, user avatar
//

import SwiftUI

#if os(macOS)

enum TopBarContext {
    case motors(
        availabilityFilter: MotorAvailabilityFilter,
        onAvailabilityFilterChange: (MotorAvailabilityFilter) -> Void,
        searchText: String,
        onSearchTextChange: (String) -> Void,
        onAdd: () -> Void,
        onImport: () -> Void,
        onExport: () -> Void,
        onSell: (() -> Void)?,
        onSettings: () -> Void,
        onLogout: (() -> Void)?,
        onInviteManagement: (() -> Void)?,
        onCompanyMembers: (() -> Void)?,
        currentUser: UserEntity?
    )
    case accounting(
        searchText: String,
        onSearchTextChange: (String) -> Void,
        onAddExpense: () -> Void,
        onExport: (() -> Void)?,
        onSettings: () -> Void,
        onLogout: (() -> Void)?,
        currentUser: UserEntity?
    )
}

struct TopBar: View {
    let context: TopBarContext
    
    @State private var localSearchText: String = ""
    
    var body: some View {
        Group {
            switch context {
            case .motors(
                let availabilityFilter,
                let onAvailabilityFilterChange,
                let searchText,
                let onSearchTextChange,
                let onAdd,
                let onImport,
                let onExport,
                let onSell,
                let onSettings,
                let onLogout,
                let onInviteManagement,
                let onCompanyMembers,
                let currentUser
            ):
                HStack(spacing: 12) {
                    availabilityFilterSegment(availabilityFilter: availabilityFilter, onChange: onAvailabilityFilterChange)
                    searchField(placeholder: "Поиск по номеру, бренду, комплектации...", text: searchText, onChange: onSearchTextChange)
                    Spacer()
                    TopBarButton(icon: "plus", title: "Добавить", shortcut: "n", action: onAdd)
                    TopBarButton(icon: "square.and.arrow.down", title: "Импорт", shortcut: "i", action: onImport)
                    TopBarButton(icon: "square.and.arrow.up", title: "Экспорт", shortcut: "e", action: onExport)
                    if let onSell = onSell {
                        TopBarButton(icon: "checkmark.seal", title: "Продать", shortcut: "s", action: onSell)
                    }
                    TopBarButton(icon: "gearshape.fill", title: "Настройки", shortcut: ",", action: onSettings)
                    if let currentUser = currentUser, let onLogout = onLogout {
                        UserMenuButton(
                            currentUser: currentUser,
                            onLogout: onLogout,
                            onInviteManagement: onInviteManagement,
                            onCompanyMembers: onCompanyMembers
                        )
                    }
                }
            case .accounting(
                let searchText,
                let onSearchTextChange,
                let onAddExpense,
                let onExport,
                let onSettings,
                let onLogout,
                let currentUser
            ):
                HStack(spacing: 12) {
                    searchField(placeholder: "Поиск по описанию, категории...", text: searchText, onChange: onSearchTextChange)
                    Spacer()
                    if let onExport = onExport {
                        TopBarButton(icon: "square.and.arrow.up", title: "Экспорт", action: onExport)
                    }
                    TopBarButton(icon: "plus.circle.fill", title: "Добавить расход", shortcut: "n", action: onAddExpense, prominent: true)
                    TopBarButton(icon: "gearshape.fill", title: "Настройки", shortcut: ",", action: onSettings)
                    if let currentUser = currentUser, let onLogout = onLogout {
                        UserMenuButton(currentUser: currentUser, onLogout: onLogout, onInviteManagement: nil, onCompanyMembers: nil)
                    }
                }
            }
        }
        .padding(.horizontal, DSSpacing.x2)
        .padding(.vertical, 12)
        .background(DSColors.topBarBackground)
        .overlay(
            Rectangle()
                .fill(DSColors.separator)
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private func availabilityFilterSegment(availabilityFilter: MotorAvailabilityFilter, onChange: @escaping (MotorAvailabilityFilter) -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach(MotorAvailabilityFilter.allCases) { filter in
                Button {
                    onChange(filter)
                } label: {
                    Text(filter.title)
                        .font(DSTypography.button)
                        .foregroundColor(availabilityFilter == filter ? DSColors.textPrimary : DSColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(availabilityFilter == filter ? DSColors.accent.opacity(0.2) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(DSColors.card)
        .cornerRadius(8)
    }
    
    private func searchField(placeholder: String, text: String, onChange: @escaping (String) -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(DSColors.textSecondary)
            
            TextField(placeholder, text: Binding(
                get: { localSearchText.isEmpty && !text.isEmpty ? text : localSearchText },
                set: { newValue in
                    localSearchText = newValue
                    onChange(newValue)
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundColor(DSColors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 280)
        .background(DSColors.card)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DSColors.separator, lineWidth: 1)
        )
        .onAppear { localSearchText = text }
        .onChange(of: text) { _, newValue in
            if localSearchText != newValue && localSearchText.isEmpty {
                localSearchText = newValue
            }
        }
    }
}

// MARK: - TopBar Button

private struct TopBarButton: View {
    let icon: String
    let title: String
    var shortcut: String? = nil
    let action: () -> Void
    var prominent: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(DSTypography.button)
            }
            .foregroundColor(prominent ? .white : DSColors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(prominent ? DSColors.accent : DSColors.card)
            )
        }
        .buttonStyle(.plain)
        .help(title)
        .modifier(OptionalKeyboardShortcutModifier(shortcut: shortcut))
    }
}

// MARK: - User Menu Button

private struct UserMenuButton: View {
    let currentUser: UserEntity
    let onLogout: () -> Void
    let onInviteManagement: (() -> Void)?
    let onCompanyMembers: (() -> Void)?
    
    var body: some View {
        Menu {
            VStack(alignment: .leading, spacing: 4) {
                if let displayName = currentUser.displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DSColors.textPrimary)
                }
                Text(currentUser.email)
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            if let onInvite = onInviteManagement {
                Button("Приглашения…", action: onInvite)
            }
            if let onMembers = onCompanyMembers {
                Button("Участники компании…", action: onMembers)
            }
            if onInviteManagement != nil || onCompanyMembers != nil {
                Divider()
            }
            
            Button("Sign Out", action: onLogout)
                .keyboardShortcut("q", modifiers: [.command, .shift])
        } label: {
            HStack(spacing: 6) {
                if let displayName = currentUser.displayName, !displayName.isEmpty {
                    Text(String(displayName.prefix(1)).uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(DSColors.accent)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(DSColors.accent)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(DSColors.card)
            .cornerRadius(8)
        }
        .menuStyle(.borderlessButton)
        .help("Профиль пользователя")
    }
}

// MARK: - Optional Keyboard Shortcut

private struct OptionalKeyboardShortcutModifier: ViewModifier {
    let shortcut: String?
    
    func body(content: Content) -> some View {
        if let s = shortcut, let char = s.first {
            content.keyboardShortcut(KeyEquivalent(char), modifiers: .command)
        } else {
            content
        }
    }
}

#endif
