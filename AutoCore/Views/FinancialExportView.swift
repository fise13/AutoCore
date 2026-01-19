import SwiftUI

/// UI для настройки и выполнения экспорта финансовых операций
struct FinancialExportView: View {
    @Binding var isPresented: Bool
    let onExport: (FinancialExportConfig) -> Void
    
    @State private var config = FinancialExportConfig()
    @State private var selectedFormat: FinancialExportConfig.ExportFormat = .excel
    @State private var fromDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var toDate: Date = Date()
    @State private var useDateRange: Bool = false
    
    @State private var includeSales: Bool = true
    @State private var includeExpenses: Bool = true
    @State private var includeRefunds: Bool = true
    @State private var includeTransfers: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Формат экспорта
                Section("Формат") {
                    Picker("Формат", selection: $selectedFormat) {
                        Text("Excel (.xlsx)").tag(FinancialExportConfig.ExportFormat.excel)
                        Text("PDF (.pdf)").tag(FinancialExportConfig.ExportFormat.pdf)
                    }
                    .pickerStyle(.radioGroup)
                    .onChange(of: selectedFormat) { _, newValue in
                        config.format = newValue
                    }
                }
                
                // Период
                Section("Период") {
                    Toggle("Использовать диапазон дат", isOn: $useDateRange)
                    
                    if useDateRange {
                        DatePicker("С", selection: $fromDate, displayedComponents: .date)
                        DatePicker("По", selection: $toDate, displayedComponents: .date)
                    }
                }
                
                // Типы операций
                Section("Типы операций") {
                    Toggle("Продажи", isOn: $includeSales)
                    Toggle("Расходы", isOn: $includeExpenses)
                    Toggle("Возвраты", isOn: $includeRefunds)
                    Toggle("Переводы", isOn: $includeTransfers)
                }
                
                // Настройки Excel
                if selectedFormat == .excel {
                    Section("Настройки Excel") {
                        Toggle("Разбивать по листам", isOn: $config.splitBySheets)
                        Toggle("Добавить сводку", isOn: $config.includeSummary)
                    }
                }
                
                // Настройки PDF
                if selectedFormat == .pdf {
                    Section("Настройки PDF") {
                        Toggle("Добавить сводку", isOn: $config.includeSummary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Экспорт финансовых данных")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Экспортировать") {
                        prepareConfig()
                        onExport(config)
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                }
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            updateConfig()
        }
        .onChange(of: useDateRange) { _, _ in updateConfig() }
        .onChange(of: fromDate) { _, _ in updateConfig() }
        .onChange(of: toDate) { _, _ in updateConfig() }
        .onChange(of: includeSales) { _, _ in updateConfig() }
        .onChange(of: includeExpenses) { _, _ in updateConfig() }
        .onChange(of: includeRefunds) { _, _ in updateConfig() }
        .onChange(of: includeTransfers) { _, _ in updateConfig() }
    }
    
    private var isValid: Bool {
        var types: Set<FinancialOperationEntity.OperationType> = []
        if includeSales { types.insert(.sale) }
        if includeExpenses { types.insert(.expense) }
        if includeRefunds { types.insert(.refund) }
        if includeTransfers { types.insert(.transfer) }
        
        return !types.isEmpty && (!useDateRange || fromDate <= toDate)
    }
    
    private func updateConfig() {
        config.format = selectedFormat
        
        if useDateRange {
            config.dateRange = DateInterval(start: fromDate, end: toDate)
        } else {
            config.dateRange = nil
        }
        
        var types: Set<FinancialOperationEntity.OperationType> = []
        if includeSales { types.insert(.sale) }
        if includeExpenses { types.insert(.expense) }
        if includeRefunds { types.insert(.refund) }
        if includeTransfers { types.insert(.transfer) }
        config.includedOperationTypes = types
    }
    
    private func prepareConfig() {
        updateConfig()
    }
}
