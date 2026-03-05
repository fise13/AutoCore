import SwiftUI

struct AddIncomeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AccountingViewModel
    @FocusState private var focusedField: IncomeFormField?
    
    @State private var amount: String = ""
    @State private var selectedAccount: FinancialOperationEntity.Account = .cashbox
    @State private var selectedPaymentMethod: FinancialOperationEntity.PaymentMethod = .cash
    @State private var description: String = ""
    @State private var comment: String = ""
    @State private var errorMessage: String?
    
    private let createIncomeUseCase: CreateIncomeOperationUseCase
    private let onIncomeSaved: ((FinancialOperationEntity) async -> Void)?
    
    private enum IncomeFormField: Hashable {
        case amount, description, comment
    }
    
    init(viewModel: AccountingViewModel, createIncomeUseCase: CreateIncomeOperationUseCase, onIncomeSaved: ((FinancialOperationEntity) async -> Void)? = nil) {
        self.viewModel = viewModel
        self.createIncomeUseCase = createIncomeUseCase
        self.onIncomeSaved = onIncomeSaved
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    GlassCardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Сумма")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            HeroAmountInput(
                                amount: $amount,
                                focusedField: $focusedField,
                                focusValue: IncomeFormField.amount
                            )
                        }
                    }
                    
                    GlassCardContainer {
                        VStack(alignment: .leading, spacing: 20) {
                            PillSelector(
                                title: "Куда внести",
                                selection: $selectedAccount,
                                options: [
                                    (.cashbox, "Касса"),
                                    (.kaspi, "Каспи")
                                ],
                                onSelect: { new in
                                    if new == .kaspi { selectedPaymentMethod = .transfer }
                                }
                            )
                            
                            if selectedAccount == .kaspi {
                                HStack {
                                    Text("Перевод")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("(только для Каспи)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 4)
                            } else {
                                PillSelector(
                                    title: "Способ",
                                    selection: $selectedPaymentMethod,
                                    options: [
                                        (.cash, "Наличные"),
                                        (.transfer, "Перевод")
                                    ]
                                )
                            }
                        }
                    }
                    
                    GlassCardContainer {
                        FloatingTextField(
                            label: "Описание (необязательно)",
                            text: $description,
                            axis: .vertical,
                            lineLimit: 2...4,
                            focusedField: $focusedField,
                            focusValue: IncomeFormField.description
                        )
                    }
                    
                    GlassCardContainer {
                        FloatingTextField(
                            label: "Комментарий (необязательно)",
                            text: $comment,
                            axis: .vertical,
                            lineLimit: 2...4,
                            focusedField: $focusedField,
                            focusValue: IncomeFormField.comment
                        )
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    AnimatedConfirmButton(
                        title: "Подтвердить",
                        isEnabled: isValid,
                        action: createIncome
                    )
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .background { ZStack { FintechBackgroundView(); NoiseOverlay(opacity: 0.02) } }
            .navigationTitle("Добавить приход")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
        .frame(minWidth: 450, minHeight: 520)
        .preferredColorScheme(.dark)
    }
    
    private var isValid: Bool {
        Decimal(string: amount).map { $0 > 0 } ?? false
    }
    
    private func createIncome() {
        guard let amountValue = Decimal(string: amount), amountValue > 0 else {
            errorMessage = "Введите корректную сумму"
            return
        }
        errorMessage = nil
        
        Task { @MainActor in
            do {
                let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
                let savedOperation = try createIncomeUseCase.execute(
                    amount: amountValue,
                    paymentMethod: selectedPaymentMethod,
                    account: selectedAccount,
                    description: trimmedDescription,
                    comment: trimmedComment
                )
                if let onIncomeSaved = onIncomeSaved {
                    await onIncomeSaved(savedOperation)
                }
                viewModel.refreshAll()
                dismiss()
            } catch {
                errorMessage = "Ошибка: \(error.localizedDescription)"
            }
        }
    }
}
