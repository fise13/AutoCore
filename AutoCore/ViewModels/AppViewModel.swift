import Foundation
import SwiftUI
import Combine

enum NavigationSection: String, Identifiable {
    case all = "all"
    case sold = "sold"
    case repair = "repair"
    case afterDan = "afterDan"
    case afterTolya = "afterTolya"
    case storage = "storage"
    case other = "other"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .all:
            return "Все моторы"
        case .sold:
            return "Проданные"
        case .repair:
            return "Ремонт"
        case .afterDan:
            return "После Дэна"
        case .afterTolya:
            return "После Толи"
        case .storage:
            return "Хранение"
        case .other:
            return "Другое"
        }
    }
    
    var emoji: String {
        switch self {
        case .all:
            return "🔧"
        case .sold:
            return "✅"
        case .repair:
            return "🔨"
        case .afterDan:
            return "👨‍🔧"
        case .afterTolya:
            return "👨‍💼"
        case .storage:
            return "📦"
        case .other:
            return "📋"
        }
    }
    
    var categoryName: String? {
        switch self {
        case .repair:
            return "Ремонт"
        case .afterDan:
            return "После Дэна"
        case .afterTolya:
            return "После Толи"
        case .storage:
            return "Хранение"
        case .other:
            return "Другое"
        default:
            return nil
        }
    }
    
    static var specificSections: [NavigationSection] {
        [.repair, .afterDan, .afterTolya, .storage, .other]
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var brands: [Brand] = []
    @Published private(set) var engines: [Engine] = []
    // Единый источник истины - все моторы без фильтрации
    @Published private(set) var allMotors: [Motor] = []
    // Отдельный массив для экрана "Проданные" (с отдельным поиском)
    @Published private(set) var soldMotors: [Motor] = []
    @Published private(set) var serviceRecords: [ServiceRecord] = []
    @Published private(set) var specificRecords: [DatabaseService.SpecificRecord] = [] // Записи из specific_records для категорий
    @Published private(set) var allSpecificRecords: [DatabaseService.SpecificRecord] = [] // ВСЕ специфичные записи для "Все моторы" и "Проданные"
    @Published private(set) var totalMotorCount: Int = 0
    @Published private(set) var totalSoldCount: Int = 0
    @Published private(set) var totalServiceRecordsCount: Int = 0

    @Published var selectedSection: NavigationSection = .all
    @Published var selectedBrandID: Int64? {
        didSet { selectedEngineID = nil }
    }
    @Published var selectedEngineID: Int64?
    @Published var selectedMotorID: Int64?

    @Published var searchText = ""
    @Published var soldSearchText = ""
    @Published var serviceRecordsSearchText = ""
    @Published var availabilityFilter: MotorAvailabilityFilter = .all
    
    // Вычисляемое свойство для фильтрации моторов
    // Фильтрация по availability применяется ПЕРВОЙ, затем поиск
    // ВАЖНО: специфичные листы НЕ создают моторы, они хранятся отдельно
    // Но при поиске показываем результаты из specific_records
    var filteredMotors: [Motor] {
        var result = allMotors
        
        // 1. Фильтр по availability (soldDate)
        switch availabilityFilter {
        case .all:
            break // Показываем все
        case .available:
            result = result.filter { $0.soldDate == nil }
        case .sold:
            result = result.filter { $0.soldDate != nil }
        }
        
        // 2. Фильтр по brandID
        if let brandID = selectedBrandID {
            result = result.filter { motor in
                // Находим engine по motor.engineID, затем проверяем его brandID
                if let engine = engines.first(where: { $0.id == motor.engineID }) {
                    return engine.brandID == brandID
                }
                return false
            }
        }
        
        // 3. Фильтр по engineID
        if let engineID = selectedEngineID {
            result = result.filter { $0.engineID == engineID }
        }
        
        // 4. Поиск применяется ПОСЛЕ всех фильтров
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            let lowerSearch = trimmedSearch.lowercased()
            result = result.filter { motor in
                motor.serialCode.lowercased().contains(lowerSearch) ||
                motor.engineCode.lowercased().contains(lowerSearch) ||
                motor.brandName.lowercased().contains(lowerSearch)
            }
        }
        
        // 5. ВСЕГДА добавляем специфичные записи (если нет фильтров по бренду/двигателю)
        // Это позволяет видеть их в "Все моторы" и в поиске
        if selectedBrandID == nil && selectedEngineID == nil {
            // Всегда используем allSpecificRecords, фильтрация происходит ниже
            let recordsToShow = allSpecificRecords
            
            // Конвертируем в виртуальные моторы
            let virtualMotors = recordsToShow.compactMap { record -> Motor? in
                // Ищем номер двигателя в данных
                let serialCode = record.data["НОМЕР ДВИГАТЕЛЯ"] ?? 
                               record.data["НОМЕР"] ?? 
                               record.data["SERIAL"] ?? 
                               record.data["SERIAL_CODE"] ??
                               record.data.values.first ?? ""
                
                if serialCode.isEmpty { return nil }
                
                // Применяем поиск, если есть
                if !trimmedSearch.isEmpty {
                    let lowerSearch = trimmedSearch.lowercased()
                    let matchesSearch = serialCode.lowercased().contains(lowerSearch) ||
                                       record.data.values.contains { $0.lowercased().contains(lowerSearch) }
                    if !matchesSearch { return nil }
                }
                
                // Создаем виртуальный мотор
                return Motor(
                    id: -record.id, // Отрицательный ID для виртуальных моторов
                    engineID: -1,
                    serialCode: serialCode,
                    configuration: record.data["КОМПЛЕКТАЦИЯ"] ?? record.data["КОНФИГУРАЦИЯ"] ?? "",
                    notes: record.data.map { "\($0.key): \($0.value)" }.joined(separator: ", "),
                    quantity: Int(record.data["КОЛИЧЕСТВО"] ?? record.data["QUANTITY"] ?? "1") ?? 1,
                    transmission: record.data["КОРОБКА"] ?? record.data["TRANSMISSION"] ?? "",
                    arrivalDate: record.createdAt,
                    soldDate: nil, // Специфичные записи не имеют soldDate
                    createdAt: record.createdAt,
                    updatedAt: record.createdAt,
                    brandName: "Специфичный",
                    engineCode: "—"
                )
            }
            result.append(contentsOf: virtualMotors)
        }
        
        return result
    }

    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published private(set) var hasMorePages = true
    @Published private(set) var hasMoreSoldPages = true
    
    private let pageSize = 500
    private var currentPage = 0
    private var currentSoldPage = 0

    let database: DatabaseService
    let undoManager = UndoManager()
    private var cancellables = Set<AnyCancellable>()

    init(database: DatabaseService) {
        self.database = database
        undoManager.groupsByEvent = true
        observeFilters()
        refreshAll()
    }

    func refreshAll() {
        isLoading = true
        currentPage = 0
        currentSoldPage = 0
        hasMorePages = true
        hasMoreSoldPages = true
        // Загружаем ВСЕ моторы без фильтрации для allMotors
        let allFilter = DatabaseService.MotorFilter(availability: .all)
        let soldFilter = DatabaseService.MotorFilter(availability: .sold)
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let brands = try self.database.fetchBrands()
                let engines = try self.database.fetchEngines(brandID: nil)
                // Загружаем все моторы без фильтрации (для allMotors)
                let allMotors = try self.database.fetchMotors(filter: allFilter, limit: nil, offset: 0)
                let totalCount = allMotors.count
                let totalSoldCount = try self.database.countMotors(filter: soldFilter)
                let soldMotors = try self.database.fetchMotors(filter: soldFilter, limit: self.pageSize, offset: 0)
                
                // Загружаем ВСЕ специфичные записи для отображения в "Все моторы" и "Проданные"
                let allSheets = try self.database.fetchAllSpecificSheets()
                var allSpecificRecords: [DatabaseService.SpecificRecord] = []
                for sheet in allSheets {
                    let records = try self.database.fetchSpecificRecords(sheetID: sheet.id)
                    // Добавляем имя листа в данные для отображения
                    let recordsWithSheetName = records.map { record -> DatabaseService.SpecificRecord in
                        var dataWithSheetName = record.data
                        dataWithSheetName["_SHEET_NAME"] = sheet.name
                        return DatabaseService.SpecificRecord(
                            id: record.id,
                            sheetID: record.sheetID,
                            rowIndex: record.rowIndex,
                            data: dataWithSheetName,
                            createdAt: record.createdAt
                        )
                    }
                    allSpecificRecords.append(contentsOf: recordsWithSheetName)
                }
                
                await self.updateState(
                    brands: brands,
                    engines: engines,
                    allMotors: allMotors,
                    soldMotors: soldMotors,
                    totalCount: totalCount,
                    totalSoldCount: totalSoldCount,
                    allSpecificRecords: allSpecificRecords
                )
                await self.setHasMorePages(false) // Все загружены в память
                await self.setHasMoreSoldPages(soldMotors.count >= self.pageSize)
            } catch {
                await self.setError("Ошибка базы данных: \(error.localizedDescription)")
            }
        }
    }
    
    func refreshSoldMotors() {
        currentSoldPage = 0
        hasMoreSoldPages = true
        let searchText = soldSearchText
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                // Загружаем проданные моторы
                let soldFilter = DatabaseService.MotorFilter(searchText: searchText, availability: .sold)
                let soldMotors = try self.database.fetchMotors(filter: soldFilter, limit: self.pageSize, offset: 0)
                let totalCount = try self.database.countMotors(filter: soldFilter)
                
                // Добавляем специфичные записи в "Проданные"
                // (хотя у них нет soldDate, пользователь хочет их видеть)
                let allSheets = try self.database.fetchAllSpecificSheets()
                var specificRecords: [DatabaseService.SpecificRecord] = []
                for sheet in allSheets {
                    let records = try self.database.fetchSpecificRecords(sheetID: sheet.id)
                    let recordsWithSheetName = records.map { record -> DatabaseService.SpecificRecord in
                        var dataWithSheetName = record.data
                        dataWithSheetName["_SHEET_NAME"] = sheet.name
                        return DatabaseService.SpecificRecord(
                            id: record.id,
                            sheetID: record.sheetID,
                            rowIndex: record.rowIndex,
                            data: dataWithSheetName,
                            createdAt: record.createdAt
                        )
                    }
                    specificRecords.append(contentsOf: recordsWithSheetName)
                }
                
                // Фильтруем специфичные записи по поиску, если есть
                let filteredSpecificRecords: [DatabaseService.SpecificRecord]
                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let lowerSearch = searchText.lowercased()
                    filteredSpecificRecords = specificRecords.filter { record in
                        record.data.values.contains { value in
                            value.lowercased().contains(lowerSearch)
                        }
                    }
                } else {
                    filteredSpecificRecords = specificRecords
                }
                
                // Конвертируем специфичные записи в виртуальные моторы
                let virtualMotors = filteredSpecificRecords.compactMap { record -> Motor? in
                    let serialCode = record.data["НОМЕР ДВИГАТЕЛЯ"] ?? 
                                   record.data["НОМЕР"] ?? 
                                   record.data["SERIAL"] ?? 
                                   record.data["SERIAL_CODE"] ?? 
                                   ""
                    
                    return Motor(
                        id: -record.id,
                        engineID: -1,
                        serialCode: serialCode.isEmpty ? "Специфичный \(record.id)" : serialCode,
                        configuration: record.data["КОМПЛЕКТАЦИЯ"] ?? record.data["КОНФИГУРАЦИЯ"] ?? "",
                        notes: record.data.filter { !$0.key.hasPrefix("_") }.map { "\($0.key): \($0.value)" }.joined(separator: ", "),
                        quantity: Int(record.data["КОЛИЧЕСТВО"] ?? record.data["QUANTITY"] ?? "1") ?? 1,
                        transmission: record.data["КОРОБКА"] ?? record.data["TRANSMISSION"] ?? "",
                        arrivalDate: record.createdAt,
                        soldDate: record.createdAt, // Устанавливаем soldDate = createdAt для отображения в "Проданные"
                        createdAt: record.createdAt,
                        updatedAt: record.createdAt,
                        brandName: "Специфичный",
                        engineCode: "—"
                    )
                }
                
                var allSoldMotors = soldMotors
                allSoldMotors.append(contentsOf: virtualMotors)
                
                await self.updateSoldMotors(allSoldMotors, totalCount: totalCount + virtualMotors.count)
                await self.setHasMoreSoldPages(allSoldMotors.count >= self.pageSize)
            } catch {
                await self.setError("Ошибка загрузки проданных моторов: \(error.localizedDescription)")
            }
        }
    }
    
    func loadMoreSoldMotorsIfNeeded() {
        guard hasMoreSoldPages, !isLoading else { return }
        isLoading = true
        currentSoldPage += 1
        let page = currentSoldPage
        let searchText = soldSearchText
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let filter = DatabaseService.MotorFilter(searchText: searchText, availability: .sold)
                let offset = page * self.pageSize
                let newMotors = try self.database.fetchMotors(filter: filter, limit: self.pageSize, offset: offset)
                await self.appendSoldMotors(newMotors)
                await self.setHasMoreSoldPages(newMotors.count >= self.pageSize)
            } catch {
                await self.setError("Ошибка загрузки моторов: \(error.localizedDescription)")
            }
        }
    }

    func refreshEngines() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let engines = try self.database.fetchEngines(brandID: nil)
                await self.updateEngines(engines)
            } catch {
                await self.setError("Ошибка загрузки двигателей: \(error.localizedDescription)")
            }
        }
    }

    func refreshMotors() {
        // Обновляем allMotors из БД (загружаем все моторы)
        // Фильтрация будет происходить через вычисляемое свойство filteredMotors
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let allFilter = DatabaseService.MotorFilter(availability: .all)
                let allMotors = try self.database.fetchMotors(filter: allFilter, limit: nil, offset: 0)
                await self.updateAllMotors(allMotors)
            } catch {
                await self.setError("Ошибка загрузки моторов: \(error.localizedDescription)")
            }
        }
    }
    
    func loadMoreMotorsIfNeeded() {
        // Пагинация больше не нужна, так как все моторы загружены в память
        // Оставляем метод для совместимости, но он ничего не делает
    }

    func addManualMotor(
        brandName: String,
        engineCode: String,
        serialCode: String,
        configuration: String,
        notes: String,
        quantity: Int,
        transmission: String,
        arrivalDate: Date,
        soldDate: Date?
    ) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let brandID = try self.database.upsertBrand(name: brandName)
                let engineID = try self.database.upsertEngine(
                    brandID: brandID,
                    code: ImportNormalization.normalizeEngineCode(engineCode)
                )
                let motorID = try self.database.insertOrUpdateMotor(
                    engineID: engineID,
                    serialCode: serialCode,
                    configuration: configuration,
                    notes: notes,
                    quantity: quantity,
                    transmission: transmission,
                    arrivalDate: arrivalDate,
                    soldDate: soldDate
                )
                await self.registerAddUndo(motorID: motorID, serialCode: serialCode)
                await self.refreshAllOnMain()
                // refreshAll() уже обновляет allMotors
            } catch {
                await self.setError("Ошибка добавления мотора: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func registerAddUndo(motorID: Int64, serialCode: String) {
        undoManager.registerUndo(withTarget: self) { target in
            Task { @MainActor in
                do {
                    try target.database.deleteMotor(id: motorID)
                    target.undoManager.registerUndo(withTarget: target) { target in
                        target.refreshAll()
                    }
                    target.undoManager.setActionName("Добавить мотор")
                    target.refreshAll()
                } catch {
                    target.errorMessage = "Ошибка отмены: \(error.localizedDescription)"
                }
            }
        }
        undoManager.setActionName("Добавить мотор")
    }

    func updateMotorDetails(
        motorID: Int64,
        configuration: String,
        notes: String,
        quantity: Int,
        transmission: String,
        arrivalDate: Date,
        soldDate: Date?
    ) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let oldMotor = try await self.getMotor(id: motorID)
                try self.database.updateMotor(
                    id: motorID,
                    configuration: configuration,
                    notes: notes,
                    quantity: quantity,
                    transmission: transmission,
                    arrivalDate: arrivalDate,
                    soldDate: soldDate
                )
                if let oldMotor {
                    await self.registerEditUndo(
                        motorID: motorID,
                        oldMotor: oldMotor,
                        newConfiguration: configuration,
                        newNotes: notes,
                        newQuantity: quantity,
                        newTransmission: transmission,
                        newArrivalDate: arrivalDate,
                        newSoldDate: soldDate
                    )
                }
                if soldDate != nil {
                    await self.switchToSoldFilter()
                }
                await self.refreshAll()
                // refreshAll() уже обновляет allMotors
            } catch {
                await self.setError("Ошибка обновления мотора: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func registerEditUndo(
        motorID: Int64,
        oldMotor: Motor,
        newConfiguration: String,
        newNotes: String,
        newQuantity: Int,
        newTransmission: String,
        newArrivalDate: Date,
        newSoldDate: Date?
    ) {
        undoManager.registerUndo(withTarget: self) { target in
            Task { @MainActor in
                do {
                    try target.database.updateMotor(
                        id: motorID,
                        configuration: oldMotor.configuration,
                        notes: oldMotor.notes,
                        quantity: oldMotor.quantity,
                        transmission: oldMotor.transmission,
                        arrivalDate: oldMotor.arrivalDate,
                        soldDate: oldMotor.soldDate
                    )
                    target.undoManager.registerUndo(withTarget: target) { target in
                        Task { @MainActor in
                            try? target.database.updateMotor(
                                id: motorID,
                                configuration: newConfiguration,
                                notes: newNotes,
                                quantity: newQuantity,
                                transmission: newTransmission,
                                arrivalDate: newArrivalDate,
                                soldDate: newSoldDate
                            )
                            target.refreshAll()
                        }
                    }
                    target.undoManager.setActionName("Редактировать мотор")
                    target.refreshAll()
                } catch {
                    target.errorMessage = "Ошибка отмены: \(error.localizedDescription)"
                }
            }
        }
        undoManager.setActionName("Редактировать мотор")
    }

    // Метод больше не используется, так как фильтрация происходит через computed property
    // Оставляем для совместимости
    private func currentFilter() -> DatabaseService.MotorFilter {
        DatabaseService.MotorFilter(
            searchText: "",
            availability: .all,
            brandID: nil,
            engineID: nil
        )
    }

    private func observeFilters() {
        // Фильтры больше не требуют обновления БД, так как фильтрация происходит через computed property
        // Но нужно обновлять allMotors при изменении данных (добавление/редактирование)
        // Оставляем только для soldSearchText, serviceRecordsSearchText и searchText (для specific_records)
        
        let soldSearchPublisher = $soldSearchText
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates()
            .map { _ in () }
            .eraseToAnyPublisher()

        soldSearchPublisher
            .sink { [weak self] in
                self?.refreshSoldMotors()
            }
            .store(in: &cancellables)
        
        let serviceRecordsSearchPublisher = $serviceRecordsSearchText
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates()
            .map { _ in () }
            .eraseToAnyPublisher()
        
        serviceRecordsSearchPublisher
            .sink { [weak self] in
                guard let self = self else { return }
                if let category = self.selectedSection.categoryName {
                    self.refreshServiceRecords(category: category)
                }
            }
            .store(in: &cancellables)
        
        // Поиск в specific_records для отображения в основном списке
        let searchPublisher = $searchText
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates()
            .eraseToAnyPublisher()
        
        // Поиск в специфичных записях теперь происходит через filteredMotors
        // Не нужно отдельно загружать результаты поиска
    }

    func toggleSold(for motor: Motor) {
        let shouldSell = motor.soldDate == nil
        setSoldStatus(motorID: motor.id, sell: shouldSell)
    }

    func setSoldStatus(motorID: Int64, sell: Bool) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let motor = try await self.getMotor(id: motorID)
                let oldSoldDate = motor?.soldDate
                let newSoldDate = sell ? Date() : nil
                
                try self.database.updateSoldDate(
                    id: motorID,
                    soldDate: newSoldDate
                )
                
                await self.registerUndo(
                    actionName: sell ? "Продать мотор" : "Вернуть мотор в наличие",
                    motorID: motorID,
                    oldSoldDate: oldSoldDate,
                    newSoldDate: newSoldDate
                )
                
                if sell {
                    await self.switchToSoldFilter()
                }
                await self.refreshAll()
                // refreshAll() уже обновляет allMotors
            } catch {
                await self.setError("Ошибка обновления продажи: \(error.localizedDescription)")
            }
        }
    }
    
    private func getMotor(id: Int64) async throws -> Motor? {
        try await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return nil }
            return try self.database.fetchMotors(
                filter: DatabaseService.MotorFilter(),
                limit: nil,
                offset: 0
            ).first { $0.id == id }
        }.value
    }
    
    @MainActor
    private func registerUndo(actionName: String, motorID: Int64, oldSoldDate: Date?, newSoldDate: Date?) {
        undoManager.registerUndo(withTarget: self) { target in
            Task { @MainActor in
                do {
                    try target.database.updateSoldDate(id: motorID, soldDate: oldSoldDate)
                    target.undoManager.registerUndo(withTarget: target) { target in
                        Task { @MainActor in
                            try? target.database.updateSoldDate(id: motorID, soldDate: newSoldDate)
                            target.refreshAll()
                        }
                    }
                    target.undoManager.setActionName(actionName)
                    target.refreshAll()
                } catch {
                    target.errorMessage = "Ошибка отмены: \(error.localizedDescription)"
                }
            }
        }
        undoManager.setActionName(actionName)
    }
    
    @MainActor
    private func switchToSoldFilter() {
        availabilityFilter = .sold
    }

    @MainActor
    private func updateState(
        brands: [Brand],
        engines: [Engine],
        allMotors: [Motor],
        soldMotors: [Motor] = [],
        totalCount: Int = 0,
        totalSoldCount: Int = 0,
        allSpecificRecords: [DatabaseService.SpecificRecord] = []
    ) {
        self.brands = brands
        self.engines = engines
        self.allMotors = allMotors
        self.soldMotors = soldMotors
        self.totalMotorCount = totalCount
        self.totalSoldCount = totalSoldCount
        self.allSpecificRecords = allSpecificRecords
        self.isLoading = false
    }
    
    @MainActor
    private func updateAllMotors(_ motors: [Motor]) {
        self.allMotors = motors
        self.totalMotorCount = motors.count
        self.isLoading = false
    }
    
    @MainActor
    private func updateSoldMotors(_ motors: [Motor], totalCount: Int = 0) {
        self.soldMotors = motors
        self.totalSoldCount = totalCount
        self.isLoading = false
    }
    
    @MainActor
    private func appendSoldMotors(_ newMotors: [Motor]) {
        self.soldMotors.append(contentsOf: newMotors)
        self.isLoading = false
    }
    
    @MainActor
    private func setHasMoreSoldPages(_ value: Bool) {
        self.hasMoreSoldPages = value
    }
    
    func refreshServiceRecords(category: String) {
        let searchText = serviceRecordsSearchText
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                // Загружаем старые записи из service_records
                let serviceRecords = try self.database.fetchServiceRecords(category: category, searchText: searchText)
                let serviceCount = try self.database.countServiceRecords(category: category, searchText: searchText)
                
                // Загружаем новые записи из specific_records
                let specificRecords = try self.database.fetchSpecificRecordsByCategory(category: category, searchText: searchText)
                let specificCount = specificRecords.count
                
                // Получаем имена листов для specific_records
                let allSheets = try self.database.fetchAllSpecificSheets()
                let recordsWithSheetNames = specificRecords.map { record -> DatabaseService.SpecificRecord in
                    // Находим имя листа по sheetID
                    if let sheet = allSheets.first(where: { $0.id == record.sheetID }) {
                        // Добавляем имя листа в данные записи для отображения
                        var dataWithSheetName = record.data
                        dataWithSheetName["_SHEET_NAME"] = sheet.name
                        return DatabaseService.SpecificRecord(
                            id: record.id,
                            sheetID: record.sheetID,
                            rowIndex: record.rowIndex,
                            data: dataWithSheetName,
                            createdAt: record.createdAt
                        )
                    }
                    return record
                }
                
                await self.updateServiceRecords(
                    serviceRecords: serviceRecords,
                    specificRecords: recordsWithSheetNames,
                    totalCount: serviceCount + specificCount
                )
            } catch {
                await self.setError("Ошибка загрузки записей: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func updateServiceRecords(serviceRecords: [ServiceRecord], specificRecords: [DatabaseService.SpecificRecord], totalCount: Int = 0) {
        self.serviceRecords = serviceRecords
        self.specificRecords = specificRecords
        self.totalServiceRecordsCount = totalCount
        self.isLoading = false
    }

    @MainActor
    private func updateEngines(_ engines: [Engine]) {
        self.engines = engines
    }
    
    @MainActor
    private func setHasMorePages(_ value: Bool) {
        hasMorePages = value
    }

    @MainActor
    private func refreshAllOnMain() {
        refreshAll()
    }

    @MainActor
    private func setError(_ message: String) {
        errorMessage = message
        isLoading = false
    }
}
