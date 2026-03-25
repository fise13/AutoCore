import Foundation
import SwiftUI
import Combine

// Импортируем EditableCellState из EditableCell.swift
// EditableCellState определен в EditableCell.swift

enum NavigationSection: Identifiable, Hashable {
    case all
    case sold
    case specificCategory(categoryID: Int64)
    case accounting
    case warehouse
    
    var id: String {
        switch self {
        case .all:
            return "all"
        case .sold:
            return "sold"
        case .specificCategory(let categoryID):
            return "category_\(categoryID)"
        case .accounting:
            return "accounting"
        case .warehouse:
            return "warehouse"
        }
    }
    
    var title: String {
        switch self {
        case .all:
            return L10n.Navigation.allMotors
        case .sold:
            return L10n.Navigation.sold
        case .specificCategory:
            return ""
        case .accounting:
            return L10n.Navigation.accounting
        case .warehouse:
            return L10n.Navigation.warehouse
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
    @Published private(set) var soldMotorPrices: [Int64: Decimal] = [:]  // Цены продажи по ID мотора
    @Published private(set) var serviceRecords: [ServiceRecord] = []
    @Published private(set) var specificRecords: [DatabaseService.SpecificRecord] = [] // Записи из specific_records для выбранной категории
    @Published private(set) var allSpecificRecords: [DatabaseService.SpecificRecord] = [] // ВСЕ специфичные записи для "Все моторы" и "Проданные" (deprecated - lazy loading)
    @Published private(set) var specificCategories: [DatabaseService.SpecificCategory] = [] // Динамические категории из БД
    @Published private(set) var motorSpecificRecords: [Int64: [DatabaseService.SpecificRecord]] = [:] // Кэш specific_records по motorID
    @Published private(set) var totalMotorCount: Int = 0
    @Published private(set) var totalSoldCount: Int = 0
    @Published private(set) var totalServiceRecordsCount: Int = 0

    @Published var selectedSection: NavigationSection = .all
    @Published var selectedBrandID: Int64?
    @Published var selectedEngineID: Int64?
    @Published var selectedMotorID: Int64?
    @Published var selectedMotorIDs: Set<Int64> = [] // Множественный выбор для batch операций

    @Published var searchText = ""
    @Published var soldSearchText = ""
    @Published var serviceRecordsSearchText = ""
    @Published var availabilityFilter: MotorAvailabilityFilter = .all
    
    // Financial operations
    @Published var isShowingSellMotorSheet = false
    @Published var motorToSell: Motor?
    @Published var isShowingRefundMotorSheet = false
    @Published var motorToRefund: Motor?
    
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
                        deletedAt: nil,
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
    
    // MARK: - Date Formatter (общий для производительности)
    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
    
    // MARK: - MotorRowDTO Conversion
    
    /// Преобразует массив Motor в MotorRowDTO с предварительным форматированием
    func convertToDTOs(motors: [Motor]) -> [MotorRowDTO] {
        motors.map { motor in
            MotorRowDTO.from(motor: motor, dateFormatter: Self.displayDateFormatter)
        }
    }

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

    @Published private(set) var recoveryState: RecoveryState?
    @Published var companyId: String = "default"
    private let motorRepository: MotorRepository
    private let firestoreCatalogSync = FirestoreCatalogSyncService()
    
    init(database: DatabaseService, recoveryState: RecoveryState? = nil) {
        self.database = database
        self.recoveryState = recoveryState
        self.motorRepository = MotorRepositoryImpl(database: database, companyId: "default")
        undoManager.groupsByEvent = true
        observeFilters()
        refreshAll()
    }

    func setCompanyId(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        companyId = normalized
        motorRepository.setCompanyId(normalized)
    }

    func refreshAll() {
        Task { @MainActor in
            isLoading = true
            currentPage = 0
            currentSoldPage = 0
            hasMorePages = true
            hasMoreSoldPages = true
        }
        
        let effectiveCompanyId = companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "default" : companyId
        var allFilter = DatabaseService.MotorFilter(availability: .all)
        allFilter.companyId = effectiveCompanyId
        var soldFilter = DatabaseService.MotorFilter(availability: .sold)
        soldFilter.companyId = effectiveCompanyId
        
        // Capture database before Task.detached to avoid main actor isolation warnings
        let database = self.database
        let pageSize = self.pageSize
        let companyId = self.companyId
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let brands = try database.fetchBrands()
                let engines = try database.fetchEngines(brandID: nil)
                let allMotors = try database.fetchMotors(filter: allFilter, limit: nil, offset: 0)
                let totalCount = allMotors.count
                let totalSoldCount = try database.countMotors(filter: soldFilter)
                let soldMotors = try database.fetchMotors(filter: soldFilter, limit: pageSize, offset: 0)
                
                // Загружаем цены продажи из финансовых операций
                let motorIDs = soldMotors.map { $0.id }
                var prices: [Int64: Decimal] = [:]
                
                if !motorIDs.isEmpty {
                    let effectiveCompanyId = companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "default" : companyId
                    let financialFilter = DatabaseService.FinancialOperationFilter(
                        type: .sale,
                        account: nil,
                        relatedMotorID: nil,
                        fromDate: nil,
                        toDate: nil,
                        limit: nil,
                        offset: nil,
                        companyId: effectiveCompanyId
                    )
                    let operations = try database.fetchFinancialOperations(filter: financialFilter)
                    
                    // Группируем по relatedMotorID и берём последнюю операцию продажи для каждого мотора
                    for motorID in motorIDs {
                        let motorOperations = operations.filter { (op: DatabaseService.FinancialOperation) in op.relatedMotorID == motorID }
                        let sortedOperations = motorOperations.sorted(by: { (op1: DatabaseService.FinancialOperation, op2: DatabaseService.FinancialOperation) in op1.createdAt > op2.createdAt })
                        if let saleOperation = sortedOperations.first {
                            prices[motorID] = saleOperation.amount
                        }
                    }
                }
                
                // Загружаем категории для получения имён
                let categories = try database.fetchAllSpecificCategories()
                
                // НЕ загружаем все specific_records при старте - используем lazy loading
                // Загружаем только при открытии карточки мотора
                let allSpecificRecords: [DatabaseService.SpecificRecord] = []
                
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
                    self.soldMotorPrices = prices
                    self.setHasMorePages(false) // Все загружены в память
                    self.setHasMoreSoldPages(soldMotors.count >= self.pageSize)
                }

                await self.firestoreCatalogSync.pushSnapshot(
                    companyId: companyId,
                    brands: brands,
                    engines: engines,
                    motors: allMotors
                )
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
        let database = self.database
        let pageSize = self.pageSize
        let companyId = self.companyId
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let effectiveCompanyId = companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "default" : companyId
                var soldFilter = DatabaseService.MotorFilter(searchText: searchText, availability: .sold)
                soldFilter.companyId = effectiveCompanyId
                let soldMotors = try database.fetchMotors(filter: soldFilter, limit: pageSize, offset: 0)
                let totalCount = try database.countMotors(filter: soldFilter)
                
                // Загружаем цены продажи из финансовых операций
                let motorIDs = soldMotors.map { $0.id }
                var prices: [Int64: Decimal] = [:]
                
                if !motorIDs.isEmpty {
                    let effectiveCompanyId = companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "default" : companyId
                    let financialFilter = DatabaseService.FinancialOperationFilter(
                        type: .sale,
                        account: nil,
                        relatedMotorID: nil,
                        fromDate: nil,
                        toDate: nil,
                        limit: nil,
                        offset: nil,
                        companyId: effectiveCompanyId
                    )
                    let operations = try database.fetchFinancialOperations(filter: financialFilter)
                    
                    // Группируем по relatedMotorID и берём последнюю операцию продажи для каждого мотора
                    for motorID in motorIDs {
                        let motorOperations = operations.filter { (op: DatabaseService.FinancialOperation) in op.relatedMotorID == motorID }
                        let sortedOperations = motorOperations.sorted(by: { (op1: DatabaseService.FinancialOperation, op2: DatabaseService.FinancialOperation) in op1.createdAt > op2.createdAt })
                        if let saleOperation = sortedOperations.first {
                            prices[motorID] = saleOperation.amount
                        }
                    }
                }
                
                // Специфичные записи НЕ добавляются в "Проданные" - только в поиск
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.updateSoldMotors(soldMotors, totalCount: totalCount, prices: prices)
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
        let database = self.database
        let pageSize = self.pageSize
        let companyId = self.companyId
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let effectiveCompanyId = companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "default" : companyId
                var filter = DatabaseService.MotorFilter(searchText: searchText, availability: .sold)
                filter.companyId = effectiveCompanyId
                let offset = page * pageSize
                let newMotors = try database.fetchMotors(filter: filter, limit: pageSize, offset: offset)
                
                // Загружаем цены продажи для новых моторов
                let motorIDs = newMotors.map { $0.id }
                var prices: [Int64: Decimal] = [:]
                
                if !motorIDs.isEmpty {
                    let financialFilter = DatabaseService.FinancialOperationFilter(
                        type: .sale,
                        account: nil,
                        relatedMotorID: nil,
                        fromDate: nil,
                        toDate: nil,
                        limit: nil,
                        offset: nil,
                        companyId: effectiveCompanyId
                    )
                    let operations = try database.fetchFinancialOperations(filter: financialFilter)
                    
                    // Группируем по relatedMotorID и берём последнюю операцию продажи для каждого мотора
                    for motorID in motorIDs {
                        let motorOperations = operations.filter { (op: DatabaseService.FinancialOperation) in op.relatedMotorID == motorID }
                        let sortedOperations = motorOperations.sorted(by: { (op1: DatabaseService.FinancialOperation, op2: DatabaseService.FinancialOperation) in op1.createdAt > op2.createdAt })
                        if let saleOperation = sortedOperations.first {
                            prices[motorID] = saleOperation.amount
                        }
                    }
                }
                
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.appendSoldMotors(newMotors, prices: prices)
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
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let engines = try database.fetchEngines(brandID: nil)
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
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let allFilter = DatabaseService.MotorFilter(availability: .all)
                let allMotors = try database.fetchMotors(filter: allFilter, limit: nil, offset: 0)
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
        let database = self.database
        let companyId = self.companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "default" : self.companyId
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let brandID = try database.upsertBrand(name: brandName)
                let engineID = try database.upsertEngine(
                    brandID: brandID,
                    code: ImportNormalization.normalizeEngineCode(engineCode)
                )
                let motorID = try database.insertOrUpdateMotor(
                    engineID: engineID,
                    serialCode: serialCode,
                    configuration: configuration,
                    notes: notes,
                    quantity: quantity,
                    transmission: transmission,
                    arrivalDate: arrivalDate,
                    soldDate: soldDate,
                    companyId: companyId
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
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let oldMotor = try await self.getMotor(id: motorID)
                try database.updateMotor(
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
        // Открываем модальное окно для продажи с финансовыми данными
        motorToSell = motor
        isShowingSellMotorSheet = true
    }
    
    func sellMotorWithFinancialOperation(
        motorID: Int64,
        saleAmount: Decimal,
        paymentMethod: FinancialOperationEntity.PaymentMethod,
        cashReceived: Decimal?,
        account: FinancialOperationEntity.Account,
        comment: String,
        currentUser: String,
        companyId: String
    ) {
        let database = self.database
        let motorRepository = self.motorRepository
        let recoveryState = self.recoveryState
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let useCase = SellMotorWithFinancialOperationUseCase(
                    database: database,
                    motorRepository: motorRepository,
                    recoveryState: recoveryState,
                    currentUser: currentUser,
                    companyId: companyId
                )
                
                let result = try await useCase.execute(
                    motorID: motorID,
                    soldDate: Date(),
                    saleAmount: saleAmount,
                    paymentMethod: paymentMethod,
                    cashReceived: cashReceived,
                    account: account,
                    comment: comment
                )
                
                // Обновляем цену продажи для этого мотора
                self.soldMotorPrices[motorID] = saleAmount
                
                self.isShowingSellMotorSheet = false
                self.motorToSell = nil
                self.switchToSoldFilter()
                self.refreshAll()
            } catch {
                self.setError("Ошибка продажи: \(error.localizedDescription)")
                self.isShowingSellMotorSheet = false
            }
        }
    }

    func setSoldStatus(motorID: Int64, sell: Bool) {
        if sell {
            // Продажа - открываем модальное окно с финансовыми данными
            if let motor = allMotors.first(where: { $0.id == motorID }) {
                motorToSell = motor
                isShowingSellMotorSheet = true
            }
        } else {
            // Возврат - открываем модальное окно возврата с финансовыми данными
            if let motor = allMotors.first(where: { $0.id == motorID }) {
                motorToRefund = motor
                isShowingRefundMotorSheet = true
            }
        }
    }
    
    func refundMotorWithFinancialOperation(
        motorID: Int64,
        refundAmount: Decimal,
        paymentMethod: FinancialOperationEntity.PaymentMethod,
        cashReceived: Decimal?,
        account: FinancialOperationEntity.Account,
        comment: String,
        currentUser: String,
        companyId: String
    ) {
        let database = self.database
        let motorRepository = self.motorRepository
        let recoveryState = self.recoveryState
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let useCase = UnsellMotorWithFinancialOperationUseCase(
                    database: database,
                    motorRepository: motorRepository,
                    recoveryState: recoveryState,
                    currentUser: currentUser,
                    companyId: companyId
                )
                
                let result = try await useCase.execute(
                    motorID: motorID,
                    refundAmount: refundAmount,
                    paymentMethod: paymentMethod,
                    cashReceived: cashReceived,
                    account: account,
                    comment: comment
                )
                
                self.isShowingRefundMotorSheet = false
                self.motorToRefund = nil
                self.refreshAll()
            } catch {
                self.setError("Ошибка возврата: \(error.localizedDescription)")
                self.isShowingRefundMotorSheet = false
            }
        }
    }
    
    private func getMotor(id: Int64) async throws -> Motor? {
        let database = self.database
        return try await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return nil }
            return try database.fetchMotors(
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
    
    /// Загрузить specific_records для мотора (lazy loading)
    func loadSpecificRecordsForMotor(motorID: Int64, serialCode: String) {
        // Проверяем кэш
        if motorSpecificRecords[motorID] != nil {
            return // Уже загружено
        }
        
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                // Загружаем specific_records по serial_code
                let records = try database.fetchSpecificRecordsBySerialCode(serialCode: serialCode)
                
                // Загружаем категории для получения имён
                let categories = try database.fetchAllSpecificCategories()
                var categoryMap: [Int64: String] = [:]
                for category in categories {
                    categoryMap[category.id] = category.name
                }
                
                // Добавляем имя категории в данные
                let recordsWithCategory = records.map { record -> DatabaseService.SpecificRecord in
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
                    self.motorSpecificRecords[motorID] = recordsWithCategory
                }
            } catch {
                // Игнорируем ошибки загрузки - это не критично
                print("Failed to load specific records for motor \(motorID): \(error)")
            }
        }
    }
    
    /// Получить specific_records для мотора из кэша
    func getSpecificRecordsForMotor(motorID: Int64) -> [DatabaseService.SpecificRecord] {
        return motorSpecificRecords[motorID] ?? []
    }
    
    // MARK: - Batch Operations
    
    /// Массовая продажа моторов
    func batchSellMotors(motorIDs: [Int64], soldDate: Date = Date()) {
        guard !motorIDs.isEmpty else { return }
        
        // Сохраняем состояние для Undo
        let oldStates = motorIDs.compactMap { id -> (Int64, Date?)? in
            if let motor = allMotors.first(where: { $0.id == id }) {
                return (id, motor.soldDate)
            }
            return nil
        }
        
        let useCase = BatchSellMotorsUseCase(
            motorRepository: motorRepository,
            recoveryState: recoveryState
        )
        
        do {
            let result = try useCase.execute(motorIDs: motorIDs, soldDate: soldDate)
            
            // Регистрируем Undo
            registerBatchUndo(
                actionName: "Массовая продажа",
                motorIDs: result.successIDs,
                oldStates: oldStates,
                restoreAction: { [weak self] ids, states in
                    guard let self = self else { return }
                    let unsellUseCase = BatchUnsellMotorsUseCase(
                        motorRepository: self.motorRepository,
                        recoveryState: self.recoveryState
                    )
                    // Возвращаем только те, которые были проданы
                    let toUnsell = ids.filter { id in
                        states.first(where: { $0.0 == id })?.1 == nil
                    }
                    _ = try? unsellUseCase.execute(motorIDs: toUnsell) // Результат не используется, но нужно обработать ошибку
                }
            )
            
            refreshAll()
            
            if result.hasPartialSuccess {
                errorMessage = "Продано \(result.successIDs.count) из \(motorIDs.count) моторов"
            } else if !result.errors.isEmpty {
                errorMessage = result.errors.joined(separator: "\n")
            }
            
            // Очищаем выбор
            selectedMotorIDs.removeAll()
            
        } catch {
            errorMessage = "Ошибка массовой продажи: \(error.localizedDescription)"
        }
    }
    
    /// Массовый возврат моторов в наличие
    func batchUnsellMotors(motorIDs: [Int64]) {
        guard !motorIDs.isEmpty else { return }
        
        // Сохраняем состояние для Undo
        let oldStates = motorIDs.compactMap { id -> (Int64, Date?)? in
            if let motor = allMotors.first(where: { $0.id == id }) {
                return (id, motor.soldDate)
            }
            return nil
        }
        
        let useCase = BatchUnsellMotorsUseCase(
            motorRepository: motorRepository,
            recoveryState: recoveryState
        )
        
        do {
            let result = try useCase.execute(motorIDs: motorIDs)
            
            // Регистрируем Undo
            registerBatchUndo(
                actionName: "Массовый возврат",
                motorIDs: result.successIDs,
                oldStates: oldStates,
                restoreAction: { [weak self] ids, states in
                    guard let self = self else { return }
                    let sellUseCase = BatchSellMotorsUseCase(
                        motorRepository: self.motorRepository,
                        recoveryState: self.recoveryState
                    )
                    // Продаем только те, которые были проданы
                    for (id, soldDate) in states {
                        if let date = soldDate {
                            _ = try? sellUseCase.execute(motorIDs: [id], soldDate: date) // Результат не используется, но нужно обработать ошибку
                        }
                    }
                }
            )
            
            refreshAll()
            
            if result.hasPartialSuccess {
                errorMessage = "Возвращено \(result.successIDs.count) из \(motorIDs.count) моторов"
            } else if !result.errors.isEmpty {
                errorMessage = result.errors.joined(separator: "\n")
            }
            
            // Очищаем выбор
            selectedMotorIDs.removeAll()
            
        } catch {
            errorMessage = "Ошибка массового возврата: \(error.localizedDescription)"
        }
    }
    
    /// Массовое добавление заметки
    func batchAddNote(motorIDs: [Int64], note: String, append: Bool = true) {
        guard !motorIDs.isEmpty else { return }
        guard !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Сохраняем старые заметки для Undo
        let oldNotes = motorIDs.compactMap { id -> (Int64, String)? in
            if let motor = allMotors.first(where: { $0.id == id }) {
                return (id, motor.notes)
            }
            return nil
        }
        
        let useCase = BatchAddNoteUseCase(
            motorRepository: motorRepository,
            recoveryState: recoveryState
        )
        
        do {
            let result = try useCase.execute(motorIDs: motorIDs, note: note, append: append)
            
            // Регистрируем Undo
            registerBatchNoteUndo(
                actionName: "Массовое добавление заметки",
                motorIDs: result.successIDs,
                oldNotes: oldNotes
            )
            
            refreshAll()
            
            if result.hasPartialSuccess {
                errorMessage = "Заметка добавлена к \(result.successIDs.count) из \(motorIDs.count) моторов"
            } else if !result.errors.isEmpty {
                errorMessage = result.errors.joined(separator: "\n")
            }
            
            // Очищаем выбор
            selectedMotorIDs.removeAll()
            
        } catch {
            errorMessage = "Ошибка добавления заметки: \(error.localizedDescription)"
        }
    }
    
    /// Регистрация Undo для batch операций
    @MainActor
    private func registerBatchUndo(
        actionName: String,
        motorIDs: [Int64],
        oldStates: [(Int64, Date?)],
        restoreAction: @escaping ([Int64], [(Int64, Date?)]) -> Void
    ) {
        undoManager.registerUndo(withTarget: self) { target in
            restoreAction(motorIDs, oldStates)
            target.undoManager.registerUndo(withTarget: target) { target in
                // Redo - повторяем операцию
                // Это упрощенная версия, в реальности нужно сохранить параметры операции
            }
            target.undoManager.setActionName(actionName)
            target.refreshAll()
        }
        undoManager.setActionName(actionName)
    }
    
    /// Регистрация Undo для batch добавления заметки
    @MainActor
    private func registerBatchNoteUndo(
        actionName: String,
        motorIDs: [Int64],
        oldNotes: [(Int64, String)]
    ) {
        undoManager.registerUndo(withTarget: self) { target in
            Task { @MainActor in
                for (id, oldNote) in oldNotes {
                    if let motor = try? target.motorRepository.findByID(id) {
                        var updatedMotor = motor
                        updatedMotor.notes = oldNote
                        updatedMotor.updatedAt = Date()
                        try? target.motorRepository.save(updatedMotor)
                    }
                }
                target.undoManager.registerUndo(withTarget: target) { _ in
                    // Redo - упрощенная версия
                }
                target.undoManager.setActionName(actionName)
                target.refreshAll()
            }
        }
        undoManager.setActionName(actionName)
    }
    
    @MainActor
    private func updateAllMotors(_ motors: [Motor]) {
        self.allMotors = motors
        self.totalMotorCount = motors.count
        self.isLoading = false
    }
    
    @MainActor
    private func updateSoldMotors(_ motors: [Motor], totalCount: Int = 0, prices: [Int64: Decimal] = [:]) {
        self.soldMotors = motors
        self.totalSoldCount = totalCount
        self.soldMotorPrices = prices
        self.isLoading = false
    }
    
    @MainActor
    private func appendSoldMotors(_ newMotors: [Motor], prices: [Int64: Decimal] = [:]) {
        self.soldMotors.append(contentsOf: newMotors)
        self.soldMotorPrices.merge(prices) { (_, new) in new }
        self.isLoading = false
    }
    
    @MainActor
    private func setHasMoreSoldPages(_ value: Bool) {
        self.hasMoreSoldPages = value
    }
    
    func refreshServiceRecords(categoryID: Int64) {
        let searchText = serviceRecordsSearchText
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                // Загружаем записи из specific_records по categoryID
                let specificRecords = try database.fetchSpecificRecordsByCategoryID(categoryID: categoryID, searchText: searchText)
                let specificCount = try database.countSpecificRecordsByCategoryID(categoryID: categoryID, searchText: searchText)

                // Получаем имя категории
                let category = try database.fetchSpecificCategory(id: categoryID)
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
    
    // Обновление ячейки специфичной записи
    @MainActor
    func updateSpecificRecordCell(recordID: Int64, fieldKey: String, value: String) {
        let database = self.database
        let specificRecords = self.specificRecords
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                // Находим запись (получаем из захваченного массива)
                guard let record = specificRecords.first(where: { $0.id == recordID }) else { return }
                
                // Обновляем данные
                var updatedData = record.data
                updatedData[fieldKey] = value
                
                // Сериализуем в JSON
                let jsonData = try JSONSerialization.data(withJSONObject: updatedData, options: [])
                guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
                
                // Сохраняем в БД
                try await database.updateSpecificRecord(id: recordID, dataJSON: jsonString)
                
                // Обновляем локальные данные
                await MainActor.run {
                    if let index = self.specificRecords.firstIndex(where: { $0.id == recordID }) {
                        var updatedRecordData = record.data
                        updatedRecordData[fieldKey] = value
                        let updatedRecord = DatabaseService.SpecificRecord(
                            id: record.id,
                            categoryID: record.categoryID,
                            rowIndex: record.rowIndex,
                            data: updatedRecordData,
                            createdAt: record.createdAt
                        )
                        self.specificRecords[index] = updatedRecord
                    }
                }
            } catch {
                await MainActor.run {
                    self.setError("Ошибка обновления записи: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func updateMotorCell(motorID: Int64, field: EditableCellState.EditableField, value: String) {
        let database = self.database
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
                try database.updateMotor(
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
