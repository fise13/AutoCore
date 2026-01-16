import SwiftUI

struct ImportWizardView: View {
    @ObservedObject var viewModel: ImportViewModel
    let existingBrands: [Brand]
    let onCommit: (BackupService?) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            footerView
        }
        .frame(minWidth: 1000, minHeight: 700)
        .onAppear {
            viewModel.loadExistingBrands()
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Импорт Excel")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .analyze:
            ImportStep1_SheetAnalysisView(viewModel: viewModel)
        case .selectType:
            ImportStep2_SheetTypeSelectionView(viewModel: viewModel, existingBrands: existingBrands)
        case .preview:
            ImportStep4_PreviewView(viewModel: viewModel, onCommit: { backupService in
                onCommit(backupService)
            })
        }
    }
    
    private var footerView: some View {
        HStack {
            Button("Отмена") {
                onCancel()
            }
            
            Spacer()
            
            if viewModel.currentStep != .analyze {
                Button("Назад") {
                    viewModel.previousStep()
                }
            }
            
            if viewModel.currentStep == .preview {
                if viewModel.isImporting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        if let progress = viewModel.importProgress {
                            Text("Импорт: \(progress.current) из \(progress.total)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Импорт...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Button("Импортировать") {
                        onCommit(nil) // BackupService будет передан из AlertsAndSheetsModifier
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Button("Далее") {
                    viewModel.nextStep()
                }
                .disabled(!viewModel.canProceedToNextStep())
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// MARK: - Step 1: Sheet Analysis

struct ImportStep1_SheetAnalysisView: View {
    @ObservedObject var viewModel: ImportViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Анализ Excel-файла")
                    .font(.title3)
                    .padding(.horizontal)
                
                Text("Найдено листов: \(viewModel.sheetConfigs.count)")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else {
                    ForEach(viewModel.sheetConfigs) { config in
                        SheetAnalysisRow(config: config)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

private struct SheetAnalysisRow: View {
    let config: SheetImportConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(config.sheetName)
                    .font(.headline)
                Spacer()
                Text("\(config.rowCount) строк")
                    .foregroundStyle(.secondary)
            }
            
            if !config.previewRows.isEmpty {
                Text("Превью первых строк:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(Array(config.previewRows.prefix(3).enumerated()), id: \.offset) { _, row in
                    Text(row.prefix(5).joined(separator: " | "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(8)
    }
}


// MARK: - Step 3: Engine Configuration

struct ImportStep3_EngineConfigView: View {
    @ObservedObject var viewModel: ImportViewModel
    let existingBrands: [Brand]
    
    var engineSheets: [SheetImportConfig] {
        viewModel.sheetConfigs.filter { $0.importType == .engines }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Настройка листов с двигателями")
                    .font(.title3)
                    .padding(.horizontal)
                
                Text("Укажите бренд и тип двигателя для каждого листа")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                ForEach(engineSheets) { config in
                    EngineConfigRow(
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

private struct EngineConfigRow: View {
    let config: SheetImportConfig
    let existingBrands: [Brand]
    let onUpdate: (SheetImportConfig) -> Void
    
    @State private var localConfig: SheetImportConfig
    
    init(config: SheetImportConfig, existingBrands: [Brand], onUpdate: @escaping (SheetImportConfig) -> Void) {
        self.config = config
        self.existingBrands = existingBrands
        self.onUpdate = onUpdate
        _localConfig = State(initialValue: config)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(config.sheetName)
                .font(.headline)
            
            GroupBox("Бренд") {
                Picker("Выберите бренд", selection: Binding(
                    get: { localConfig.selectedBrandID },
                    set: { newID in
                        localConfig.selectedBrandID = newID
                        localConfig.customBrand = ""
                        onUpdate(localConfig)
                    }
                )) {
                    Text("Выберите из списка").tag(Int64?.none)
                    ForEach(existingBrands) { brand in
                        Text(brand.name).tag(Int64?.some(brand.id))
                    }
                }
                
                if localConfig.selectedBrandID == nil {
                    if !localConfig.customBrand.isEmpty {
                        HStack {
                            Text("Автоматически определено: \(localConfig.customBrand)")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Spacer()
                            Button("Очистить") {
                                localConfig.customBrand = ""
                                onUpdate(localConfig)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                    
                    TextField("Или введите новый бренд вручную", text: Binding(
                        get: { localConfig.customBrand },
                        set: { newValue in
                            localConfig.customBrand = newValue
                            onUpdate(localConfig)
                        }
                    ))
                }
            }
            
            GroupBox("Код двигателя") {
                Text("Имя листа: \(config.sheetName)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                
                if !localConfig.customEngineCode.isEmpty {
                    HStack {
                        Text("Автоматически определено: \(localConfig.customEngineCode)")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Spacer()
                        Button("Очистить") {
                            localConfig.customEngineCode = ""
                            onUpdate(localConfig)
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
                
                TextField("Или введите код двигателя вручную", text: Binding(
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
}

// MARK: - Step 4: Specific Sheet Configuration

struct ImportStep4_SpecificConfigView: View {
    @ObservedObject var viewModel: ImportViewModel
    
    var specificSheets: [SheetImportConfig] {
        viewModel.sheetConfigs.filter { $0.importType == .specific }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Настройка специфичных листов")
                    .font(.title3)
                    .padding(.horizontal)
                
                Text("Выберите категорию для каждого листа")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                ForEach(specificSheets) { config in
                    SpecificConfigRow(
                        config: config,
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

private struct SpecificConfigRow: View {
    let config: SheetImportConfig
    let onUpdate: (SheetImportConfig) -> Void
    
    @State private var localConfig: SheetImportConfig
    
    init(config: SheetImportConfig, onUpdate: @escaping (SheetImportConfig) -> Void) {
        self.config = config
        self.onUpdate = onUpdate
        _localConfig = State(initialValue: config)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(config.sheetName)
                .font(.headline)
            
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(8)
    }
}

// MARK: - Step 4: Preview

struct ImportStep4_PreviewView: View {
    @ObservedObject var viewModel: ImportViewModel
    let onCommit: (BackupService?) -> Void
    
    var summary: ImportPreviewSummary {
        viewModel.buildPreviewSummary()
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Предпросмотр импорта")
                    .font(.title3)
                    .padding(.horizontal)
                
                GroupBox("Итоговая статистика") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Моторов будет импортировано: \(summary.totalMotors)", systemImage: "engine.combustion")
                        Label("Новых брендов: \(summary.newBrands.count)", systemImage: "tag")
                        Label("Новых двигателей: \(summary.newEngines.count)", systemImage: "gearshape")
                        Label("Пропущено листов: \(summary.skippedSheets.count)", systemImage: "xmark.circle")
                        Label("Специфичных листов: \(summary.specificSheets.count)", systemImage: "doc.text")
                    }
                    .padding(8)
                }
                .padding(.horizontal)
                
                // Показываем preview данных для каждого листа
                ForEach(viewModel.sheetConfigs.filter { $0.importType != .skip }) { config in
                    PreviewSheetView(viewModel: viewModel, config: config)
                        .padding(.horizontal)
                }
                
                if !summary.newBrands.isEmpty {
                    GroupBox("Новые бренды") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(summary.newBrands, id: \.self) { brand in
                                Text("• \(brand)")
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)
                }
                
                if !summary.newEngines.isEmpty {
                    GroupBox("Новые двигатели") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(summary.newEngines.enumerated()), id: \.offset) { index, engine in
                                Text("• \(engine.brand) — \(engine.code)")
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)
                }
                
                if !summary.skippedSheets.isEmpty {
                    GroupBox("Пропущенные листы") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(summary.skippedSheets, id: \.self) { sheet in
                                Text("• \(sheet)")
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)
                }
                
                if !summary.specificSheets.isEmpty {
                    GroupBox("Специфичные листы") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(summary.specificSheets, id: \.name) { sheet in
                                Text("• \(sheet.name) — \(sheet.categoryName)")
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

private struct PreviewSheetView: View {
    @ObservedObject var viewModel: ImportViewModel
    let config: SheetImportConfig
    
    var body: some View {
        GroupBox("Лист: \(config.sheetName)") {
            if config.importType == .engines {
                if let sheet = viewModel.getSheetData(for: config),
                   let mapping = viewModel.columnMappings[config.id] {
                    let rows = viewModel.buildEngineRows(for: sheet, mapping: mapping)
                    PreviewEngineTable(rows: Array(rows.prefix(10)))
                } else {
                    Text("Нет данных для предпросмотра")
                        .foregroundStyle(.secondary)
                }
            } else if config.importType == .specific {
                if let sheet = viewModel.getSheetData(for: config),
                   let mapping = viewModel.columnMappings[config.id] {
                    let rows = viewModel.buildSpecificRows(for: sheet, mapping: mapping)
                    PreviewSpecificTable(rows: Array(rows.prefix(10)))
                } else {
                    Text("Нет данных для предпросмотра")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct PreviewEngineTable: View {
    let rows: [ImportRow]
    
    var body: some View {
        Table(rows) {
            TableColumn("Номер двигателя") { row in
                Text(row.serialCode)
            }
            TableColumn("Комплектация") { row in
                Text(row.configuration)
            }
            TableColumn("Особые отметки") { row in
                Text(row.notes)
            }
            TableColumn("Кол-во") { row in
                Text("\(row.quantity)")
            }
            TableColumn("Коробка") { row in
                Text(row.transmission)
            }
            TableColumn("Дата прихода") { row in
                Text(formatDate(row.arrivalDate))
            }
            TableColumn("Дата продажи") { row in
                Text(formatDate(row.soldDate))
            }
        }
        .frame(height: 200)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

private struct PreviewSpecificTable: View {
    let rows: [[String: String]]
    
    private var allKeys: [String] {
        var keysSet = Set<String>()
        for row in rows {
            keysSet.formUnion(row.keys)
        }
        return Array(keysSet).sorted()
    }
    
    var body: some View {
        if rows.isEmpty {
            Text("Нет данных")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Поля: \(allKeys.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(rows.prefix(10).enumerated()), id: \.offset) { index, row in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Строка \(index + 1):")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                ForEach(allKeys, id: \.self) { key in
                                    HStack {
                                        Text("\(key):")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(row[key] ?? "")
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding(4)
                            .background(.regularMaterial)
                            .cornerRadius(4)
                        }
                    }
                }
                .frame(height: 200)
            }
        }
    }
}

private struct PreviewRow: Identifiable {
    let id: Int
    let data: [String: String]
}

