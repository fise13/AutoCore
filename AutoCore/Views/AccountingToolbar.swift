import SwiftUI

struct AccountingToolbar: ToolbarContent {
    let selectedTab: Int
    let onSelectedTabChange: (Int) -> Void
    let searchText: String
    let onSearchTextChange: (String) -> Void
    let onAddOperation: () -> Void
    let onExport: (() -> Void)?
    let onAnalyze: (() -> Void)?
    let onSettings: () -> Void
    let onAccountSettings: (() -> Void)?
    let onLogout: (() -> Void)?
    let currentUser: UserEntity?
    
    @FocusState private var isSearchFocused: Bool
    @State private var localSearchText: String = ""

#if os(macOS)
    private var controlBackground: Color { Color(NSColor.controlBackgroundColor) }
#else
    private var controlBackground: Color { Color(UIColor.secondarySystemBackground) }
#endif
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 12) {
                Picker("Раздел", selection: Binding(
                    get: { selectedTab },
                    set: { onSelectedTabChange($0) }
                )) {
                    Text("Обзор").tag(0)
                    Text("Касса").tag(1)
                    Text("Расходы").tag(2)
                    Text("Операции").tag(3)
                    Text("Авансы").tag(4)
                }
                .pickerStyle(.segmented)
                .frame(width: 420)

                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Поиск...", text: Binding(
                    get: { localSearchText },
                    set: { newValue in
                        localSearchText = newValue
                        onSearchTextChange(newValue)
                    }
                ))
                .textFieldStyle(.plain)
                .frame(width: 220)
                .focused($isSearchFocused)

                Spacer()

                Button(action: onAddOperation) {
                    Label("Новая операция", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("n", modifiers: .command)

                if let onExport = onExport {
                    Button(action: onExport) { Label("Экспорт", systemImage: "square.and.arrow.up") }
                }
                if let onAnalyze = onAnalyze {
                    Button(action: onAnalyze) { Label("Анализ Excel", systemImage: "tablecells.badge.ellipsis") }
                }
                Button(action: onSettings) {
                    Label("Настройки", systemImage: "gearshape.fill")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(controlBackground)
            .cornerRadius(6)
            .onAppear { localSearchText = searchText }
            .onChange(of: searchText) { _, newValue in
                if localSearchText != newValue { localSearchText = newValue }
            }
        }

        ToolbarItem(placement: .automatic) {
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
                    if let onAccountSettings {
                        Button("Настройки аккаунта", action: onAccountSettings)
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
                                .background(Color.accentColor)
                                .clipShape(Circle())
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
                    .background(controlBackground.opacity(0.5))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .help("Профиль пользователя")
            }
        }
    }
}
