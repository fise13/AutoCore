import Foundation
import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

@MainActor
final class WarehouseViewModel: ObservableObject {
    @Published private(set) var items: [InventoryItemEntity] = []
    @Published var searchText: String = ""
    @Published var selectedCategory: String = ""
    @Published var selectedItemID: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    let companyId: String

    private let inventoryRepository: InventoryRepository
    private let movementRepository: InventoryMovementRepository
    private let createInventoryItemUseCase: CreateInventoryItemUseCase
    private let addInventoryUseCase: AddInventoryUseCase
    private let removeInventoryUseCase: RemoveInventoryUseCase

    init(
        companyId: String,
        inventoryRepository: InventoryRepository,
        movementRepository: InventoryMovementRepository
    ) {
        self.companyId = companyId
        self.inventoryRepository = inventoryRepository
        self.movementRepository = movementRepository
        self.createInventoryItemUseCase = CreateInventoryItemUseCase(
            inventoryRepository: inventoryRepository,
            movementRepository: movementRepository
        )
        self.addInventoryUseCase = AddInventoryUseCase(
            inventoryRepository: inventoryRepository,
            movementRepository: movementRepository
        )
        self.removeInventoryUseCase = RemoveInventoryUseCase(
            inventoryRepository: inventoryRepository,
            movementRepository: movementRepository
        )
    }

    var filteredItems: [InventoryItemEntity] {
        items.filter { item in
            let categoryMatches = selectedCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                item.category.caseInsensitiveCompare(selectedCategory) == .orderedSame
            let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchMatches = search.isEmpty ||
                item.name.localizedCaseInsensitiveContains(search) ||
                item.partNumber.localizedCaseInsensitiveContains(search) ||
                item.category.localizedCaseInsensitiveContains(search)
            return categoryMatches && searchMatches
        }
    }

    var availableCategories: [String] {
        let unique = Set(items.map { $0.category }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        return unique.sorted()
    }

    func refresh() {
        let effectiveCompanyId = companyId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !effectiveCompanyId.isEmpty else {
            errorMessage = "Создайте компанию или присоединитесь по коду приглашения — тогда склад будет доступен."
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        Task {
            do {
                if let uid = Auth.auth().currentUser?.uid {
                    let db = Firestore.firestore()
                    do {
                        _ = try await db.collection("users").document(uid).getDocument()
                    } catch {
                        throw AppError.syncError(message: "Нет доступа к users/{uid}: \(error.localizedDescription)")
                    }
                }

                let filter = InventoryFilter(
                    searchText: nil,
                    category: nil
                )
                let loaded = try await inventoryRepository.findAll(companyId: companyId, filter: filter)
                self.items = loaded
                self.isLoading = false
            } catch {
                let baseMessage = Self.formatWarehouseError(error, companyId: self.companyId, context: .load)
                if error.localizedDescription.localizedCaseInsensitiveContains("permission") {
                    let debug = await Self.fetchPermissionDebugInfo(companyIdFromApp: self.companyId)
                    self.errorMessage = baseMessage + "\n\n--- Дебаг ---\n" + debug
                } else {
                    self.errorMessage = baseMessage
                }
                self.isLoading = false
            }
        }
    }

    /// При ошибке прав запрашивает users/{uid} с сервера и возвращает строку для дебага.
    private static func fetchPermissionDebugInfo(companyIdFromApp: String) async -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            return "uid: не авторизован"
        }
        do {
            let snap = try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .getDocument(source: .server)
            let exists = snap.exists
            let data = snap.data()
            let companyIdInDoc = (data?["companyId"] as? String) ?? "(нет поля или null)"
            let roleInDoc = (data?["role"] as? String) ?? "(нет)"
            let match = !companyIdFromApp.isEmpty && companyIdInDoc == companyIdFromApp
            return """
            uid: \(uid)
            В Firestore users/\(uid): exists=\(exists), companyId=\(companyIdInDoc), role=\(roleInDoc)
            Запрос склада с companyId: \(companyIdFromApp)
            Совпадение companyId: \(match ? "да" : "НЕТ — правила откажут")
            """
        } catch {
            return "uid: \(uid). Ошибка чтения users/\(uid): \(error.localizedDescription)"
        }
    }

    func createItem(_ input: WarehouseItemInput) {
        errorMessage = nil
        Task {
            do {
                _ = try await createInventoryItemUseCase.execute(
                    CreateInventoryItemDTO(
                        companyId: companyId,
                        name: input.name,
                        partNumber: input.partNumber,
                        category: input.category,
                        quantity: input.quantity,
                        buyPrice: input.buyPrice,
                        sellPrice: input.sellPrice,
                        comment: "Создание позиции"
                    )
                )
                refresh()
            } catch {
                errorMessage = Self.formatWarehouseError(error, companyId: companyId, context: .addItem)
            }
        }
    }

    func addInventory(itemId: String, quantity: Decimal, comment: String) {
        errorMessage = nil
        Task {
            do {
                _ = try await addInventoryUseCase.execute(
                    AddInventoryDTO(
                        companyId: companyId,
                        itemId: itemId,
                        quantity: quantity,
                        comment: comment
                    )
                )
                refresh()
            } catch {
                errorMessage = "Ошибка прихода: \(error.localizedDescription)"
            }
        }
    }

    func removeInventory(itemId: String, quantity: Decimal, comment: String) {
        errorMessage = nil
        Task {
            do {
                _ = try await removeInventoryUseCase.execute(
                    RemoveInventoryDTO(
                        companyId: companyId,
                        itemId: itemId,
                        quantity: quantity,
                        comment: comment
                    )
                )
                refresh()
            } catch {
                errorMessage = "Ошибка списания: \(error.localizedDescription)"
            }
        }
    }

    func deleteItem(itemId: String) {
        errorMessage = nil
        Task {
            do {
                try await inventoryRepository.delete(itemId)
                if selectedItemID == itemId {
                    selectedItemID = nil
                }
                refresh()
            } catch {
                errorMessage = "Ошибка удаления товара: \(error.localizedDescription)"
            }
        }
    }

    func importFromCSV(url: URL) {
        errorMessage = nil
        Task {
            do {
                let ext = url.pathExtension.lowercased()
                if ext == "xlsx" {
                    #if os(macOS)
                    let excelService = WarehouseExcelService()
                    let inputs = try excelService.importItems(from: url, companyId: companyId)
                    for input in inputs {
                        _ = try await createInventoryItemUseCase.execute(
                            CreateInventoryItemDTO(
                                companyId: companyId,
                                name: input.name,
                                partNumber: input.partNumber,
                                category: input.category,
                                quantity: input.quantity,
                                buyPrice: input.buyPrice,
                                sellPrice: input.sellPrice,
                                comment: "Импорт XLSX"
                            )
                        )
                    }
                    #else
                    throw AppError.importError(message: "Импорт XLSX доступен только на macOS")
                    #endif
                } else {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    let rows = content
                        .components(separatedBy: .newlines)
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                    guard rows.count > 1 else { return }
                    for row in rows.dropFirst() {
                        let columns = row.components(separatedBy: ",")
                        guard columns.count >= 6 else { continue }

                        let name = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let partNumber = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        let category = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                        let quantity = Decimal(string: columns[3].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                        let buyPrice = Decimal(string: columns[4].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                        let sellPrice = Decimal(string: columns[5].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

                        _ = try await createInventoryItemUseCase.execute(
                            CreateInventoryItemDTO(
                                companyId: companyId,
                                name: name,
                                partNumber: partNumber,
                                category: category,
                                quantity: quantity,
                                buyPrice: buyPrice,
                                sellPrice: sellPrice,
                                comment: "Импорт CSV"
                            )
                        )
                    }
                }

                refresh()
            } catch {
                errorMessage = Self.formatWarehouseError(error, companyId: companyId, context: .importItems)
            }
        }
    }

    func buildCSV() -> String {
        let header = "name,partNumber,category,quantity,buyPrice,sellPrice"
        let body = filteredItems.map { item in
            [
                escapeCSV(item.name),
                escapeCSV(item.partNumber),
                escapeCSV(item.category),
                "\(item.quantity)",
                "\(item.buyPrice)",
                "\(item.sellPrice)"
            ].joined(separator: ",")
        }
        return ([header] + body).joined(separator: "\n")
    }

    func exportToXLSX(url: URL) throws {
        #if os(macOS)
        let service = WarehouseExcelService()
        try service.export(items: filteredItems, to: url)
        #else
        throw AppError.exportError(message: "Экспорт XLSX доступен только на macOS")
        #endif
    }

    private func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    private enum WarehouseErrorContext {
        case load
        case addItem
        case importItems

        var actionPhrase: String {
            switch self {
            case .load: return "загрузить склад"
            case .addItem: return "добавить товар"
            case .importItems: return "импортировать данные склада"
            }
        }
    }

    /// Форматирует ошибку склада: понятный текст для пользователя и краткая техническая строка.
    private static func formatWarehouseError(_ error: Error, companyId: String, context: WarehouseErrorContext = .load) -> String {
        let raw = error.localizedDescription
        let action = context.actionPhrase
        let isPermission = raw.localizedCaseInsensitiveContains("permission") || raw.localizedCaseInsensitiveContains("permissions") || raw.localizedCaseInsensitiveContains("недостаточно")

        if isPermission {
            let hint: String
            if companyId.isEmpty {
                hint = "Создайте компанию или присоединитесь по коду приглашения в разделе онбординга."
            } else {
                hint = "Убедитесь, что в Firebase в документе users (ваш пользователь) заполнено поле companyId. Если компанию только что создали — выйдите из аккаунта и войдите снова или подождите несколько секунд и повторите действие."
            }
            return "Не удалось \(action): доступ к данным запрещён правилами Firebase.\n\n\(hint)\n\nТехнически: \(raw)"
        }

        if raw.localizedCaseInsensitiveContains("unauthenticated") || raw.localizedCaseInsensitiveContains("не авторизован") {
            return "Не удалось \(action): вы не авторизованы. Войдите в аккаунт заново.\n\nТехнически: \(raw)"
        }

        if raw.localizedCaseInsensitiveContains("companyId") && raw.localizedCaseInsensitiveContains("не задан") {
            return "Не удалось \(action): не определена компания. Создайте компанию или присоединитесь по коду приглашения.\n\nТехнически: \(raw)"
        }

        return "Ошибка (\(action)): \(raw)"
    }
}

struct WarehouseItemInput {
    let name: String
    let partNumber: String
    let category: String
    let quantity: Decimal
    let buyPrice: Decimal
    let sellPrice: Decimal
}
