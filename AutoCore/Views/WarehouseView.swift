import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct WarehouseView: View {
    @StateObject private var viewModel: WarehouseViewModel
    @State private var isShowingCreateItem = false
    @State private var movementAction: MovementAction?
    @State private var itemPendingDelete: InventoryItemEntity?

    init(companyId: String) {
        _viewModel = StateObject(
            wrappedValue: WarehouseViewModel(
                companyId: companyId,
                inventoryRepository: FirestoreInventoryRepository(),
                movementRepository: FirestoreInventoryMovementRepository()
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Загрузка склада...")
                    Spacer()
                }
            } else if viewModel.filteredItems.isEmpty {
                EmptyStateView(
                    icon: "shippingbox",
                    title: "Склад пуст",
                    message: "Добавьте первый товар или импортируйте Excel/CSV файл",
                    actionTitle: "Добавить товар",
                    action: { isShowingCreateItem = true }
                )
            } else {
                inventoryTable
            }

            if let error = viewModel.errorMessage {
                Divider()
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .onAppear {
            viewModel.refresh()
        }
        .sheet(isPresented: $isShowingCreateItem) {
            WarehouseCreateItemSheet { input in
                viewModel.createItem(input)
                isShowingCreateItem = false
            }
        }
        .sheet(item: $movementAction) { action in
            WarehouseMovementSheet(action: action.kind) { quantity, comment in
                switch action.kind {
                case .income:
                    viewModel.addInventory(itemId: action.item.id, quantity: quantity, comment: comment)
                case .expense:
                    viewModel.removeInventory(itemId: action.item.id, quantity: quantity, comment: comment)
                }
                movementAction = nil
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            TextField("Поиск по названию, артикулу, категории...", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 360)

            Picker("Категория", selection: $viewModel.selectedCategory) {
                Text("Все").tag("")
                ForEach(viewModel.availableCategories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .frame(width: 200)

            Spacer()

            Button {
                isShowingCreateItem = true
            } label: {
                Label("Добавить", systemImage: "plus")
            }

            Button {
                openImportPanel()
            } label: {
                Label("Импорт", systemImage: "square.and.arrow.down")
            }

            Button {
                exportCSV()
            } label: {
                Label("Экспорт", systemImage: "square.and.arrow.up")
            }

            if let selectedItem = selectedItem {
                Button {
                    movementAction = MovementAction(item: selectedItem, kind: .income)
                } label: {
                    Label("Приход", systemImage: "plus.circle")
                }

                Button {
                    movementAction = MovementAction(item: selectedItem, kind: .expense)
                } label: {
                    Label("Списание", systemImage: "minus.circle")
                }

                Button(role: .destructive) {
                    itemPendingDelete = selectedItem
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            }
        }
        .padding(12)
    }

    private var inventoryTable: some View {
        Table(viewModel.filteredItems, selection: $viewModel.selectedItemID) {
            TableColumn("name") { item in
                Text(item.name)
            }
            .width(min: 180, ideal: 220)

            TableColumn("partNumber") { item in
                Text(item.partNumber)
            }
            .width(min: 120, ideal: 160)

            TableColumn("category") { item in
                Text(item.category)
            }
            .width(min: 120, ideal: 150)

            TableColumn("quantity") { item in
                Text("\(item.quantity)")
            }
            .width(min: 80, ideal: 100)

            TableColumn("buyPrice") { item in
                Text(formatCurrency(item.buyPrice))
            }
            .width(min: 100, ideal: 120)

            TableColumn("sellPrice") { item in
                Text(formatCurrency(item.sellPrice))
            }
            .width(min: 100, ideal: 120)
        }
        .contextMenu(forSelectionType: String.self) { selectedIds in
            if let id = selectedIds.first,
               let item = viewModel.filteredItems.first(where: { $0.id == id }) {
                Button(role: .destructive) {
                    itemPendingDelete = item
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Удалить товар?",
            isPresented: Binding(
                get: { itemPendingDelete != nil },
                set: { if !$0 { itemPendingDelete = nil } }
            ),
            presenting: itemPendingDelete
        ) { item in
            Button("Удалить", role: .destructive) {
                viewModel.deleteItem(itemId: item.id)
                itemPendingDelete = nil
            }
            Button("Отмена", role: .cancel) {
                itemPendingDelete = nil
            }
        } message: { item in
            Text("Товар \"\(item.name)\" будет удалён со склада.")
        }
    }

    private var selectedItem: InventoryItemEntity? {
        guard let id = viewModel.selectedItemID else { return nil }
        return viewModel.filteredItems.first(where: { $0.id == id })
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.currencySymbol = "₸"
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) ₸"
    }

    private func openImportPanel() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Импорт склада"
        panel.allowedContentTypes = [
            UTType.commaSeparatedText,
            UTType(filenameExtension: "csv"),
            UTType.spreadsheet,
            UTType(filenameExtension: "xlsx")
        ].compactMap { $0 }
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.importFromCSV(url: url)
        }
        #endif
    }

    private func exportCSV() {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.title = "Экспорт склада"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "xlsx"),
            UTType.commaSeparatedText
        ].compactMap { $0 }
        panel.nameFieldStringValue = "warehouse.xlsx"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let ext = url.pathExtension.lowercased()
            if ext == "csv" {
                try viewModel.buildCSV().write(to: url, atomically: true, encoding: .utf8)
            } else {
                try viewModel.exportToXLSX(url: url)
            }
        } catch {
            viewModel.errorMessage = "Ошибка экспорта склада: \(error.localizedDescription)"
        }
        #endif
    }
}

private struct WarehouseCreateItemSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var partNumber = ""
    @State private var category = ""
    @State private var quantity = "0"
    @State private var buyPrice = "0"
    @State private var sellPrice = "0"

    let onSave: (WarehouseItemInput) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Новый товар")
                .font(.headline)

            TextField("Название", text: $name)
            TextField("Артикул", text: $partNumber)
            TextField("Категория", text: $category)
            TextField("Количество", text: $quantity)
            TextField("Закупочная цена", text: $buyPrice)
            TextField("Цена продажи", text: $sellPrice)

            HStack {
                Spacer()
                Button("Отмена") { dismiss() }
                Button("Сохранить") {
                    onSave(
                        WarehouseItemInput(
                            name: name,
                            partNumber: partNumber,
                            category: category,
                            quantity: Decimal(string: quantity) ?? 0,
                            buyPrice: Decimal(string: buyPrice) ?? 0,
                            sellPrice: Decimal(string: sellPrice) ?? 0
                        )
                    )
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || partNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 420)
    }
}

private struct WarehouseMovementSheet: View {
    enum ActionKind: String {
        case income
        case expense

        var title: String {
            switch self {
            case .income: return "Приход"
            case .expense: return "Списание"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    let action: ActionKind
    let onSave: (Decimal, String) -> Void

    @State private var quantity: String = ""
    @State private var comment: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(action.title)
                .font(.headline)

            TextField("Количество", text: $quantity)
            TextField("Комментарий", text: $comment)

            HStack {
                Spacer()
                Button("Отмена") { dismiss() }
                Button("Подтвердить") {
                    onSave(Decimal(string: quantity) ?? 0, comment)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled((Decimal(string: quantity) ?? 0) <= 0)
            }
        }
        .padding(18)
        .frame(width: 360)
    }
}

private struct MovementAction: Identifiable {
    let id = UUID()
    let item: InventoryItemEntity
    let kind: WarehouseMovementSheet.ActionKind
}
