import SwiftUI

struct AccountingToolbar: ToolbarContent {
    let searchText: String
    let onSearchTextChange: (String) -> Void
    let onAddExpense: () -> Void
    let onExport: (() -> Void)?
    let onSettings: () -> Void
    let onLogout: (() -> Void)?
    let currentUser: UserEntity?
    
    @FocusState private var isSearchFocused: Bool
    @State private var localSearchText: String = ""
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 12) {
                // Поиск
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Поиск по описанию, категории...", text: Binding(
                        get: { localSearchText },
                        set: { newValue in
                            localSearchText = newValue
                            onSearchTextChange(newValue)
                        }
                    ))
                    .textFieldStyle(.plain)
                    .frame(width: 300)
                    .focused($isSearchFocused)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .onAppear {
                    localSearchText = searchText
                }
                .onChange(of: searchText) { _, newValue in
                    if localSearchText != newValue {
                        localSearchText = newValue
                    }
                }
                
                Spacer()
                
                // Кнопка экспорта
                if let onExport = onExport {
                    Button(action: onExport) {
                        Label("Экспорт", systemImage: "square.and.arrow.up")
                    }
                }
                
                // Кнопка добавления расхода
                Button(action: onAddExpense) {
                    Label("Добавить расход", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("n", modifiers: .command)
                
                Button(action: onSettings) {
                    Label("Настройки", systemImage: "gearshape.fill")
                }
                .keyboardShortcut(",", modifiers: .command)
                
                // Profile / Logout
                if let currentUser = currentUser, let onLogout = onLogout {
                    Menu {
                        VStack(alignment: .leading, spacing: 4) {
                            if let displayName = currentUser.displayName, !displayName.isEmpty {
                                Text(displayName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                            Text(currentUser.email)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        Button("Sign Out", action: onLogout)
                            .keyboardShortcut("q", modifiers: [.command, .shift])
                    } label: {
                        HStack(spacing: 6) {
                            if let displayName = currentUser.displayName, !displayName.isEmpty {
                                Text(String(displayName.prefix(1)).uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .imageScale(.medium)
                                    .foregroundStyle(Color.accentColor)
                            }
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                    .help("Профиль пользователя")
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
