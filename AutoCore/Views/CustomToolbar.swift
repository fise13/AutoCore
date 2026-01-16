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
            }
            .padding(.horizontal, 16)
        }
    }
}
