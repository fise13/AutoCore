import SwiftUI

struct CustomToolbar: ToolbarContent {
    let availabilityFilter: MotorAvailabilityFilter
    let searchText: String
    let onAvailabilityFilterChange: (MotorAvailabilityFilter) -> Void
    let onSearchTextChange: (String) -> Void
    let onImport: () -> Void
    let onExport: () -> Void
    let onAdd: () -> Void
    let onSell: (() -> Void)?
    let onSettings: () -> Void
    let onLogout: (() -> Void)?
    let currentUser: UserEntity?
    
    @FocusState private var isSearchFocused: Bool
    @State private var localSearchText: String = ""
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 12) {
                // Фильтр по наличию
                Picker("Наличие", selection: Binding(
                    get: { availabilityFilter },
                    set: { newValue in
                        // Вызываем напрямую - изменение произойдет после завершения рендера
                        onAvailabilityFilterChange(newValue)
                    }
                )) {
                    ForEach(MotorAvailabilityFilter.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
                
                // Поиск
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Поиск по номеру, бренду, комплектации...", text: Binding(
                        get: { localSearchText },
                        set: { newValue in
                            localSearchText = newValue
                            // Вызываем напрямую - изменение произойдет после завершения рендера
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
                
                // Кнопки действий
                Button(action: onAdd) {
                    Label("Добавить", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button(action: onImport) {
                    Label("Импорт", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("i", modifiers: .command)
                
                Button(action: onExport) {
                    Label("Экспорт", systemImage: "square.and.arrow.up")
                }
                .keyboardShortcut("e", modifiers: .command)
                
                if let onSell = onSell {
                    Button(action: onSell) {
                        Label("Продать", systemImage: "checkmark.seal")
                    }
                    .keyboardShortcut("s", modifiers: .command)
                }
                
                Button(action: onSettings) {
                    Label("Настройки", systemImage: "gearshape.fill")
                }
                .keyboardShortcut(",", modifiers: .command)
                
                // Profile / Logout
                if let currentUser = currentUser, let onLogout = onLogout {
                    Menu {
                        // Заголовок с информацией о пользователе
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
                        // Улучшенный аватар с инициалами
                        HStack(spacing: 6) {
                            if let displayName = currentUser.displayName, !displayName.isEmpty {
                                // Инициалы в круге
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
                                // Иконка пользователя
                                Image(systemName: "person.circle.fill")
                                    .imageScale(.medium)
                                    .foregroundStyle(Color.accentColor)
                            }
                            
                            // Стрелка вниз для меню
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
