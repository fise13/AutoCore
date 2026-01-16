import SwiftUI

struct ServiceRecordsView: View {
    let records: [ServiceRecord]
    let specificRecords: [DatabaseService.SpecificRecord] // Новые записи из specific_records
    let searchText: String
    let onSearchTextChange: (String) -> Void
    let isLoading: Bool
    let totalCount: Int
    let categoryName: String
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Объединяем старые ServiceRecord и новые SpecificRecord для отображения
    private var allRecords: [RecordDisplayItem] {
        var items: [RecordDisplayItem] = []
        
        // Старые записи из service_records
        for record in records {
            items.append(RecordDisplayItem.fromServiceRecord(record))
        }
        
        // Новые записи из specific_records
        for record in specificRecords {
            items.append(RecordDisplayItem.fromSpecificRecord(record))
        }
        
        return items
    }
    
    // Собираем все уникальные поля из записей для создания динамических колонок
    private var allFieldNames: [String] {
        var fieldSet = Set<String>()
        
        // Собираем поля из specific_records (игнорируем служебные)
        for record in specificRecords {
            for key in record.data.keys {
                // Игнорируем служебные поля
                if !key.hasPrefix("_") {
                    fieldSet.insert(key)
                }
            }
        }
        
        // Сортируем по алфавиту для стабильного порядка
        return Array(fieldSet).sorted()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if allRecords.isEmpty && !isLoading {
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
                if !allFieldNames.isEmpty {
                    // Для специфичных записей - динамические колонки
                    dynamicTable
                } else {
                    // Для старых service_records - стандартная таблица
                    legacyTable
                }
            }
        }
        .searchable(text: Binding(
            get: { searchText },
            set: { newValue in
                // Вызываем напрямую - изменение произойдет после завершения рендера
                onSearchTextChange(newValue)
            }
        ), prompt: "Поиск по номеру двигателя, данным, листу")
    }
    
    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
    
    // Динамическая таблица с колонками на основе полей из данных
    private var dynamicTable: some View {
        // Ограничиваем до 7 динамических колонок (уже есть 3 фиксированные: Номер, Лист, Дата)
        let fieldsToShow = Array(allFieldNames.prefix(7))
        
        return Table(allRecords) {
            TableColumn("Номер двигателя") { item in
                Text(item.serialCode)
            }
            TableColumn("Лист") { item in
                Text(item.sheetName)
                    .foregroundStyle(.secondary)
            }
            
            // Создаем динамические колонки напрямую в Table через встроенные условия
            if fieldsToShow.count > 0 {
                TableColumn(fieldsToShow[0]) { item in
                    Text(item.dataFields.first(where: { $0.key == fieldsToShow[0] })?.value ?? "")
                }
            }
            if fieldsToShow.count > 1 {
                TableColumn(fieldsToShow[1]) { item in
                    Text(item.dataFields.first(where: { $0.key == fieldsToShow[1] })?.value ?? "")
                }
            }
            if fieldsToShow.count > 2 {
                TableColumn(fieldsToShow[2]) { item in
                    Text(item.dataFields.first(where: { $0.key == fieldsToShow[2] })?.value ?? "")
                }
            }
            if fieldsToShow.count > 3 {
                TableColumn(fieldsToShow[3]) { item in
                    Text(item.dataFields.first(where: { $0.key == fieldsToShow[3] })?.value ?? "")
                }
            }
            if fieldsToShow.count > 4 {
                TableColumn(fieldsToShow[4]) { item in
                    Text(item.dataFields.first(where: { $0.key == fieldsToShow[4] })?.value ?? "")
                }
            }
            if fieldsToShow.count > 5 {
                TableColumn(fieldsToShow[5]) { item in
                    Text(item.dataFields.first(where: { $0.key == fieldsToShow[5] })?.value ?? "")
                }
            }
            if fieldsToShow.count > 6 {
                TableColumn(fieldsToShow[6]) { item in
                    Text(item.dataFields.first(where: { $0.key == fieldsToShow[6] })?.value ?? "")
                }
            }
            
            TableColumn("Дата") { item in
                Text(formatDate(item.date))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    
    // Стандартная таблица для старых service_records
    @ViewBuilder
    private var legacyTable: some View {
        Table(allRecords) {
            TableColumn("Номер двигателя") { item in
                Text(item.serialCode)
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

// Объединенная модель для отображения записей
private struct RecordDisplayItem: Identifiable {
    let id: Int64
    let serialCode: String
    let sheetName: String
    let dataFields: [(key: String, value: String)]
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
            date: record.createdAt
        )
    }
}
