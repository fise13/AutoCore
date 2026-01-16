import SwiftUI

// MARK: - Step 3: Column Mapping

struct ImportStep3_ColumnMappingView: View {
    @ObservedObject var viewModel: ImportViewModel
    let existingBrands: [Brand]
    
    var body: some View {
        VStack(spacing: 0) {
            if let currentConfig = viewModel.getCurrentSheetConfig() {
                ColumnMappingSheetView(
                    viewModel: viewModel,
                    config: currentConfig,
                    existingBrands: existingBrands
                )
            } else {
                Text("Все листы настроены")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct ColumnMappingSheetView: View {
    @ObservedObject var viewModel: ImportViewModel
    let config: SheetImportConfig
    let existingBrands: [Brand]
    
    @State private var columnMapping: SheetColumnMapping
    @State private var localConfig: SheetImportConfig
    
    init(viewModel: ImportViewModel, config: SheetImportConfig, existingBrands: [Brand]) {
        self.viewModel = viewModel
        self.config = config
        self.existingBrands = existingBrands
        
        // Инициализируем маппинг из viewModel или создаем новый
        let initialMapping = viewModel.columnMappings[config.id] ?? SheetColumnMapping(
            sheetID: config.id,
            columnMappings: [],
            headerRowIndex: nil
        )
        _columnMapping = State(initialValue: initialMapping)
        _localConfig = State(initialValue: config)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок с информацией о текущем листе
            headerView
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Настройка колонок (показываем только если не "пропустить")
                    if config.importType != .skip {
                        columnMappingSection
                    } else {
                        Text("Этот лист будет пропущен при импорте")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Настройка колонок")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Лист: \(config.sheetName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let nextSheet = viewModel.getNextSheetToConfigure() {
                    Text("Следующий: \(nextSheet.sheetName)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Последний лист")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            if let nextSheet = viewModel.getNextSheetToConfigure() {
                Button("Следующий лист") {
                    saveAndMoveNext()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
    
    private var columnMappingSection: some View {
        GroupBox(config.importType == .engines ? "Назначение колонок" : "Поля данных") {
            VStack(alignment: .leading, spacing: 12) {
                Text(config.importType == .engines
                     ? "Для каждой колонки выберите, какое поле она содержит"
                     : "Для каждой колонки введите имя поля или оставьте пустым для игнорирования")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(columnMapping.columnMappings) { mapping in
                    ColumnMappingRow(
                        mapping: mapping,
                        isEngineSheet: config.importType == .engines,
                        onUpdate: { updatedMapping in
                            if let index = columnMapping.columnMappings.firstIndex(where: { $0.id == updatedMapping.id }) {
                                columnMapping.columnMappings[index] = updatedMapping
                                viewModel.updateColumnMapping(for: config.id, mapping: columnMapping)
                            }
                        }
                    )
                }
            }
        }
    }
    
    private func saveAndMoveNext() {
        viewModel.updateColumnMapping(for: config.id, mapping: columnMapping)
        viewModel.updateSheetConfig(localConfig)
        viewModel.moveToNextSheet()
    }
}

private struct ColumnMappingRow: View {
    let mapping: ColumnMapping
    let isEngineSheet: Bool
    let onUpdate: (ColumnMapping) -> Void
    
    @State private var selectedField: EngineFieldMapping?
    @State private var customFieldName: String
    
    init(mapping: ColumnMapping, isEngineSheet: Bool, onUpdate: @escaping (ColumnMapping) -> Void) {
        self.mapping = mapping
        self.isEngineSheet = isEngineSheet
        self.onUpdate = onUpdate
        _selectedField = State(initialValue: mapping.engineFieldMapping)
        _customFieldName = State(initialValue: mapping.customFieldName ?? "")
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Информация о колонке
            VStack(alignment: .leading, spacing: 4) {
                Text(mapping.displayName)
                    .font(.headline)
                    .frame(width: 150, alignment: .leading)
                
                if !mapping.previewValues.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(mapping.previewValues.prefix(3).enumerated()), id: \.offset) { _, value in
                            Text(value)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(width: 150, alignment: .leading)
                }
            }
            
            Divider()
            
            // Настройка назначения
            if isEngineSheet {
                // Для основных листов - выбор из фиксированного списка
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Назначение", selection: Binding(
                        get: { selectedField },
                        set: { newField in
                            selectedField = newField
                            var updated = mapping
                            updated.engineFieldMapping = newField
                            updated.customFieldName = nil
                            onUpdate(updated)
                        }
                    )) {
                        Text("Не назначено").tag(EngineFieldMapping?.none)
                        ForEach(EngineFieldMapping.allCases.filter { $0 != .ignore }) { field in
                            HStack {
                                Text(field.displayName)
                                if field.isRequired {
                                    Text("*")
                                        .foregroundStyle(.red)
                                }
                            }
                            .tag(EngineFieldMapping?.some(field))
                        }
                        Text("Игнорировать").tag(EngineFieldMapping?.some(.ignore))
                    }
                    .frame(width: 250)
                    
                    if let field = selectedField, field.isRequired {
                        Text("Обязательное поле")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            } else {
                // Для специфичных листов - ввод имени поля
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Имя поля (или оставьте пустым)", text: Binding(
                        get: { customFieldName },
                        set: { newValue in
                            customFieldName = newValue
                            var updated = mapping
                            updated.customFieldName = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newValue
                            updated.engineFieldMapping = nil
                            onUpdate(updated)
                        }
                    ))
                    .frame(width: 250)
                    
                    Text("Введите имя поля, которое будет использовано для сохранения данных")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(8)
    }
}
