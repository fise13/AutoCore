import SwiftUI
import UniformTypeIdentifiers
import AppKit
import Combine
import Foundation

struct RootView: View {
    @ObservedObject var appViewModel: AppViewModel
    @StateObject private var importViewModel: ImportViewModel

    @State private var isShowingImportPicker = false
    @State private var isShowingImportPreview = false
    @State private var isShowingAddMotor = false
    @State private var isShowingExportSelection = false
    @State private var isShowingExportSettings = false
    @State private var isShowingCreateCategory = false
    @State private var newCategoryName = ""
    @State private var alertMessage = ""
    @State private var isShowingAlert = false
    @State private var isInspectorVisible = false // Inspector скрыт по умолчанию
    
    // Окно для показа панелей (получается через WindowAccessor)
    @State private var hostWindow: NSWindow?
    
    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        _importViewModel = StateObject(wrappedValue: ImportViewModel(database: appViewModel.database))
    }

    var body: some View {
        splitView
            .navigationTitle("AutoCore")
            .toolbar {
                toolbarContent
            }
            .onAppear {
                setupKeyboardShortcuts()
            }
            .background(WindowAccessor(window: $hostWindow))
            .modifier(AlertsAndSheetsModifier(
                isShowingImportPreview: $isShowingImportPreview,
                isShowingAddMotor: $isShowingAddMotor,
                isShowingExportSelection: $isShowingExportSelection,
                isShowingAlert: $isShowingAlert,
                isShowingCreateCategory: $isShowingCreateCategory,
                alertMessage: alertMessage,
                newCategoryName: $newCategoryName,
                importViewModel: importViewModel,
                appViewModel: appViewModel,
                onShowAlert: showAlert,
                onCreateCategory: createCategory,
                onExport: performExport
            ))
            .sheet(isPresented: $isShowingExportSettings) {
                ExportSettingsView(
                    isPresented: $isShowingExportSettings,
                    database: appViewModel.database,
                    currentFilters: ExportSettingsView.CurrentFilters(
                        searchText: appViewModel.searchText,
                        availabilityFilter: appViewModel.availabilityFilter,
                        brandID: appViewModel.selectedBrandID,
                        engineID: appViewModel.selectedEngineID
                    ),
                    onExport: { settings in
                        performExportWithSettings(settings)
                    }
                )
            }
            .onReceive(appViewModel.$errorMessage.compactMap { $0 }) { message in
                showAlert(message)
                Task { @MainActor in
                    appViewModel.errorMessage = nil
                }
            }
            .onReceive(importViewModel.$errorMessage.compactMap { $0 }) { message in
                showAlert(message)
                Task { @MainActor in
                    importViewModel.errorMessage = nil
                }
            }
            .onChange(of: appViewModel.selectedSection) { _, newValue in
                // Вызываем напрямую - onChange уже выполняется вне контекста рендера
                handleSectionChange(newValue)
            }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        CustomToolbar(
            availabilityFilter: appViewModel.availabilityFilter,
            searchText: appViewModel.searchText,
            onAvailabilityFilterChange: { newFilter in
                appViewModel.setAvailabilityFilter(newFilter)
            },
            onSearchTextChange: { newText in
                appViewModel.setSearchText(newText)
            },
            onImport: { openImportPanel() },
            onExport: { Task { @MainActor in exportExcel() } },
            onAdd: { isShowingAddMotor = true },
            onSell: selectedMotor != nil ? {
                if let motor = selectedMotor {
                    appViewModel.toggleSold(for: motor)
                }
            } : nil
        )
    }
    
    
    
    private func handleSectionChange(_ newValue: NavigationSection) {
        switch newValue {
        case .sold:
            appViewModel.refreshSoldMotors()
        case .specificCategory(let categoryID):
            appViewModel.refreshServiceRecords(categoryID: categoryID)
        default:
            break
        }
    }
    
    private var splitView: some View {
        NavigationSplitView {
            SidebarView(
                brands: appViewModel.brands,
                engines: appViewModel.engines,
                categories: appViewModel.specificCategories,
                selectedSection: appViewModel.selectedSection,
                selectedBrandID: appViewModel.selectedBrandID,
                selectedEngineID: appViewModel.selectedEngineID,
                onSectionChange: { section in
                    appViewModel.setSelectedSection(section)
                },
                onBrandChange: { brandID in
                    appViewModel.setSelectedBrandID(brandID)
                },
                onEngineChange: { engineID in
                    appViewModel.setSelectedEngineID(engineID)
                },
                onBrandAndEngineChange: { brandID, engineID in
                    appViewModel.setSelectedBrandAndEngine(brandID: brandID, engineID: engineID)
                },
                onClearFilters: {
                    appViewModel.clearAllFilters()
                },
                onCreateCategory: {
                    showCreateCategoryDialog()
                }
            )
        } content: {
            contentView
        } detail: {
            detailView
        }
    }
    
    private var contentView: some View {
        Group {
            switch appViewModel.selectedSection {
            case .sold:
                SoldMotorsView(
                    motors: appViewModel.soldMotors,
                    selectedMotorID: $appViewModel.selectedMotorID,
                    searchText: appViewModel.soldSearchText,
                    onSearchTextChange: { newText in
                        appViewModel.setSoldSearchText(newText)
                    },
                    isLoading: appViewModel.isLoading,
                    totalCount: appViewModel.totalSoldCount,
                    hasMorePages: appViewModel.hasMoreSoldPages,
                    onReturnToStock: { motor in
                        appViewModel.setSoldStatus(motorID: motor.id, sell: false)
                    },
                    onLoadMore: {
                        appViewModel.loadMoreSoldMotorsIfNeeded()
                    }
                )
            case .specificCategory(let categoryID):
                if let category = appViewModel.specificCategories.first(where: { $0.id == categoryID }) {
                    ServiceRecordsView(
                        records: [],
                        specificRecords: appViewModel.specificRecords,
                        searchText: appViewModel.serviceRecordsSearchText,
                        onSearchTextChange: { newText in
                            appViewModel.setServiceRecordsSearchText(newText)
                        },
                        isLoading: appViewModel.isLoading,
                        totalCount: appViewModel.totalServiceRecordsCount,
                        categoryName: category.name
                    )
                } else {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "Категория не найдена",
                        message: "Категория была удалена или не существует",
                        actionTitle: nil,
                        action: nil
                    )
                }
            default:
                MotorListView(
                    motors: appViewModel.filteredMotors,
                    selectedMotorID: $appViewModel.selectedMotorID,
                    searchText: appViewModel.searchText,
                    availabilityFilter: appViewModel.availabilityFilter,
                    isLoading: appViewModel.isLoading,
                    totalCount: appViewModel.filteredMotors.count,
                    hasMorePages: false,
                    onToggleSold: { motor in
                        appViewModel.toggleSold(for: motor)
                    },
                    onLoadMore: {
                        appViewModel.loadMoreMotorsIfNeeded()
                    },
                    onDuplicate: { motor in
                        duplicateMotor(motor)
                    },
                    onExportSelected: { motor in
                        exportSelectedMotor(motor)
                    },
                    onCellSave: { motorID, field, value in
                        appViewModel.updateMotorCell(motorID: motorID, field: field, value: value)
                    }
                )
            }
        }
    }
    
    private var detailView: some View {
        Group {
            if isInspectorVisible {
                MotorDetailView(
                    motor: selectedMotor,
                    isSold: appViewModel.selectedSection == .sold,
                    onSave: { motorID, configuration, notes, quantity, transmission, arrivalDate, soldDate in
                        appViewModel.updateMotorDetails(
                            motorID: motorID,
                            configuration: configuration,
                            notes: notes,
                            quantity: quantity,
                            transmission: transmission,
                            arrivalDate: arrivalDate,
                            soldDate: soldDate
                        )
                    },
                    onToggleSold: { motorID, sell in
                        appViewModel.setSoldStatus(motorID: motorID, sell: sell)
                    }
                )
            } else {
                ContentUnavailableView("Inspector скрыт", systemImage: "sidebar.right")
                    .frame(minWidth: 200)
            }
        }
    }
    
    private var selectedMotor: Motor? {
        if appViewModel.selectedSection == .sold {
            return appViewModel.soldMotors.first(where: { $0.id == appViewModel.selectedMotorID })
        } else {
            return appViewModel.filteredMotors.first(where: { $0.id == appViewModel.selectedMotorID })
        }
    }

    private func setupKeyboardShortcuts() {
        // Горячие клавиши обрабатываются через .keyboardShortcut в CustomToolbar
        // Дополнительные можно добавить здесь через NSEvent
    }

    @MainActor
    private func openImportPanel() {
        // КАНОНИЧЕСКИЙ способ для SwiftUI: используем окно из WindowAccessor
        guard let window = hostWindow else {
            assertionFailure("Нет окна для показа Open Panel. WindowAccessor должен быть установлен.")
            showAlert("Не удалось найти окно приложения")
            return
        }
        
        let panel = NSOpenPanel()
        panel.title = "Выберите Excel файл"
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")].compactMap { $0 }
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        
        // beginSheetModal - правильный способ для SwiftUI с привязкой к окну
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else {
                // Пользователь отменил - ничего не делаем
                return
            }
            
            // Обрабатываем выбранный файл на главном потоке
            Task { @MainActor in
                self.importViewModel.load(url: url)
                self.isShowingImportPreview = true
            }
        }
    }

    @MainActor
    private func exportExcel() {
        // Показываем окно настроек экспорта
        isShowingExportSettings = true
    }
    
    @MainActor
    private func performExportWithSettings(_ settings: ExportSettings) {
        // Показываем Save Panel после подтверждения настроек
        guard let window = hostWindow ?? NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first(where: { $0.isVisible && $0.isKeyWindow }) else {
            assertionFailure("Нет окна для показа Save Panel")
            showAlert("Не удалось найти окно приложения")
            return
        }
        
        Task { @MainActor in
            let panel = NSSavePanel()
            
            panel.title = "Экспорт Excel"
            panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")].compactMap { $0 }
            panel.nameFieldStringValue = "autocore.xlsx"
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else {
                    return
                }
                
                Task { @MainActor in
                    await self.handleExportWithSettings(url: url, settings: settings)
                }
            }
        }
    }
    
    @MainActor
    private func performExport(selectedSpecificSheetIDs: Set<Int64>?) {
        // КАНОНИЧЕСКИЙ способ для SwiftUI: используем окно из WindowAccessor или fallback
        guard let window = hostWindow ?? NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first(where: { $0.isVisible && $0.isKeyWindow }) else {
            assertionFailure("Нет окна для показа Save Panel. WindowAccessor должен быть установлен.")
            showAlert("Не удалось найти окно приложения")
            return
        }
        
        // Создаем панель на главном потоке
        Task { @MainActor in
            let panel = NSSavePanel()
            
            panel.title = "Экспорт Excel"
            panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")].compactMap { $0 }
            panel.nameFieldStringValue = "autocore.xlsx"
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            
            // beginSheetModal - правильный способ для SwiftUI с привязкой к окну
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else {
                    // Пользователь отменил - ничего не делаем
                    return
                }
                
                // Выполняем экспорт после выбора файла
                Task { @MainActor in
                    await self.handleExport(url: url, selectedSpecificSheetIDs: selectedSpecificSheetIDs)
                }
            }
        }
    }
    
    @MainActor
    private func handleExportWithSettings(url: URL, settings: ExportSettings) async {
        // Показываем индикатор загрузки
        appViewModel.isLoading = true
        
        // Захватываем значения до Task.detached
        let database = appViewModel.database
        let currentFilters = settings.respectCurrentFilters ? ExportSettingsView.CurrentFilters(
            searchText: appViewModel.searchText,
            availabilityFilter: appViewModel.availabilityFilter,
            brandID: appViewModel.selectedBrandID,
            engineID: appViewModel.selectedEngineID
        ) : nil
        
        do {
            // Выполняем экспорт в фоне с настройками
            let result = try await Task.detached(priority: .userInitiated) {
                try ExcelExportService().export(
                    database: database,
                    to: url,
                    settings: settings,
                    currentFilters: currentFilters
                )
            }.value
            
            // Показываем результат на главном потоке
            let message = """
            Экспорт завершён

            Листов: \(result.sheetsCount)
            Моторов: \(result.motorsCount)
            Проданных: \(result.soldMotorsCount)
            Специфичных листов: \(result.specificSheetsCount)

            Файл: \(url.path)
            """
            showAlert(message)
        } catch {
            showAlert("Ошибка экспорта: \(error.localizedDescription)")
        }
        
        appViewModel.isLoading = false
    }
    
    @MainActor
    private func handleExport(url: URL, selectedSpecificSheetIDs: Set<Int64>?) async {
        // Старый метод для обратной совместимости
        appViewModel.isLoading = true
        
        do {
            let allMotors = try await Task.detached(priority: .userInitiated) {
                try self.appViewModel.database.fetchMotors(
                    filter: DatabaseService.MotorFilter(availability: .all),
                    limit: nil,
                    offset: 0
                )
            }.value
            
            let engines = try await Task.detached(priority: .userInitiated) {
                try self.appViewModel.database.fetchEngines(brandID: nil)
            }.value
            
            if allMotors.isEmpty && engines.isEmpty {
                showAlert("Нет данных для экспорта")
                appViewModel.isLoading = false
                return
            }
            
            let result = try await Task.detached(priority: .userInitiated) {
                try ExcelExportService().export(
                    database: self.appViewModel.database,
                    to: url,
                    selectedSpecificSheetIDs: selectedSpecificSheetIDs
                )
            }.value
            
            let message = """
            Экспорт завершён

            Листов: \(result.sheetsCount)
            Моторов: \(result.motorsCount)
            Проданных: \(result.soldMotorsCount)
            Специфичных листов: \(result.specificSheetsCount)

            Файл: \(url.path)
            """
            showAlert(message)
        } catch {
            showAlert("Ошибка экспорта: \(error.localizedDescription)")
        }
        
        appViewModel.isLoading = false
    }
}
    private extension RootView {
    func showAlert(_ message: String) {
        alertMessage = message
        isShowingAlert = true
    }
    
    func showCreateCategoryDialog() {
        newCategoryName = ""
        isShowingCreateCategory = true
    }
    
    func createCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        Task { @MainActor in
            do {
                try await Task.detached(priority: .userInitiated) {
                    try self.appViewModel.database.executeInTransactionBlock {
                        try self.appViewModel.database.beginTransaction()
                        _ = try self.appViewModel.database.createSpecificCategoryUnlocked(name: trimmed)
                        try self.appViewModel.database.commitTransaction()
                    }
                }.value
                
                appViewModel.refreshAll()
                newCategoryName = ""
            } catch {
                showAlert("Ошибка создания категории: \(error.localizedDescription)")
            }
        }
    }
    
    func duplicateMotor(_ motor: Motor) {
        // Находим engine по motor.engineID
        guard let engine = appViewModel.engines.first(where: { $0.id == motor.engineID }) else {
            showAlert("Не удалось найти двигатель для дублирования")
            return
        }
        
        guard let brand = appViewModel.brands.first(where: { $0.id == engine.brandID }) else {
            showAlert("Не удалось найти бренд для дублирования")
            return
        }
        
        appViewModel.addManualMotor(
            brandName: brand.name,
            engineCode: engine.code,
            serialCode: motor.serialCode + " (копия)",
            configuration: motor.configuration,
            notes: motor.notes,
            quantity: motor.quantity,
            transmission: motor.transmission,
            arrivalDate: motor.arrivalDate,
            soldDate: nil // Дубликат всегда в наличии
        )
        
        showAlert("Мотор успешно продублирован")
    }
    
    func exportSelectedMotor(_ motor: Motor) {
        // Экспорт одного мотора в отдельный файл
        Task { @MainActor in
            guard let window = hostWindow ?? NSApplication.shared.keyWindow else {
                showAlert("Не удалось найти окно приложения")
                return
            }
            
            let panel = NSSavePanel()
            panel.title = "Экспорт мотора"
            panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")].compactMap { $0 }
            panel.nameFieldStringValue = "motor_\(motor.serialCode).xlsx"
            panel.canCreateDirectories = true
            
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { return }
                
                Task { @MainActor in
                    do {
                        // Создаем временный фильтр только для этого мотора
                        let exportService = ExcelExportService()
                        // Для экспорта одного мотора можно создать отдельный метод
                        // Пока просто показываем сообщение
                        showAlert("Экспорт одного мотора будет реализован в следующей версии")
                    }
                }
            }
        }
    }
}

// MARK: - WindowAccessor
// NSViewRepresentable для получения реального NSWindow из SwiftUI View
private struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            // Получаем реальное окно через view.window
            self.window = view.window
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Обновляем окно при изменении иерархии
        Task { @MainActor in
            self.window = nsView.window
        }
    }
}
