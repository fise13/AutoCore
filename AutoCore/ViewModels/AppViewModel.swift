import Foundation
import SwiftUI
import Combine

// Импортируем EditableCellState из EditableCell.swift
// EditableCellState определен в EditableCell.swift

enum NavigationSection: Identifiable, Hashable {
    case all
    case sold
    case specificCategory(categoryID: Int64)
    
    var id: String {
        switch self {
        case .all:
            return "all"
        case .sold:
            return "sold"
        case .specificCategory(let categoryID):
            return "category_\(categoryID)"
        }
    }
    
    var title: String {
        switch self {
        case .all:
            return "Все моторы"
        case .sold:
            return "Проданные"
        case .specificCategory:
            return "" // Будет заполнено из категории
        }
    }
    
    var categoryID: Int64? {
        switch self {
        case .specificCategory(let categoryID):
            return categoryID
        default:
            return nil
        }
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
    @Published private(set) var specificRecords: [DatabaseService.SpecificRecord] = [] // Записи из specific_records для выбранной категории
    @Published private(set) var allSpecificRecords: [DatabaseService.SpecificRecord] = [] // ВСЕ специфичные записи для "Все моторы" и "Проданные"
    @Published private(set) var specificCategories: [DatabaseService.SpecificCategory] = [] // Динамические категории из БД
    @Published private(set) var totalMotorCount: Int = 0
    @Published private(set) var totalSoldCount: Int = 0
    @Published private(set) var totalServiceRecordsCount: Int = 0

    @Published var selectedSection: NavigationSection = .all
    @Published var selectedBrandID: Int64?
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
        
        // 4. Улучшенный поиск применяется ПОСЛЕ всех фильтров
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            let lowerSearch = trimmedSearch.lowercased()
            // Разбиваем поисковый запрос на слова для поиска по нескольким полям
            let searchTerms = lowerSearch.split(separator: " ").map { String($0) }
            
            result = result.filter { motor in
                // Поиск по всем полям одновременно
                let searchableText = [
                    motor.serialCode,
                    motor.engineCode,
                    motor.brandName,
                    motor.configuration,
                    motor.notes,
                    motor.transmission,
                    formatDate(motor.arrivalDate),
                    formatDate(motor.soldDate)
                ].joined(separator: " ").lowercased()
                
                // Все слова должны быть найдены (AND логика)
                return searchTerms.allSatisfy { term in
                    searchableText.contains(term)
                }
            }
            
            // 5. Добавляем специфичные записи ТОЛЬКО при поиске (если нет фильтров по бренду/двигателю)
            // НЕ добавляем их при фильтре "Проданные", так как у них нет soldDate
            if selectedBrandID == nil && selectedEngineID == nil && availabilityFilter != .sold {
                let recordsToShow = allSpecificRecords
                
                // Конвертируем в виртуальные моторы и фильтруем по поиску
                let virtualMotors = recordsToShow.compactMap { record -> Motor? in
                    // Ищем номер двигателя в данных
                    let serialCode = record.data["НОМЕР ДВИГАТЕЛЯ"] ?? 
                                   record.data["НОМЕР"] ?? 
                                   record.data["SERIAL"] ?? 
                                   record.data["SERIAL_CODE"] ??
                                   record.data.values.first ?? ""
                    
                    if serialCode.isEmpty { return nil }
                    
                    // Применяем поиск - проверяем, что запись соответствует поисковому запросу
                    let lowerSearch = trimmedSearch.lowercased()
                    let matchesSearch = serialCode.lowercased().contains(lowerSearch) ||
                                       record.data.values.contains { $0.lowercased().contains(lowerSearch) }
                    if !matchesSearch { return nil }
                    
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
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return Self.dateFormatter.string(from: date)
    }

    init(database: DatabaseService) {
        self.database = database
        undoManager.groupsByEvent = true
        observeFilters()
        refreshAll()
    }

    func refreshAll() {
        Task { @MainActor in
            isLoading = true
            currentPage = 0
            currentSoldPage = 0
            hasMorePages = true
            hasMoreSoldPages = true
        }
        
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
                let allRecords = try self.database.fetchAllSpecificRecords()
                // Загружаем категории для получения имён
                let categories = try self.database.fetchAllSpecificCategories()
                var categoryMap: [Int64: String] = [:]
                for category in categories {
                    categoryMap[category.id] = category.name
                }
                
                // Добавляем имя категории в данные для отображения
                let allSpecificRecords = allRecords.map { record -> DatabaseService.SpecificRecord in
                    var dataWithCategory = record.data
                    if let categoryName = categoryMap[record.categoryID] {
                        dataWithCategory["_CATEGORY_NAME"] = categoryName
                    }
                    return DatabaseService.SpecificRecord(
                        id: record.id,
                        categoryID: record.categoryID,
                        rowIndex: record.rowIndex,
                        data: dataWithCategory,
                        createdAt: record.createdAt
                    )
                }
                
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.updateState(
                        brands: brands,
                        engines: engines,
                        allMotors: allMotors,
                        soldMotors: soldMotors,
                        totalCount: totalCount,
                        totalSoldCount: totalSoldCount,
                        allSpecificRecords: allSpecificRecords,
                        categories: categories
                    )
                    self.setHasMorePages(false) // Все загружены в память
                    self.setHasMoreSoldPages(soldMotors.count >= self.pageSize)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка базы данных: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func refreshSoldMotors() {
        Task { @MainActor in
            currentSoldPage = 0
            hasMoreSoldPages = true
        }
        
        let searchText = soldSearchText
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                // Загружаем проданные моторы
                let soldFilter = DatabaseService.MotorFilter(searchText: searchText, availability: .sold)
                let soldMotors = try self.database.fetchMotors(filter: soldFilter, limit: self.pageSize, offset: 0)
                let totalCount = try self.database.countMotors(filter: soldFilter)
                
                // Специфичные записи НЕ добавляются в "Проданные" - только в поиск
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.updateSoldMotors(soldMotors, totalCount: totalCount)
                    self.setHasMoreSoldPages(soldMotors.count >= self.pageSize)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка загрузки проданных моторов: \(error.localizedDescription)")
                }
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
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.appendSoldMotors(newMotors)
                    self.setHasMoreSoldPages(newMotors.count >= self.pageSize)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка загрузки моторов: \(error.localizedDescription)")
                }
            }
        }
    }

    func refreshEngines() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let engines = try self.database.fetchEngines(brandID: nil)
                await MainActor.run { [weak self] in
                    self?.updateEngines(engines)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка загрузки двигателей: \(error.localizedDescription)")
                }
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
                await MainActor.run { [weak self] in
                    self?.updateAllMotors(allMotors)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка загрузки моторов: \(error.localizedDescription)")
                }
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
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.registerAddUndo(motorID: motorID, serialCode: serialCode)
                    self.refreshAllOnMain()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка добавления мотора: \(error.localizedDescription)")
                }
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
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if let oldMotor {
                        self.registerEditUndo(
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
                        self.switchToSoldFilter()
                    }
                    self.refreshAll()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка обновления мотора: \(error.localizedDescription)")
                }
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
        
        // Обработка изменения selectedBrandID: сброс selectedEngineID
        // Делаем это асинхронно через Combine, чтобы избежать изменения во время рендера
        $selectedBrandID
            .dropFirst() // Пропускаем начальное значение
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Сбрасываем selectedEngineID при изменении бренда на следующем цикле RunLoop,
                // чтобы не публиковать изменения во время обновления вью.
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if self.selectedEngineID != nil {
                        self.selectedEngineID = nil
                    }
                }
            }
            .store(in: &cancellables)
        
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
                if let categoryID = self.selectedSection.categoryID {
                    self.refreshServiceRecords(categoryID: categoryID)
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

    // MARK: - Intent Methods (для изменения состояния из Views)
    
    /// Установить фильтр наличия
    func setAvailabilityFilter(_ filter: MotorAvailabilityFilter) {
        availabilityFilter = filter
    }
    
    /// Установить текст поиска
    func setSearchText(_ text: String) {
        searchText = text
    }
    
    /// Установить текст поиска для проданных моторов
    func setSoldSearchText(_ text: String) {
        soldSearchText = text
    }
    
    /// Установить текст поиска для записей обслуживания
    func setServiceRecordsSearchText(_ text: String) {
        serviceRecordsSearchText = text
    }
    
    /// Установить выбранную секцию
    func setSelectedSection(_ section: NavigationSection) {
        selectedSection = section
    }
    
    /// Установить выбранный бренд
    func setSelectedBrandID(_ brandID: Int64?) {
        selectedBrandID = brandID
        // Сбрасываем engineID при изменении бренда
        if selectedEngineID != nil {
            selectedEngineID = nil
        }
    }
    
    /// Установить выбранный двигатель
    func setSelectedEngineID(_ engineID: Int64?) {
        selectedEngineID = engineID
    }
    
    /// Установить выбранный бренд и двигатель одновременно
    func setSelectedBrandAndEngine(brandID: Int64?, engineID: Int64?) {
        selectedBrandID = brandID
        selectedEngineID = engineID
    }
    
    /// Сбросить все фильтры
    func clearAllFilters() {
        selectedBrandID = nil
        selectedEngineID = nil
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
                
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.registerUndo(
                        actionName: sell ? "Продать мотор" : "Вернуть мотор в наличие",
                        motorID: motorID,
                        oldSoldDate: oldSoldDate,
                        newSoldDate: newSoldDate
                    )
                    
                    if sell {
                        self.switchToSoldFilter()
                    }
                    self.refreshAll()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка обновления продажи: \(error.localizedDescription)")
                }
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
        allSpecificRecords: [DatabaseService.SpecificRecord] = [],
        categories: [DatabaseService.SpecificCategory] = []
    ) {
        self.brands = brands
        self.engines = engines
        self.allMotors = allMotors
        self.soldMotors = soldMotors
        self.totalMotorCount = totalCount
        self.totalSoldCount = totalSoldCount
        self.allSpecificRecords = allSpecificRecords
        self.specificCategories = categories
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
    
    func refreshServiceRecords(categoryID: Int64) {
        let searchText = serviceRecordsSearchText
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                // Загружаем записи из specific_records по categoryID
                let specificRecords = try self.database.fetchSpecificRecordsByCategoryID(categoryID: categoryID, searchText: searchText)
                let specificCount = try self.database.countSpecificRecordsByCategoryID(categoryID: categoryID, searchText: searchText)

                // Получаем имя категории
                let category = try self.database.fetchSpecificCategory(id: categoryID)
                let recordsWithCategoryNames = specificRecords.map { record -> DatabaseService.SpecificRecord in
                    var dataWithCategory = record.data
                    if let categoryName = category?.name {
                        dataWithCategory["_CATEGORY_NAME"] = categoryName
                    }
                    return DatabaseService.SpecificRecord(
                        id: record.id,
                        categoryID: record.categoryID,
                        rowIndex: record.rowIndex,
                        data: dataWithCategory,
                        createdAt: record.createdAt
                    )
                }
                
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.updateServiceRecords(
                        specificRecords: recordsWithCategoryNames,
                        totalCount: specificCount
                    )
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка загрузки записей: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @MainActor
    private func updateServiceRecords(specificRecords: [DatabaseService.SpecificRecord], totalCount: Int = 0) {
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
    
    // MARK: - Inline Cell Editing
    
    func updateMotorCell(motorID: Int64, field: EditableCellState.EditableField, value: String) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                // Получаем текущий мотор для сохранения старого значения
                let oldMotor = try await self.getMotor(id: motorID)
                guard let oldMotor else { return }
                
                // Подготавливаем новые значения
                var newConfiguration = oldMotor.configuration
                var newNotes = oldMotor.notes
                var newQuantity = oldMotor.quantity
                var newTransmission = oldMotor.transmission
                var newArrivalDate = oldMotor.arrivalDate
                var newSoldDate = oldMotor.soldDate
                
                // Обновляем соответствующее поле
                switch field {
                case .serialCode:
                    // Серийный номер обычно не редактируется, но если нужно - можно добавить
                    return
                case .configuration:
                    newConfiguration = value
                case .notes:
                    newNotes = value
                case .quantity:
                    if let qty = Int(value), qty > 0 {
                        newQuantity = qty
                    } else {
                        return // Невалидное значение
                    }
                case .transmission:
                    newTransmission = value
                case .arrivalDate:
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let date = formatter.date(from: value) {
                        newArrivalDate = date
                    } else {
                        return // Невалидная дата
                    }
                case .soldDate:
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if value.isEmpty {
                        newSoldDate = nil
                    } else if let date = formatter.date(from: value) {
                        newSoldDate = date
                    } else {
                        return // Невалидная дата
                    }
                }
                
                // Сохраняем изменения
                try self.database.updateMotor(
                    id: motorID,
                    configuration: newConfiguration,
                    notes: newNotes,
                    quantity: newQuantity,
                    transmission: newTransmission,
                    arrivalDate: newArrivalDate,
                    soldDate: newSoldDate
                )
                
                // Регистрируем Undo
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.registerCellEditUndo(
                        motorID: motorID,
                        oldMotor: oldMotor,
                        newConfiguration: newConfiguration,
                        newNotes: newNotes,
                        newQuantity: newQuantity,
                        newTransmission: newTransmission,
                        newArrivalDate: newArrivalDate,
                        newSoldDate: newSoldDate
                    )
                    self.refreshAll()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка обновления: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @MainActor
    private func registerCellEditUndo(
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
                    target.undoManager.setActionName("Редактирование ячейки")
                    target.refreshAll()
                } catch {
                    target.errorMessage = "Ошибка отмены: \(error.localizedDescription)"
                }
            }
        }
        undoManager.setActionName("Редактирование ячейки")
    }
}
