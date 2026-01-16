import Foundation
import SQLite3

final class DatabaseService {
    struct MotorFilter: Hashable {
        var searchText: String = ""
        var availability: MotorAvailabilityFilter = .all
        var brandID: Int64? = nil
        var engineID: Int64? = nil
    }

    private let queue = DispatchQueue(label: "AutoCore.DatabaseQueue")
    private var db: OpaquePointer?
    private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init() throws {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folderURL = appSupport.appendingPathComponent("AutoCore", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let dbURL = folderURL.appendingPathComponent("autocore.sqlite")

        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(dbURL.path, &db, flags, nil) != SQLITE_OK {
            throw DatabaseError.openDatabase(message: errorMessage)
        }

        // Включаем внешние ключи и создаём схему при первом запуске.
        try execute(sql: "PRAGMA foreign_keys = ON;")
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    func fetchBrands() throws -> [Brand] {
        try query(sql: "SELECT id, name FROM brands ORDER BY name ASC;") { statement in
            let id = sqlite3_column_int64(statement, 0)
            let name = stringColumn(statement, index: 1)
            return Brand(id: id, name: name)
        }
    }

    func fetchEngines(brandID: Int64?) throws -> [Engine] {
        if let brandID {
            return try query(
                sql: "SELECT id, brand_id, engine_code FROM engines WHERE brand_id = ? ORDER BY engine_code ASC;",
                bindings: [.int64(brandID)]
            ) { statement in
                Engine(
                    id: sqlite3_column_int64(statement, 0),
                    brandID: sqlite3_column_int64(statement, 1),
                    code: stringColumn(statement, index: 2)
                )
            }
        }

        return try query(
            sql: "SELECT id, brand_id, engine_code FROM engines ORDER BY engine_code ASC;"
        ) { statement in
            Engine(
                id: sqlite3_column_int64(statement, 0),
                brandID: sqlite3_column_int64(statement, 1),
                code: stringColumn(statement, index: 2)
            )
        }
    }

    func fetchMotors(filter: MotorFilter, limit: Int? = nil, offset: Int = 0) throws -> [Motor] {
        var sql = """
        SELECT motors.id,
               motors.engine_id,
               motors.serial_code,
               motors.configuration,
               motors.notes,
               motors.quantity,
               motors.transmission,
               motors.arrival_date,
               motors.sold_date,
               motors.created_at,
               motors.updated_at,
               brands.name,
               engines.engine_code
        FROM motors
        JOIN engines ON engines.id = motors.engine_id
        JOIN brands ON brands.id = engines.brand_id
        WHERE 1 = 1
        """
        var bindings: [SQLiteBinding] = []

        if let brandID = filter.brandID {
            sql += " AND brands.id = ?"
            bindings.append(.int64(brandID))
        }
        if let engineID = filter.engineID {
            sql += " AND engines.id = ?"
            bindings.append(.int64(engineID))
        }
        switch filter.availability {
        case .all:
            break
        case .available:
            sql += " AND motors.sold_date IS NULL"
        case .sold:
            sql += " AND motors.sold_date IS NOT NULL"
        }
        if !filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sql += " AND (motors.serial_code LIKE ? OR engines.engine_code LIKE ? OR brands.name LIKE ?)"
            let like = "%\(filter.searchText)%"
            bindings.append(.text(like))
            bindings.append(.text(like))
            bindings.append(.text(like))
        }
        
        if filter.availability == .sold {
            sql += " ORDER BY motors.sold_date DESC, motors.created_at DESC"
        } else {
            sql += " ORDER BY motors.arrival_date DESC, motors.created_at DESC"
        }
        
        if let limit = limit {
            sql += " LIMIT ? OFFSET ?"
            bindings.append(.int64(Int64(limit)))
            bindings.append(.int64(Int64(offset)))
        }
        sql += ";"

        return try query(sql: sql, bindings: bindings) { statement in
            let arrivalDate = dateFormatter.date(from: stringColumn(statement, index: 7)) ?? Date()
            let soldDateString = optionalStringColumn(statement, index: 8)
            let soldDate = soldDateString.flatMap { dateFormatter.date(from: $0) }
            let createdAt = dateFormatter.date(from: stringColumn(statement, index: 9)) ?? Date()
            let updatedAt = dateFormatter.date(from: stringColumn(statement, index: 10)) ?? createdAt
            return Motor(
                id: sqlite3_column_int64(statement, 0),
                engineID: sqlite3_column_int64(statement, 1),
                serialCode: stringColumn(statement, index: 2),
                configuration: stringColumn(statement, index: 3),
                notes: stringColumn(statement, index: 4),
                quantity: Int(sqlite3_column_int64(statement, 5)),
                transmission: stringColumn(statement, index: 6),
                arrivalDate: arrivalDate,
                soldDate: soldDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                brandName: stringColumn(statement, index: 11),
                engineCode: stringColumn(statement, index: 12)
            )
        }
    }
    
    func countMotors(filter: MotorFilter) throws -> Int {
        var sql = """
        SELECT COUNT(*)
        FROM motors
        JOIN engines ON engines.id = motors.engine_id
        JOIN brands ON brands.id = engines.brand_id
        WHERE 1 = 1
        """
        var bindings: [SQLiteBinding] = []

        if let brandID = filter.brandID {
            sql += " AND brands.id = ?"
            bindings.append(.int64(brandID))
        }
        if let engineID = filter.engineID {
            sql += " AND engines.id = ?"
            bindings.append(.int64(engineID))
        }
        switch filter.availability {
        case .all:
            break
        case .available:
            sql += " AND motors.sold_date IS NULL"
        case .sold:
            sql += " AND motors.sold_date IS NOT NULL"
        }
        if !filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sql += " AND (motors.serial_code LIKE ?)"
            let like = "%\(filter.searchText)%"
            bindings.append(.text(like))
        }
        sql += ";"
        
        let results = try query(sql: sql, bindings: bindings) { statement in
            Int(sqlite3_column_int64(statement, 0))
        }
        return results.first ?? 0
    }

    func upsertBrand(name: String) throws -> Int64 {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            throw DatabaseError.invalidInput(message: "Пустое имя бренда.")
        }
        try inTransaction {
            try executeUnlocked(
                sql: "INSERT INTO brands (name) VALUES (?) ON CONFLICT(name) DO NOTHING;",
                bindings: [.text(normalized)]
            )
        }
        return try singleValueInt64(
            sql: "SELECT id FROM brands WHERE name = ?;",
            bindings: [.text(normalized)]
        )
    }
    
    func upsertBrandUnlocked(name: String) throws -> Int64 {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            throw DatabaseError.invalidInput(message: "Пустое имя бренда.")
        }
        // Вызывается внутри queue.sync через executeInTransactionBlock
        try executeUnlocked(
            sql: "INSERT INTO brands (name) VALUES (?) ON CONFLICT(name) DO NOTHING;",
            bindings: [.text(normalized)]
        )
        return try singleValueInt64Unlocked(
            sql: "SELECT id FROM brands WHERE name = ?;",
            bindings: [.text(normalized)]
        )
    }

    func upsertEngine(brandID: Int64, code: String) throws -> Int64 {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty {
            throw DatabaseError.invalidInput(message: "Пустой код двигателя.")
        }
        try inTransaction {
            try executeUnlocked(
                sql: "INSERT INTO engines (brand_id, engine_code) VALUES (?, ?) ON CONFLICT(brand_id, engine_code) DO NOTHING;",
                bindings: [.int64(brandID), .text(normalized)]
            )
        }
        return try singleValueInt64(
            sql: "SELECT id FROM engines WHERE brand_id = ? AND engine_code = ?;",
            bindings: [.int64(brandID), .text(normalized)]
        )
    }
    
    func upsertEngineUnlocked(brandID: Int64, code: String) throws -> Int64 {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty {
            throw DatabaseError.invalidInput(message: "Пустой код двигателя.")
        }
        // Вызывается внутри queue.sync через executeInTransactionBlock
        try executeUnlocked(
            sql: "INSERT INTO engines (brand_id, engine_code) VALUES (?, ?) ON CONFLICT(brand_id, engine_code) DO NOTHING;",
            bindings: [.int64(brandID), .text(normalized)]
        )
        return try singleValueInt64Unlocked(
            sql: "SELECT id FROM engines WHERE brand_id = ? AND engine_code = ?;",
            bindings: [.int64(brandID), .text(normalized)]
        )
    }

    func insertOrUpdateMotor(
        engineID: Int64,
        serialCode: String,
        configuration: String,
        notes: String,
        quantity: Int,
        transmission: String,
        arrivalDate: Date?,
        soldDate: Date?
    ) throws -> Int64 {
        let normalizedSerial = serialCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedSerial.isEmpty {
            throw DatabaseError.invalidInput(message: "Пустой серийный номер.")
        }
        try inTransaction {
            try insertOrUpdateMotorUnlocked(
                engineID: engineID,
                serialCode: normalizedSerial,
                configuration: configuration,
                notes: notes,
                quantity: quantity,
                transmission: transmission,
                arrivalDate: arrivalDate,
                soldDate: soldDate
            )
        }
        return try singleValueInt64(
            sql: "SELECT id FROM motors WHERE serial_code = ?;",
            bindings: [.text(normalizedSerial)]
        )
    }
    
    func insertOrUpdateMotorUnlocked(
        engineID: Int64,
        serialCode: String,
        configuration: String,
        notes: String,
        quantity: Int,
        transmission: String,
        arrivalDate: Date?,
        soldDate: Date?
    ) throws {
        let createdAt = dateFormatter.string(from: Date())
        let updatedAt = createdAt
        let arrivalValue = arrivalDate ?? Date()
        let arrivalString = dateFormatter.string(from: arrivalValue)
        let soldString = soldDate.map { dateFormatter.string(from: $0) }
        // Серийный номер уникален, поэтому применяем upsert.
        // Вызывается внутри queue.sync через executeInTransactionBlock
        try executeUnlocked(
            sql: """
            INSERT INTO motors (
                engine_id,
                serial_code,
                configuration,
                notes,
                quantity,
                transmission,
                arrival_date,
                sold_date,
                created_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(serial_code) DO UPDATE SET
                engine_id = excluded.engine_id,
                configuration = excluded.configuration,
                notes = excluded.notes,
                quantity = excluded.quantity,
                transmission = excluded.transmission,
                arrival_date = excluded.arrival_date,
                sold_date = excluded.sold_date,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .int64(engineID),
                .text(serialCode),
                .text(configuration),
                .text(notes),
                .int64(Int64(max(quantity, 1))),
                .text(transmission),
                .text(arrivalString),
                .textOptional(soldString),
                .text(createdAt),
                .text(updatedAt)
            ]
        )
    }
    
    private func singleValueInt64Unlocked(sql: String, bindings: [SQLiteBinding] = []) throws -> Int64 {
        let statement = try prepare(sql: sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.executionFailed(message: "No row returned")
        }
        return sqlite3_column_int64(statement, 0)
    }

    func updateMotor(
        id: Int64,
        configuration: String,
        notes: String,
        quantity: Int,
        transmission: String,
        arrivalDate: Date,
        soldDate: Date?
    ) throws {
        try inTransaction {
            let updatedAt = dateFormatter.string(from: Date())
            try executeUnlocked(
                sql: """
                UPDATE motors
                SET configuration = ?,
                    notes = ?,
                    quantity = ?,
                    transmission = ?,
                    arrival_date = ?,
                    sold_date = ?,
                    updated_at = ?
                WHERE id = ?;
                """,
                bindings: [
                    .text(configuration),
                    .text(notes),
                    .int64(Int64(max(quantity, 1))),
                    .text(transmission),
                    .text(dateFormatter.string(from: arrivalDate)),
                    .textOptional(soldDate.map { dateFormatter.string(from: $0) }),
                    .text(updatedAt),
                    .int64(id)
                ]
            )
        }
    }

    func updateSoldDate(id: Int64, soldDate: Date?) throws {
        try inTransaction {
            let updatedAt = dateFormatter.string(from: Date())
            try executeUnlocked(
                sql: "UPDATE motors SET sold_date = ?, updated_at = ? WHERE id = ?;",
                bindings: [
                    .textOptional(soldDate.map { dateFormatter.string(from: $0) }),
                    .text(updatedAt),
                    .int64(id)
                ]
            )
        }
    }

    func applySoldDateFromImport(serialCode: String, soldDate: Date) throws {
        let normalized = serialCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        let existing = try query(
            sql: "SELECT id, sold_date FROM motors WHERE serial_code = ?;",
            bindings: [.text(normalized)]
        ) { statement -> (Int64, String?) in
            (sqlite3_column_int64(statement, 0), optionalStringColumn(statement, index: 1))
        }
        guard let (id, existingSold) = existing.first else { return }
        if existingSold != nil {
            return
        }
        try updateSoldDate(id: id, soldDate: soldDate)
    }
    
    func deleteMotor(id: Int64) throws {
        try inTransaction {
            try executeUnlocked(
                sql: "DELETE FROM motors WHERE id = ?;",
                bindings: [.int64(id)]
            )
        }
    }
    
    func insertServiceRecord(
        serialCode: String,
        sheetName: String,
        category: String,
        notes: String,
        date: Date
    ) throws {
        let createdAt = dateFormatter.string(from: Date())
        let recordDate = dateFormatter.string(from: date)
        try queue.sync {
            try executeUnlocked(
                sql: """
                INSERT INTO service_records (serial_code, sheet_name, category, notes, record_date, created_at)
                VALUES (?, ?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(serialCode),
                    .text(sheetName),
                    .text(category),
                    .text(notes),
                    .text(recordDate),
                    .text(createdAt)
                ]
            )
        }
    }
    
    func insertServiceRecordUnlocked(
        serialCode: String,
        sheetName: String,
        category: String,
        notes: String,
        date: Date
    ) throws {
        let createdAt = dateFormatter.string(from: Date())
        let recordDate = dateFormatter.string(from: date)
        // Вызывается внутри queue.sync через executeInTransactionBlock
        try executeUnlocked(
            sql: """
            INSERT INTO service_records (serial_code, sheet_name, category, notes, record_date, created_at)
            VALUES (?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(serialCode),
                .text(sheetName),
                .text(category),
                .text(notes),
                .text(recordDate),
                .text(createdAt)
            ]
        )
    }
    
    func fetchServiceRecords(category: String, searchText: String = "") throws -> [ServiceRecord] {
        var sql = """
        SELECT id, serial_code, sheet_name, category, notes, record_date, created_at
        FROM service_records
        WHERE category = ?
        """
        var bindings: [SQLiteBinding] = [.text(category)]
        
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sql += " AND (serial_code LIKE ? OR notes LIKE ? OR sheet_name LIKE ?)"
            let like = "%\(searchText)%"
            bindings.append(.text(like))
            bindings.append(.text(like))
            bindings.append(.text(like))
        }
        
        sql += " ORDER BY record_date DESC, created_at DESC;"
        
        return try query(sql: sql, bindings: bindings) { statement in
            ServiceRecord(
                id: sqlite3_column_int64(statement, 0),
                serialCode: stringColumn(statement, index: 1),
                sheetName: stringColumn(statement, index: 2),
                category: stringColumn(statement, index: 3),
                notes: stringColumn(statement, index: 4),
                recordDate: dateFromString(stringColumn(statement, index: 5)) ?? Date(),
                createdAt: dateFromString(stringColumn(statement, index: 6)) ?? Date()
            )
        }
    }
    
    func countServiceRecords(category: String, searchText: String = "") throws -> Int {
        var sql = "SELECT COUNT(*) FROM service_records WHERE category = ?"
        var bindings: [SQLiteBinding] = [.text(category)]
        
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sql += " AND (serial_code LIKE ? OR notes LIKE ? OR sheet_name LIKE ?)"
            let like = "%\(searchText)%"
            bindings.append(.text(like))
            bindings.append(.text(like))
            bindings.append(.text(like))
        }
        
        sql += ";"
        
        return Int(try singleValueInt64(sql: sql, bindings: bindings))
    }
    
    private func dateFromString(_ string: String) -> Date? {
        dateFormatter.date(from: string)
    }
    
    func fetchAllServiceRecords() throws -> [ServiceRecord] {
        return try query(
            sql: "SELECT id, serial_code, sheet_name, category, notes, record_date, created_at FROM service_records ORDER BY record_date DESC;"
        ) { statement in
            ServiceRecord(
                id: sqlite3_column_int64(statement, 0),
                serialCode: stringColumn(statement, index: 1),
                sheetName: stringColumn(statement, index: 2),
                category: stringColumn(statement, index: 3),
                notes: stringColumn(statement, index: 4),
                recordDate: dateFromString(stringColumn(statement, index: 5)) ?? Date(),
                createdAt: dateFromString(stringColumn(statement, index: 6)) ?? Date()
            )
        }
    }
    
    // Методы для работы с specific_sheets и specific_records
    func upsertSpecificSheetUnlocked(name: String) throws -> Int64 {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            throw DatabaseError.invalidInput(message: "Пустое имя листа.")
        }
        // Вызывается внутри queue.sync через executeInTransactionBlock
        try executeUnlocked(
            sql: "INSERT INTO specific_sheets (name, created_at) VALUES (?, ?) ON CONFLICT(name) DO NOTHING;",
            bindings: [.text(normalized), .text(dateFormatter.string(from: Date()))]
        )
        return try singleValueInt64Unlocked(
            sql: "SELECT id FROM specific_sheets WHERE name = ?;",
            bindings: [.text(normalized)]
        )
    }
    
    func insertSpecificRecordUnlocked(
        sheetID: Int64,
        rowIndex: Int,
        dataJSON: String
    ) throws {
        // Вызывается внутри queue.sync через executeInTransactionBlock
        try executeUnlocked(
            sql: """
            INSERT INTO specific_records (sheet_id, row_index, data_json, created_at)
            VALUES (?, ?, ?, ?);
            """,
            bindings: [
                .int64(sheetID),
                .int64(Int64(rowIndex)),
                .text(dataJSON),
                .text(dateFormatter.string(from: Date()))
            ]
        )
    }
    
    // Методы для чтения specific_sheets и specific_records
    struct SpecificSheet: Identifiable {
        let id: Int64
        let name: String
        let createdAt: Date
    }
    
    struct SpecificRecord: Identifiable {
        let id: Int64
        let sheetID: Int64
        let rowIndex: Int
        let data: [String: String]
        let createdAt: Date
    }
    
    func fetchAllSpecificSheets() throws -> [SpecificSheet] {
        return try query(
            sql: "SELECT id, name, created_at FROM specific_sheets ORDER BY name ASC;"
        ) { statement in
            let createdAtString = stringColumn(statement, index: 2)
            let createdAt = dateFormatter.date(from: createdAtString) ?? Date()
            return SpecificSheet(
                id: sqlite3_column_int64(statement, 0),
                name: stringColumn(statement, index: 1),
                createdAt: createdAt
            )
        }
    }
    
    // Получает специфичные записи по категории (название листа должно соответствовать категории)
    func fetchSpecificRecordsByCategory(category: String, searchText: String = "") throws -> [SpecificRecord] {
        // Ищем листы, которые соответствуют категории
        // Категории: "Ремонт", "После Дэна", "После Толи", "Хранение", "Другое"
        let categoryPatterns: [String: [String]] = [
            "Ремонт": ["РЕМОНТ"],
            "После Дэна": ["ДЭН", "ДЕН", "РЕМОНТ ДЭН", "РЕМОНТ ДЕН"],
            "После Толи": ["ТОЛ", "ТОЛЯ", "РЕМОНТ ТОЛ", "РЕМОНТ ТОЛЯ"],
            "Хранение": ["ХРАН", "СКЛАД"],
            "Другое": []
        ]
        
        var patterns = categoryPatterns[category] ?? []
        if category == "Другое" {
            // Для "Другое" берем все листы, которые не подходят под другие категории
            let excludePatterns = categoryPatterns.values.flatMap { $0 }
            // Это сложнее, сделаем проще - ищем листы, которые не содержат известные паттерны
        }
        
        // Получаем все листы
        let allSheets = try fetchAllSpecificSheets()
        
        // Фильтруем листы по категории
        let matchingSheets = allSheets.filter { sheet in
            let sheetNameUpper = sheet.name.uppercased()
            if category == "Другое" {
                // Для "Другое" - листы, которые не подходят под другие категории
                let allOtherPatterns = ["РЕМОНТ", "ДЭН", "ДЕН", "ТОЛ", "ТОЛЯ", "ХРАН", "СКЛАД"]
                return !allOtherPatterns.contains { pattern in
                    sheetNameUpper.contains(pattern)
                }
            } else {
                // Для остальных категорий - проверяем паттерны
                return patterns.contains { pattern in
                    sheetNameUpper.contains(pattern)
                }
            }
        }
        
        if matchingSheets.isEmpty {
            return []
        }
        
        // Получаем записи из всех подходящих листов
        var allRecords: [SpecificRecord] = []
        for sheet in matchingSheets {
            let records = try fetchSpecificRecords(sheetID: sheet.id)
            allRecords.append(contentsOf: records)
        }
        
        // Применяем поиск, если есть
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lowerSearch = searchText.lowercased()
            allRecords = allRecords.filter { record in
                // Ищем в данных записи
                return record.data.values.contains { value in
                    value.lowercased().contains(lowerSearch)
                }
            }
        }
        
        return allRecords
    }
    
    // Подсчет записей по категории
    func countSpecificRecordsByCategory(category: String, searchText: String = "") throws -> Int {
        let records = try fetchSpecificRecordsByCategory(category: category, searchText: searchText)
        return records.count
    }
    
    func fetchSpecificRecords(sheetID: Int64) throws -> [SpecificRecord] {
        return try query(
            sql: "SELECT id, sheet_id, row_index, data_json, created_at FROM specific_records WHERE sheet_id = ? ORDER BY row_index ASC;",
            bindings: [.int64(sheetID)]
        ) { statement in
            let dataJSON = stringColumn(statement, index: 3)
            let createdAtString = stringColumn(statement, index: 4)
            let createdAt = dateFormatter.date(from: createdAtString) ?? Date()
            
            // Парсим JSON
            var data: [String: String] = [:]
            if let jsonData = dataJSON.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                for (key, value) in jsonObject {
                    data[key] = "\(value)"
                }
            }
            
            return SpecificRecord(
                id: sqlite3_column_int64(statement, 0),
                sheetID: sqlite3_column_int64(statement, 1),
                rowIndex: Int(sqlite3_column_int64(statement, 2)),
                data: data,
                createdAt: createdAt
            )
        }
    }
    
    // Поиск в specific_records по номеру двигателя или другим полям
    func searchSpecificRecords(searchText: String) throws -> [SpecificRecord] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let like = "%\(searchText)%"
        return try query(
            sql: """
            SELECT id, sheet_id, row_index, data_json, created_at
            FROM specific_records
            WHERE data_json LIKE ?
            ORDER BY row_index ASC
            LIMIT 1000;
            """,
            bindings: [.text(like)]
        ) { statement in
            let dataJSON = stringColumn(statement, index: 3)
            let createdAtString = stringColumn(statement, index: 4)
            let createdAt = dateFormatter.date(from: createdAtString) ?? Date()
            
            // Парсим JSON
            var data: [String: String] = [:]
            if let jsonData = dataJSON.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                for (key, value) in jsonObject {
                    data[key] = "\(value)"
                }
            }
            
            return SpecificRecord(
                id: sqlite3_column_int64(statement, 0),
                sheetID: sqlite3_column_int64(statement, 1),
                rowIndex: Int(sqlite3_column_int64(statement, 2)),
                data: data,
                createdAt: createdAt
            )
        }
    }
    
    func deleteAllServiceRecords() throws {
        try inTransaction {
            try executeUnlocked(sql: "DELETE FROM service_records;", bindings: [])
        }
    }
    
    func deleteAllMotors() throws {
        try inTransaction {
            try executeUnlocked(sql: "DELETE FROM motors;", bindings: [])
        }
    }
    
    func deleteAllEngines() throws {
        try inTransaction {
            try executeUnlocked(sql: "DELETE FROM engines;", bindings: [])
        }
    }
    
    func deleteAllBrands() throws {
        try inTransaction {
            try executeUnlocked(sql: "DELETE FROM brands;", bindings: [])
        }
    }
    
    func deleteAllData() throws {
        try inTransaction {
            try executeUnlocked(sql: "DELETE FROM service_records;", bindings: [])
            try executeUnlocked(sql: "DELETE FROM motors;", bindings: [])
            try executeUnlocked(sql: "DELETE FROM engines;", bindings: [])
            try executeUnlocked(sql: "DELETE FROM brands;", bindings: [])
        }
    }

    private func migrate() throws {
        // Схема соответствует канонической модели.
        try execute(sql: """
        CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER NOT NULL
        );
        """)

        let currentVersion = (try? singleValueInt64(sql: "SELECT version FROM schema_version LIMIT 1;")) ?? 0
        if currentVersion < 4 {
            // Создаем таблицы для специфичных листов
            try execute(sql: """
            CREATE TABLE IF NOT EXISTS specific_sheets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                created_at TEXT NOT NULL
            );
            """)
            
            try execute(sql: """
            CREATE TABLE IF NOT EXISTS specific_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sheet_id INTEGER NOT NULL,
                row_index INTEGER NOT NULL,
                data_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY(sheet_id) REFERENCES specific_sheets(id) ON DELETE CASCADE
            );
            """)
            
            try execute(sql: "CREATE INDEX IF NOT EXISTS idx_specific_records_sheet_id ON specific_records(sheet_id);")
            try execute(sql: "CREATE INDEX IF NOT EXISTS idx_specific_records_row_index ON specific_records(row_index);")
            
            try execute(sql: "DELETE FROM schema_version;")
            try execute(sql: "INSERT INTO schema_version (version) VALUES (4);")
        }
        if currentVersion < 3 {
            try execute(sql: """
            CREATE TABLE IF NOT EXISTS service_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                serial_code TEXT NOT NULL,
                sheet_name TEXT NOT NULL,
                category TEXT NOT NULL,
                notes TEXT NOT NULL DEFAULT '',
                record_date TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            """)
            try execute(sql: "CREATE INDEX IF NOT EXISTS idx_service_records_serial_code ON service_records(serial_code);")
            try execute(sql: "CREATE INDEX IF NOT EXISTS idx_service_records_category ON service_records(category);")
            try execute(sql: "DELETE FROM schema_version;")
            try execute(sql: "INSERT INTO schema_version (version) VALUES (3);")
        }
        if currentVersion < 2 {
            let requiredColumns = [
                "id",
                "engine_id",
                "serial_code",
                "configuration",
                "notes",
                "quantity",
                "transmission",
                "arrival_date",
                "sold_date",
                "created_at",
                "updated_at"
            ]
            if !tableHasColumns(table: "motors", required: requiredColumns) {
                let legacyName = "motors_legacy_\(Int(Date().timeIntervalSince1970))"
                if tableExists("motors") {
                    try execute(sql: "ALTER TABLE motors RENAME TO \(legacyName);")
                }
            }
            try execute(sql: "DELETE FROM schema_version;")
            try execute(sql: "INSERT INTO schema_version (version) VALUES (2);")
        }

        try execute(sql: """
        CREATE TABLE IF NOT EXISTS brands (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE
        );
        """)

        try execute(sql: """
        CREATE TABLE IF NOT EXISTS engines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            brand_id INTEGER NOT NULL,
            engine_code TEXT NOT NULL,
            UNIQUE(brand_id, engine_code),
            FOREIGN KEY(brand_id) REFERENCES brands(id) ON DELETE CASCADE
        );
        """)

        try execute(sql: """
        CREATE TABLE IF NOT EXISTS motors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            engine_id INTEGER NOT NULL,
            serial_code TEXT NOT NULL UNIQUE,
            configuration TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            quantity INTEGER NOT NULL DEFAULT 1,
            transmission TEXT NOT NULL DEFAULT '',
            arrival_date TEXT NOT NULL,
            sold_date TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY(engine_id) REFERENCES engines(id) ON DELETE CASCADE
        );
        """)

        try execute(sql: "CREATE INDEX IF NOT EXISTS idx_motors_engine_id ON motors(engine_id);")
        try execute(sql: "CREATE INDEX IF NOT EXISTS idx_motors_sold_date ON motors(sold_date);")
        try execute(sql: "CREATE INDEX IF NOT EXISTS idx_motors_serial_code ON motors(serial_code);")
        try execute(sql: "CREATE INDEX IF NOT EXISTS idx_motors_arrival_date ON motors(arrival_date DESC);")
        try execute(sql: "CREATE INDEX IF NOT EXISTS idx_engines_brand_id ON engines(brand_id);")
    }

    private func tableExists(_ table: String) -> Bool {
        let rows = try? query(
            sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?;",
            bindings: [.text(table)]
        ) { _ in true }
        return rows?.isEmpty == false
    }

    private func tableHasColumns(table: String, required: [String]) -> Bool {
        let columns = (try? query(sql: "PRAGMA table_info(\(table));") { statement in
            stringColumn(statement, index: 1)
        }) ?? []
        let existing = Set(columns)
        return Set(required).isSubset(of: existing)
    }

    private func execute(sql: String, bindings: [SQLiteBinding] = []) throws {
        try queue.sync {
            try executeUnlocked(sql: sql, bindings: bindings)
        }
    }

    func beginTransaction() throws {
        // Вызывается внутри executeInTransaction, поэтому не нужен queue.sync
        try executeUnlocked(sql: "BEGIN TRANSACTION;", bindings: [])
    }
    
    func commitTransaction() throws {
        // Вызывается внутри executeInTransaction, поэтому не нужен queue.sync
        try executeUnlocked(sql: "COMMIT;", bindings: [])
    }
    
    func rollbackTransaction() throws {
        // Может вызываться из catch, поэтому нужен queue.sync
        try queue.sync {
            try executeUnlocked(sql: "ROLLBACK;", bindings: [])
        }
    }
    
    func executeInTransactionBlock(_ work: () throws -> Void) throws {
        try queue.sync {
            try work()
        }
    }
    
    private func inTransaction(_ work: () throws -> Void) throws {
        try queue.sync {
            try executeUnlocked(sql: "BEGIN;")
            do {
                try work()
                try executeUnlocked(sql: "COMMIT;")
            } catch {
                try? executeUnlocked(sql: "ROLLBACK;")
                throw error
            }
        }
    }
    
    func executeInTransaction(_ work: () throws -> Void) throws {
        try queue.sync {
            try work()
        }
    }

    private func query<T>(sql: String, bindings: [SQLiteBinding] = [], map: (OpaquePointer) -> T) throws -> [T] {
        try queue.sync {
            let statement = try prepare(sql: sql)
            defer { sqlite3_finalize(statement) }
            try bind(bindings, to: statement)
            var results: [T] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                results.append(map(statement))
            }
            return results
        }
    }

    private func executeUnlocked(sql: String, bindings: [SQLiteBinding] = []) throws {
        let statement = try prepare(sql: sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        if sqlite3_step(statement) != SQLITE_DONE {
            throw DatabaseError.executionFailed(message: errorMessage)
        }
    }

    private func singleValueInt64(sql: String, bindings: [SQLiteBinding] = []) throws -> Int64 {
        let results = try query(sql: sql, bindings: bindings) { statement in
            sqlite3_column_int64(statement, 0)
        }
        guard let value = results.first else {
            throw DatabaseError.executionFailed(message: "Нет результата для запроса.")
        }
        return value
    }

    private func prepare(sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            throw DatabaseError.prepareFailed(message: errorMessage)
        }
        return statement!
    }

    private func bind(_ bindings: [SQLiteBinding], to statement: OpaquePointer) throws {
        for (index, binding) in bindings.enumerated() {
            let position = Int32(index + 1)
            switch binding {
            case .int64(let value):
                sqlite3_bind_int64(statement, position, value)
            case .intOptional(let value):
                if let value {
                    sqlite3_bind_int64(statement, position, Int64(value))
                } else {
                    sqlite3_bind_null(statement, position)
                }
            case .text(let value):
                sqlite3_bind_text(statement, position, value, -1, sqliteTransient)
            case .textOptional(let value):
                if let value {
                    sqlite3_bind_text(statement, position, value, -1, sqliteTransient)
                } else {
                    sqlite3_bind_null(statement, position)
                }
            }
        }
    }

    private var errorMessage: String {
        String(cString: sqlite3_errmsg(db))
    }
}

private enum SQLiteBinding {
    case int64(Int64)
    case intOptional(Int?)
    case text(String)
    case textOptional(String?)
}

private enum DatabaseError: Error {
    case openDatabase(message: String)
    case prepareFailed(message: String)
    case executionFailed(message: String)
    case invalidInput(message: String)
}

private func stringColumn(_ statement: OpaquePointer, index: Int32) -> String {
    if let cString = sqlite3_column_text(statement, index) {
        return String(cString: cString)
    }
    return ""
}

private func optionalStringColumn(_ statement: OpaquePointer, index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
        return nil
    }
    return stringColumn(statement, index: index)
}

private func intColumn(_ statement: OpaquePointer, index: Int32) -> Int? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
        return nil
    }
    return Int(sqlite3_column_int64(statement, index))
}
