import SwiftUI

#if os(macOS)

struct ExportSettingsView: View {
    @Binding var isPresented: Bool
    let onExport: (ExportSettings) -> Void
    let database: DatabaseService
    
    @State private var settings: ExportSettings
    @State private var allSpecificCategories: [DatabaseService.SpecificCategory] = []
    @State private var isLoadingCategories = false
    
    let currentFilters: CurrentFilters?
    
    init(
        isPresented: Binding<Bool>,
        database: DatabaseService,
        currentFilters: CurrentFilters? = nil,
        onExport: @escaping (ExportSettings) -> Void
    ) {
        self._isPresented = isPresented
        self.database = database
        self.currentFilters = currentFilters
        self.onExport = onExport
        // Загружаем сохраненные настройки или используем по умолчанию
        self._settings = State(initialValue: ExportSettings.load())
    }
    
    struct CurrentFilters {
        let searchText: String
        let availabilityFilter: MotorAvailabilityFilter
        let brandID: Int64?
        let engineID: Int64?
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. ПРОДАННЫЕ МОТОРЫ
                Section {
                    Toggle("Экспортировать проданные моторы", isOn: $settings.includeSoldMotors)
                        .help("Если включено, создастся лист 'Проданные' с проданными моторами")
                } header: {
                    Text("Проданные моторы")
                } footer: {
                    Text(settings.includeSoldMotors
                         ? "Лист 'Проданные' будет создан с датами продажи"
                         : "Проданные моторы не будут включены в экспорт")
                }
                
                // 2. МОТОРЫ В НАЛИЧИИ
                Section {
                    Toggle("Экспортировать моторы в наличии", isOn: $settings.includeAvailableMotors)
                        .help("Если выключено, лист 'В наличии' не будет создан")
                } header: {
                    Text("Моторы в наличии")
                } footer: {
                    Text(settings.includeAvailableMotors
                         ? "Моторы в наличии будут экспортированы"
                         : "Моторы в наличии не будут включены в экспорт")
                }
                
                // 3. СТРУКТУРА ЛИСТОВ
                Section {
                    Picker("Структура листов", selection: $settings.sheetStructure) {
                        ForEach(ExportSettings.SheetStructure.allCases, id: \.self) { structure in
                            Text(structure.title).tag(structure)
                        }
                    }
                    .pickerStyle(.radioGroup)
                } header: {
                    Text("Структура листов")
                } footer: {
                    Text(settings.sheetStructure == .separateByEngine
                         ? "Каждый двигатель будет в отдельном листе"
                         : "Все моторы будут в одном общем листе")
                }
                
                // 4. СПЕЦИФИЧНЫЕ КАТЕГОРИИ
                Section {
                    if isLoadingCategories {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else if allSpecificCategories.isEmpty {
                        Text("Нет специфичных категорий")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(allSpecificCategories) { category in
                            Toggle(
                                category.name,
                                isOn: Binding(
                                    get: { settings.selectedSpecificCategoryIDs.contains(category.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            settings.selectedSpecificCategoryIDs.insert(category.id)
                                        } else {
                                            settings.selectedSpecificCategoryIDs.remove(category.id)
                                        }
                                    }
                                )
                            )
                        }
                    }
                } header: {
                    Text("Специфичные категории")
                } footer: {
                    Text("Выберите категории для экспорта")
                }
                
                // 5. ФОРМАТИРОВАНИЕ
                Section {
                    Toggle("Экспортировать с форматированием", isOn: $settings.includeFormatting)
                        .help("Если включено, цвета и форматирование будут перенесены в Excel")
                } header: {
                    Text("Форматирование")
                } footer: {
                    Text(settings.includeFormatting
                         ? "Цвета, жирность и заливка будут включены"
                         : "Экспорт будет без форматирования")
                }
                
                // 6. ФИЛЬТРЫ
                Section {
                    Toggle("Учитывать текущие фильтры", isOn: $settings.respectCurrentFilters)
                        .help("Если включено, экспортируются только видимые данные")
                    
                    if settings.respectCurrentFilters, let filters = currentFilters {
                        VStack(alignment: .leading, spacing: 4) {
                            if !filters.searchText.isEmpty {
                                Label("Поиск: \(filters.searchText)", systemImage: "magnifyingglass")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if filters.availabilityFilter != .all {
                                Label("Фильтр: \(filters.availabilityFilter.title)", systemImage: "line.3.horizontal.decrease")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if filters.brandID != nil || filters.engineID != nil {
                                Label("Выбран бренд/двигатель", systemImage: "tag")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                } header: {
                    Text("Фильтры")
                } footer: {
                    Text(settings.respectCurrentFilters
                         ? "Экспортируются только данные, видимые сейчас в таблице"
                         : "Экспортируются все данные без учета фильтров")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Настройки экспорта Excel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Экспортировать") {
                        // Сохраняем настройки
                        settings.save()
                        // Вызываем экспорт
                        onExport(settings)
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .task {
                await loadSpecificCategories()
            }
        }
        .frame(width: 600, height: 700)
    }
    
    @MainActor
    private func loadSpecificCategories() async {
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        
        do {
            allSpecificCategories = try database.fetchAllSpecificCategories()
            
            // Если настройки пустые, выбираем все категории по умолчанию
            if settings.selectedSpecificCategoryIDs.isEmpty && !allSpecificCategories.isEmpty {
                settings.selectedSpecificCategoryIDs = Set(allSpecificCategories.map { $0.id })
            }
        } catch {
            // Ошибка загрузки - оставляем пустым
            allSpecificCategories = []
        }
    }
}

#endif
