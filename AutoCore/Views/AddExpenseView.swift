import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AccountingViewModel
    
    @State private var amount: String = ""
    @State private var selectedAccount: FinancialOperationEntity.Account = .cashbox
    @State private var selectedPaymentMethod: FinancialOperationEntity.PaymentMethod = .cash
    @State private var category: String = ""
    @State private var description: String = ""
    @State private var comment: String = ""
    @State private var errorMessage: String?
    @State private var recentCategories: [String] = []
    
    private let createExpenseUseCase: CreateExpenseOperationUseCase
    
    init(viewModel: AccountingViewModel, createExpenseUseCase: CreateExpenseOperationUseCase) {
        self.viewModel = viewModel
        self.createExpenseUseCase = createExpenseUseCase
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Сумма") {
                    HStack {
                        TextField("0", text: $amount)
                            .textFieldStyle(.plain)
                            .font(.system(size: 24, weight: .medium))
                        
                        Text("₸")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Откуда списать") {
                    Picker("Счёт", selection: $selectedAccount) {
                        Text("Касса").tag(FinancialOperationEntity.Account.cashbox)
                        Text("Каспи").tag(FinancialOperationEntity.Account.kaspi)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedAccount) { _, newAccount in
                        // Если выбран Каспи, автоматически устанавливаем способ оплаты "Перевод"
                        if newAccount == .kaspi {
                            selectedPaymentMethod = .transfer
                        }
                    }
                }
                
                Section("Способ оплаты") {
                    if selectedAccount == .kaspi {
                        // Для Каспи показываем только "Перевод" (read-only)
                        HStack {
                            Text("Перевод")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("(только для Каспи)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        // Для Кассы можно выбрать способ оплаты
                        Picker("Способ", selection: $selectedPaymentMethod) {
                            Text("Наличные").tag(FinancialOperationEntity.PaymentMethod.cash)
                            Text("Перевод").tag(FinancialOperationEntity.PaymentMethod.transfer)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                Section("Категория") {
                    TextField("Например: Зарплата, Аренда, Закупка...", text: $category)
                    
                    if !recentCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recentCategories, id: \.self) { cat in
                                    Button(cat) {
                                        category = cat
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section("Описание") {
                    TextField("Человекочитаемое описание расхода", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Комментарий (необязательно)") {
                    TextField("Дополнительная информация", text: $comment, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Добавить расход")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Подтвердить") {
                        createExpense()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadRecentCategories()
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    
    private var isValid: Bool {
        guard let amountValue = Decimal(string: amount), amountValue > 0 else {
            return false
        }
        return !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func loadRecentCategories() {
        Task.detached { [weak viewModel] in
            guard let viewModel = viewModel else { return }
            do {
                let filter = FinancialOperationFilter(
                    type: .expense,
                    account: nil,
                    relatedMotorID: nil,
                    fromDate: nil,
                    toDate: nil,
                    limit: 50,
                    offset: nil
                )
                let operations = try viewModel.financialOperationRepository.findAll(filter: filter)
                
                let categories = operations
                    .compactMap { $0.category }
                    .filter { !$0.isEmpty }
                
                // Получаем уникальные категории, отсортированные по частоте использования
                var categoryCounts: [String: Int] = [:]
                for cat in categories {
                    categoryCounts[cat, default: 0] += 1
                }
                
                let sortedCategories = Array(categoryCounts.keys)
                    .sorted { categoryCounts[$0] ?? 0 > categoryCounts[$1] ?? 0 }
                    .prefix(10)
                    .map { $0 }
                
                await MainActor.run {
                    self.recentCategories = Array(sortedCategories)
                }
            } catch {
                // Игнорируем ошибки загрузки категорий
            }
        }
    }
    
    private func createExpense() {
        guard let amountValue = Decimal(string: amount), amountValue > 0 else {
            errorMessage = "Введите корректную сумму"
            return
        }
        
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else {
            errorMessage = "Описание обязательно"
            return
        }
        
        errorMessage = nil
        
        Task { @MainActor in
            do {
                let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
                
                _ = try createExpenseUseCase.execute(
                    amount: amountValue,
                    paymentMethod: selectedPaymentMethod,
                    account: selectedAccount,
                    category: trimmedCategory.isEmpty ? nil : trimmedCategory,
                    description: trimmedDescription,
                    comment: trimmedComment
                )
                
                // Обновляем данные в ViewModel
                viewModel.refreshAll()
                
                dismiss()
            } catch {
                errorMessage = "Ошибка создания расхода: \(error.localizedDescription)"
            }
        }
    }
}

extension Decimal {
    init?(string: String) {
        let cleaned = string.replacingOccurrences(of: ",", with: ".")
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        guard let number = formatter.number(from: cleaned) else {
            return nil
        }
        self = number.decimalValue
    }
}
