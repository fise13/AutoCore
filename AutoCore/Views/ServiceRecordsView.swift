import SwiftUI
import Combine

#if os(macOS)

struct ServiceRecordsView: View {
    let records: [ServiceRecord]
    let specificRecords: [DatabaseService.SpecificRecord]
    let searchText: String
    let onSearchTextChange: (String) -> Void
    let isLoading: Bool
    let totalCount: Int
    let categoryName: String
    
    // Callback для обновления ячеек
    let onCellSave: ((Int64, String, String) -> Void)?
    let onDeleteRecord: ((Int64) -> Void)?
    
    @StateObject private var editViewModel = InlineEditViewModel()
    @StateObject private var tableViewModel = ServiceRecordsTableViewModel()
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            if tableViewModel.allRecords.isEmpty && !isLoading {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: totalCount == 0 ? "Специфичных данных пока нет" : "Ничего не найдено",
                    message: totalCount == 0
                        ? "Они появятся после импорта или добавления"
                        : "Попробуйте изменить запрос",
                    actionTitle: nil,
                    action: nil
                )
            } else {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Создаем динамическую таблицу с колонками на основе полей
                if !tableViewModel.allFieldNames.isEmpty {
                    // Для специфичных записей - динамические колонки с редактированием
                    editableDynamicTable
                } else {
                    // Для старых service_records - стандартная таблица
                    legacyTable
                }
            }
        }
        .background(DSColors.background)
        .searchable(text: Binding(
            get: { searchText },
            set: { newValue in
                onSearchTextChange(newValue)
            }
        ), prompt: "Поиск по номеру двигателя, данным, листу")
        .onAppear {
            tableViewModel.rebuild(records: records, specificRecords: specificRecords)
        }
        .onChange(of: records) { _, _ in
            tableViewModel.rebuild(records: records, specificRecords: specificRecords)
        }
        .onChange(of: specificRecords) { _, _ in
            tableViewModel.rebuild(records: records, specificRecords: specificRecords)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
    
    // Редактируемая динамическая таблица - упрощенная версия без ForEach
    @ViewBuilder
    private var editableDynamicTable: some View {
        let fieldsToShow = Array(tableViewModel.allFieldNames.prefix(5))
        
        Table(tableViewModel.allRecords) {
            TableColumn("Номер двигателя") { item in
                makeEditableCell(item: item, fieldKey: "НОМЕР ДВИГАТЕЛЯ", value: item.serialCode, field: .serialCode)
            }
            .width(min: 150)
            
            TableColumn("Лист") { item in
                makeEditableCell(item: item, fieldKey: "_CATEGORY_NAME", value: item.sheetName, field: .configuration)
            }
            .width(min: 120)
            
            // Фиксированные динамические колонки (до 5 штук) - оптимизировано для производительности
            if fieldsToShow.count > 0 {
                let fieldKey0 = fieldsToShow[0]
                TableColumn(fieldKey0) { item in
                    let fieldValue = item.data[fieldKey0] ?? ""
                    makeEditableCell(item: item, fieldKey: fieldKey0, value: fieldValue, field: .notes)
                }
                .width(min: 120)
            }
            
            if fieldsToShow.count > 1 {
                let fieldKey1 = fieldsToShow[1]
                TableColumn(fieldKey1) { item in
                    let fieldValue = item.data[fieldKey1] ?? ""
                    makeEditableCell(item: item, fieldKey: fieldKey1, value: fieldValue, field: .notes)
                }
                .width(min: 120)
            }
            
            if fieldsToShow.count > 2 {
                let fieldKey2 = fieldsToShow[2]
                TableColumn(fieldKey2) { item in
                    let fieldValue = item.data[fieldKey2] ?? ""
                    makeEditableCell(item: item, fieldKey: fieldKey2, value: fieldValue, field: .notes)
                }
                .width(min: 120)
            }
            
            if fieldsToShow.count > 3 {
                let fieldKey3 = fieldsToShow[3]
                TableColumn(fieldKey3) { item in
                    let fieldValue = item.data[fieldKey3] ?? ""
                    makeEditableCell(item: item, fieldKey: fieldKey3, value: fieldValue, field: .notes)
                }
                .width(min: 120)
            }
            
            if fieldsToShow.count > 4 {
                let fieldKey4 = fieldsToShow[4]
                TableColumn(fieldKey4) { item in
                    let fieldValue = item.data[fieldKey4] ?? ""
                    makeEditableCell(item: item, fieldKey: fieldKey4, value: fieldValue, field: .notes)
                }
                .width(min: 120)
            }
            
            TableColumn("Дата") { item in
                Text(formatDate(item.date))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            }
            .width(min: 100)
        }
    }
    
    // Helper для создания редактируемой ячейки
    @ViewBuilder
    private func makeEditableCell(item: RecordDisplayItem, fieldKey: String, value: String, field: EditableCellState.EditableField) -> some View {
        EditableSpecificRecordCell(
            recordID: item.id,
            fieldKey: fieldKey,
            value: value,
            editingCell: editViewModel.editingCell,
            selectedCell: editViewModel.selectedCell,
            onSave: { newValue in
                onCellSave?(item.id, fieldKey, newValue)
            },
            onStartEditing: {
                editViewModel.startEditing(motorID: item.id, field: field, currentValue: value)
            },
            onSelectCell: {
                editViewModel.selectCell(motorID: item.id, field: field)
            },
            onCancelEditing: {
                editViewModel.cancelEditing()
            }
        )
        .contextMenu {
            if let onDeleteRecord {
                Button(role: .destructive) {
                    onDeleteRecord(item.id)
                } label: {
                    Label("Удалить запись", systemImage: "trash")
                }
            }
        }
    }
    
    // Стандартная таблица для старых service_records
    @ViewBuilder
    private var legacyTable: some View {
        Table(tableViewModel.allRecords) {
            TableColumn("Номер двигателя") { item in
                Text(item.serialCode)
                    .contextMenu {
                        if let onDeleteRecord {
                            Button(role: .destructive) {
                                onDeleteRecord(item.id)
                            } label: {
                                Label("Удалить запись", systemImage: "trash")
                            }
                        }
                    }
            }
            TableColumn("Лист") { item in
                Text(item.sheetName)
                    .foregroundStyle(.secondary)
            }
            TableColumn("Категория") { item in
                if let category = item.dataFields.first(where: { $0.key == "Категория" })?.value {
                    Text(category)
                        .foregroundStyle(.secondary)
                } else {
                    Text("")
                }
            }
            TableColumn("Заметки") { item in
                if let notes = item.dataFields.first(where: { $0.key == "Заметки" })?.value {
                    Text(notes)
                        .foregroundStyle(.secondary)
                } else {
                    Text("")
                }
            }
            TableColumn("Дата") { item in
                Text(formatDate(item.date))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Editable Cell for Specific Records

private struct EditableSpecificRecordCell: View {
    let recordID: Int64
    let fieldKey: String
    let value: String
    let editingCell: EditingCell?
    let selectedCell: SelectedCell?
    
    let onSave: (String) -> Void
    let onStartEditing: () -> Void
    let onSelectCell: () -> Void
    let onCancelEditing: () -> Void
    
    // Локальное состояние для редактирования (не вызывает publishing warnings)
    @State private var localEditingValue: String = ""
    
    // Используем recordID как motorID для совместимости с EditingCell
    private var isEditing: Bool {
        editingCell?.motorID == recordID
    }
    
    private var isSelected: Bool {
        selectedCell?.motorID == recordID
    }
    
    var body: some View {
        Group {
            if isEditing {
                TextField("", text: $localEditingValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(DSColors.background)
                    .onAppear {
                        localEditingValue = value
                    }
                    .onSubmit {
                        onSave(localEditingValue)
                        onCancelEditing()
                    }
            } else {
                Text(value.isEmpty ? " " : value)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .background(
                        isSelected 
                            ? DSColors.accent.opacity(0.15)
                            : DSColors.card
                    )
                    .overlay(
                        Rectangle()
                            .stroke(
                                isSelected ? Color.accentColor : Color.clear,
                                lineWidth: 1.5
                            )
                    )
                    .onTapGesture(count: 2) {
                        onStartEditing()
                    }
                    .onTapGesture {
                        onSelectCell()
                    }
            }
        }
        .frame(height: 22)
        .border(Color.white.opacity(0.08), width: 0.5)
        .id("\(recordID)-\(fieldKey)")
    }
}

@MainActor
private final class ServiceRecordsTableViewModel: ObservableObject {
    @Published private(set) var allRecords: [RecordDisplayItem] = []
    @Published private(set) var allFieldNames: [String] = []

    func rebuild(records: [ServiceRecord], specificRecords: [DatabaseService.SpecificRecord]) {
        var items: [RecordDisplayItem] = []
        items.reserveCapacity(records.count + specificRecords.count)
        items.append(contentsOf: records.map(RecordDisplayItem.fromServiceRecord))
        items.append(contentsOf: specificRecords.map(RecordDisplayItem.fromSpecificRecord))
        allRecords = items

        var fieldSet = Set<String>()
        for record in specificRecords {
            for key in record.data.keys where !key.hasPrefix("_") {
                fieldSet.insert(key)
            }
        }
        allFieldNames = Array(fieldSet).sorted()
    }
}

#endif

// Объединенная модель для отображения записей
private struct RecordDisplayItem: Identifiable {
    let id: Int64
    let serialCode: String
    let sheetName: String
    let dataFields: [(key: String, value: String)]
    let data: [String: String]
    let date: Date
    
    static func fromServiceRecord(_ record: ServiceRecord) -> RecordDisplayItem {
        RecordDisplayItem(
            id: record.id,
            serialCode: record.serialCode,
            sheetName: record.sheetName,
            dataFields: [
                ("Категория", record.category),
                ("Заметки", record.notes)
            ],
            data: [
                "Категория": record.category,
                "Заметки": record.notes
            ],
            date: record.recordDate
        )
    }
    
    static func fromSpecificRecord(_ record: DatabaseService.SpecificRecord) -> RecordDisplayItem {
        // Ищем номер двигателя в данных
        let serialCode = record.data["НОМЕР ДВИГАТЕЛЯ"] ?? 
                        record.data["НОМЕР"] ?? 
                        record.data["SERIAL"] ?? 
                        record.data["SERIAL_CODE"] ?? 
                        record.data.values.first ?? ""
        
        // Имя категории добавляется в данные при загрузке
        let sheetName = record.data["_CATEGORY_NAME"] ?? 
                       record.data["ЛИСТ"] ?? 
                       record.data["SHEET"] ?? 
                       "Специфичный"
        
        // Все поля данных (исключаем служебные поля, начинающиеся с _)
        let dataFields = record.data
            .filter { !$0.key.hasPrefix("_") } // Исключаем служебные поля
            .map { (key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key } // Сортируем по ключу для стабильности
        
        return RecordDisplayItem(
            id: record.id,
            serialCode: serialCode,
            sheetName: sheetName,
            dataFields: dataFields,
            data: Dictionary(uniqueKeysWithValues: dataFields),
            date: record.createdAt
        )
    }
}
