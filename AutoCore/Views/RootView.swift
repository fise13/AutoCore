import SwiftUI
import UniformTypeIdentifiers
import AppKit
import Combine

struct RootView: View {
    @ObservedObject var appViewModel: AppViewModel
    @StateObject private var importViewModel: ImportViewModel

    @State private var isShowingImportPicker = false
    @State private var isShowingImportPreview = false
    @State private var isShowingAddMotor = false
    @State private var isShowingExportSelection = false
    @State private var alertMessage = ""
    @State private var isShowingAlert = false
    @State private var specificSheetsForExport: [DatabaseService.SpecificSheet] = []
    
    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        _importViewModel = StateObject(wrappedValue: ImportViewModel(database: appViewModel.database))
    }

    var body: some View {
        splitView
            .navigationTitle("AutoCore")
            .toolbar { toolbarContent }
            .sheet(isPresented: $isShowingImportPreview) {
                ImportWizardView(
                    viewModel: importViewModel,
                    existingBrands: appViewModel.brands,
                    onCommit: {
                        Task { @MainActor in
                            do {
                                let imported = try await importViewModel.commitImport(database: appViewModel.database)
                                appViewModel.refreshAll()
                                showAlert("Импортировано моторов: \(imported)")
                                isShowingImportPreview = false
                            } catch {
                                showAlert("Ошибка сохранения: \(error.localizedDescription)")
                            }
                        }
                    },
                    onCancel: {
                        isShowingImportPreview = false
                    }
                )
            }
            .sheet(isPresented: $isShowingAddMotor) {
                AddMotorView(
                    brands: appViewModel.brands,
                    engines: appViewModel.engines
                ) { brand, engine, serial, configuration, notes, quantity, transmission, arrivalDate, soldDate in
                    appViewModel.addManualMotor(
                        brandName: brand,
                        engineCode: engine,
                        serialCode: serial,
                        configuration: configuration,
                        notes: notes,
                        quantity: quantity,
                        transmission: transmission,
                        arrivalDate: arrivalDate,
                        soldDate: soldDate
                    )
                    if soldDate != nil {
                        appViewModel.availabilityFilter = .sold
                    }
                    isShowingAddMotor = false
                }
            }
            .alert("Сообщение", isPresented: $isShowingAlert) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $isShowingExportSelection) {
                ExportSelectionView(
                    isPresented: $isShowingExportSelection,
                    specificSheets: specificSheetsForExport
                ) { selectedSheetIDs in
                    performExport(selectedSpecificSheetIDs: selectedSheetIDs)
                }
            }
            .onReceive(appViewModel.$errorMessage.compactMap { $0 }) { message in
                showAlert(message)
                DispatchQueue.main.async {
                    appViewModel.errorMessage = nil
                }
            }
            .onReceive(importViewModel.$errorMessage.compactMap { $0 }) { message in
                showAlert(message)
                DispatchQueue.main.async {
                    importViewModel.errorMessage = nil
                }
            }
            .onChange(of: appViewModel.selectedSection) { _, newValue in
                switch newValue {
                case .sold:
                    appViewModel.refreshSoldMotors()
                case .repair, .afterDan, .afterTolya, .storage, .other:
                    appViewModel.refreshServiceRecords(category: newValue.categoryName ?? "")
                default:
                    // Для обычного списка фильтрация происходит через computed property
                    // Обновляем allMotors только если нужно
                    break
                }
            }
    }

    private var splitView: some View {
        NavigationSplitView {
            SidebarView(
                brands: appViewModel.brands,
                engines: appViewModel.engines,
                selectedSection: $appViewModel.selectedSection,
                selectedBrandID: $appViewModel.selectedBrandID,
                selectedEngineID: $appViewModel.selectedEngineID
            )
        } content: {
            switch appViewModel.selectedSection {
                case .sold:
                    SoldMotorsView(
                        motors: appViewModel.soldMotors,
                        selectedMotorID: $appViewModel.selectedMotorID,
                        searchText: $appViewModel.soldSearchText,
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
                case .repair, .afterDan, .afterTolya, .storage, .other:
                    ServiceRecordsView(
                        records: appViewModel.serviceRecords,
                        specificRecords: appViewModel.specificRecords,
                        searchText: $appViewModel.serviceRecordsSearchText,
                        isLoading: appViewModel.isLoading,
                        totalCount: appViewModel.totalServiceRecordsCount,
                        categoryName: appViewModel.selectedSection.categoryName ?? ""
                    )
                default:
                    MotorListView(
                        motors: appViewModel.filteredMotors,
                        selectedMotorID: $appViewModel.selectedMotorID,
                        searchText: $appViewModel.searchText,
                        availabilityFilter: $appViewModel.availabilityFilter,
                        isLoading: appViewModel.isLoading,
                        totalCount: appViewModel.filteredMotors.count,
                        hasMorePages: false,
                        onToggleSold: { motor in
                            appViewModel.toggleSold(for: motor)
                        },
                        onLoadMore: {
                            appViewModel.loadMoreMotorsIfNeeded()
                        }
                    )
                }
        } detail: {
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
        }
    }

    private var selectedMotor: Motor? {
        // Ищем в filteredMotors для обычного списка, или в soldMotors для экрана "Проданные"
        if appViewModel.selectedSection == .sold {
            return appViewModel.soldMotors.first(where: { $0.id == appViewModel.selectedMotorID })
        } else {
            return appViewModel.filteredMotors.first(where: { $0.id == appViewModel.selectedMotorID })
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Импорт Excel") {
                openImportPanel()
            }
            Button("Экспорт Excel") {
                exportExcel()
            }
            Button("Добавить мотор") {
                isShowingAddMotor = true
            }
        }
    }

    @MainActor
    private func openImportPanel() {
        // КАНОНИЧЕСКИЙ способ для SwiftUI: используем begin с completion handler
        let panel = NSOpenPanel()
        panel.title = "Выберите Excel файл"
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")].compactMap { $0 }
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        
        // begin - правильный способ для SwiftUI, не блокирует поток
        panel.begin { response in
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

    private func exportExcel() {
        // Упрощенный экспорт - экспортируем все автоматически без диалога выбора
        performExport(selectedSpecificSheetIDs: nil)
    }
    
    @MainActor
    private func performExport(selectedSpecificSheetIDs: Set<Int64>?) {
        // КАНОНИЧЕСКИЙ способ для SwiftUI: используем begin с completion handler
        // Это асинхронный, неблокирующий вызов
        let panel = NSSavePanel()
        panel.title = "Экспорт Excel"
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")].compactMap { $0 }
        panel.nameFieldStringValue = "autocore.xlsx"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        
        // begin - правильный способ для SwiftUI, не блокирует поток
        panel.begin { response in
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
    
    @MainActor
    private func handleExport(url: URL, selectedSpecificSheetIDs: Set<Int64>?) async {
        // Показываем индикатор загрузки через appViewModel
        appViewModel.isLoading = true
        
        do {
            // Проверяем, есть ли данные (выполняем в фоне)
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
            
            // Выполняем экспорт в фоне (это может занять время)
            let result = try await Task.detached(priority: .userInitiated) {
                try ExcelExportService().export(
                    database: self.appViewModel.database,
                    to: url,
                    selectedSpecificSheetIDs: selectedSpecificSheetIDs
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
}
private extension RootView {
    func showAlert(_ message: String) {
        alertMessage = message
        isShowingAlert = true
    }
}
