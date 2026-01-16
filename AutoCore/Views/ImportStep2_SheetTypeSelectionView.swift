import SwiftUI

// MARK: - Step 2: Sheet Type Selection

struct ImportStep2_SheetTypeSelectionView: View {
    @ObservedObject var viewModel: ImportViewModel
    let existingBrands: [Brand]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Выберите тип для каждого листа")
                    .font(.title3)
                    .padding(.horizontal)
                
                Text("Для каждого листа выберите тип. Основные листы (двигатели) автоматически определяют бренд и код двигателя из названия.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                ForEach(viewModel.sheetConfigs) { config in
                    SheetTypeSelectionRow(
                        viewModel: viewModel,
                        config: config,
                        existingBrands: existingBrands,
                        onUpdate: { newConfig in
                            viewModel.updateSheetConfig(newConfig)
                        }
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

private struct SheetTypeSelectionRow: View {
    @ObservedObject var viewModel: ImportViewModel
    let config: SheetImportConfig
    let existingBrands: [Brand]
    let onUpdate: (SheetImportConfig) -> Void
    
    @State private var localConfig: SheetImportConfig
    
    init(viewModel: ImportViewModel, config: SheetImportConfig, existingBrands: [Brand], onUpdate: @escaping (SheetImportConfig) -> Void) {
        self.viewModel = viewModel
        self.config = config
        self.existingBrands = existingBrands
        self.onUpdate = onUpdate
        _localConfig = State(initialValue: config)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(config.sheetName)
                .font(.headline)
            
            Picker("Тип листа", selection: Binding(
                get: { localConfig.importType },
                set: { newType in
                    localConfig.importType = newType
                    // При смене типа сбрасываем настройки
                    if newType == .engines {
                        localConfig.specificCategory = .repair
                        localConfig.customCategoryName = ""
                    } else if newType == .specific {
                        // Для специфичных листов сбрасываем настройки бренда/двигателя
                        localConfig.selectedBrandID = nil
                        localConfig.customBrand = ""
                        localConfig.customEngineCode = ""
                    }
                    onUpdate(localConfig)
                    // Обновляем автоматический маппинг колонок при смене типа
                    viewModel.updateColumnMappingForTypeChange(sheetID: config.id, importType: newType)
                }
            )) {
                Text("Основной (двигатели)").tag(SheetImportType.engines)
                Text("Специфичный (ремонт, после Дэна и т.п.)").tag(SheetImportType.specific)
                Text("Пропустить").tag(SheetImportType.skip)
            }
            .pickerStyle(.radioGroup)
            
            // Показываем автоматически определенные значения для основных листов
            if localConfig.importType == .engines {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Автоматически определено из названия листа:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let brand = localConfig.effectiveBrand, !brand.isEmpty {
                        HStack {
                            Text("Бренд: \(brand)")
                                .foregroundStyle(.green)
                            Spacer()
                            Button("Очистить") {
                                localConfig.customBrand = ""
                                onUpdate(localConfig)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                    
                    if let engineCode = localConfig.effectiveEngineCode, !engineCode.isEmpty {
                        HStack {
                            Text("Код двигателя: \(engineCode)")
                                .foregroundStyle(.green)
                            Spacer()
                            Button("Очистить") {
                                localConfig.customEngineCode = ""
                                onUpdate(localConfig)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                    
                    // Показываем возможность выбрать бренд из списка или ввести новый
                    GroupBox("Бренд") {
                        Picker("Выберите бренд", selection: Binding(
                            get: { localConfig.selectedBrandID },
                            set: { newID in
                                localConfig.selectedBrandID = newID
                                if newID != nil {
                                    localConfig.customBrand = ""
                                }
                                onUpdate(localConfig)
                            }
                        )) {
                            Text("Выберите из списка").tag(Int64?.none)
                            ForEach(existingBrands) { brand in
                                Text(brand.name).tag(Int64?.some(brand.id))
                            }
                        }
                        
                        if localConfig.selectedBrandID == nil {
                            TextField("Или введите новый бренд", text: Binding(
                                get: { localConfig.customBrand },
                                set: { newValue in
                                    localConfig.customBrand = newValue
                                    onUpdate(localConfig)
                                }
                            ))
                        }
                    }
                    
                    GroupBox("Код двигателя") {
                        TextField("Код двигателя", text: Binding(
                            get: { localConfig.customEngineCode },
                            set: { newValue in
                                localConfig.customEngineCode = newValue
                                onUpdate(localConfig)
                            }
                        ))
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(8)
            }
            
            // Для специфичных листов - выбор категории
            if localConfig.importType == .specific {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Категория")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Picker("Категория", selection: Binding(
                        get: { localConfig.specificCategory },
                        set: { newCategory in
                            localConfig.specificCategory = newCategory
                            if newCategory != .other {
                                localConfig.customCategoryName = ""
                            }
                            onUpdate(localConfig)
                        }
                    )) {
                        ForEach(SpecificSheetCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    
                    if localConfig.specificCategory == .other {
                        TextField("Введите название категории", text: Binding(
                            get: { localConfig.customCategoryName },
                            set: { newValue in
                                localConfig.customCategoryName = newValue
                                onUpdate(localConfig)
                            }
                        ))
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(8)
    }
}
