import SwiftUI

struct AlertsAndSheetsModifier: ViewModifier {
    @Binding var isShowingImportPreview: Bool
    @Binding var isShowingAddMotor: Bool
    @Binding var isShowingExportSelection: Bool
    @Binding var isShowingAlert: Bool
    @Binding var isShowingCreateCategory: Bool
    let alertMessage: String
    @Binding var newCategoryName: String
    let importViewModel: ImportViewModel
    let appViewModel: AppViewModel
    let backupService: BackupService?
    let onShowAlert: (String) -> Void
    let onCreateCategory: () -> Void
    let onExport: (Set<Int64>?) -> Void
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isShowingImportPreview) {
                ImportWizardView(
                    viewModel: importViewModel,
                    existingBrands: appViewModel.brands,
                    onCommit: { _ in
                        Task { @MainActor in
                            do {
                                let imported = try await importViewModel.commitImport(database: appViewModel.database, backupService: backupService)
                                appViewModel.refreshAll()
                                onShowAlert("Импортировано моторов: \(imported)")
                                isShowingImportPreview = false
                            } catch {
                                onShowAlert("Ошибка сохранения: \(error.localizedDescription)")
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
                        appViewModel.setAvailabilityFilter(.sold)
                    }
                    isShowingAddMotor = false
                }
            }
            .alert("Сообщение", isPresented: $isShowingAlert) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .alert("Новая категория", isPresented: $isShowingCreateCategory) {
                TextField("Имя категории", text: $newCategoryName)
                Button("Отмена", role: .cancel) {
                    newCategoryName = ""
                }
                Button("Создать") {
                    onCreateCategory()
                }
                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Введите имя новой специфичной категории")
            }
            .sheet(isPresented: $isShowingExportSelection) {
                ExportSelectionView(
                    isPresented: $isShowingExportSelection,
                    specificCategories: appViewModel.specificCategories
                ) { selectedCategoryIDs in
                    onExport(selectedCategoryIDs)
                }
            }
    }
}
