//
//  IOSAddExpenseSheet.swift
//  AutoCore
//
//  Лист добавления расхода для iOS (бухгалтер).
//

import SwiftUI

#if os(iOS)

struct IOSAddExpenseSheet: View {
    let companyId: String
    @ObservedObject var viewModel: IOSAccountingViewModel
    var onDismiss: () -> Void
    
    @State private var amountText = ""
    @State private var selectedAccount: FinancialOperationEntity.Account = .cashbox
    @State private var categoryText = ""
    @State private var descriptionText = ""
    @State private var commentText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    private var amount: Decimal? {
        let cleaned = amountText.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleaned)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                IOSScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.x3) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Сумма, ₸")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(IOSPalette.textSecondary)
                            TextField("0", text: $amountText)
                                .keyboardType(.decimalPad)
                                .font(.title2.monospacedDigit())
                                .padding()
                                .background(IOSPalette.backgroundElevated)
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Счёт списания")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(IOSPalette.textSecondary)
                            HStack(spacing: 12) {
                                accountButton(.cashbox, title: "Касса")
                                accountButton(.kaspi, title: "Каспи")
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Категория (необязательно)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(IOSPalette.textSecondary)
                            TextField("Например: Аренда, Закупка", text: $categoryText)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(IOSPalette.backgroundElevated)
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Описание")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(IOSPalette.textSecondary)
                            TextField("На что потрачено", text: $descriptionText)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(IOSPalette.backgroundElevated)
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Комментарий (необязательно)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(IOSPalette.textSecondary)
                            TextField("", text: $commentText)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(IOSPalette.backgroundElevated)
                                .cornerRadius(12)
                        }
                        
                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(IOSPalette.negative)
                        }
                    }
                    .padding(Spacing.x3)
                }
            }
            .navigationTitle("Расход")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundStyle(IOSPalette.flowlyBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveExpense()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(IOSPalette.flowlyBlue)
                    .disabled(isSaving || amount == nil || (amount ?? 0) <= 0 || descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .disabled(isSaving)
        }
    }
    
    private func accountButton(_ account: FinancialOperationEntity.Account, title: String) -> some View {
        let isSelected = selectedAccount == account
        return Button {
            selectedAccount = account
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : IOSPalette.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? IOSPalette.flowlyBlue : IOSPalette.backgroundElevated)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func saveExpense() {
        guard let amt = amount, amt > 0 else {
            errorMessage = "Введите сумму больше нуля"
            return
        }
        let desc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty else {
            errorMessage = "Укажите описание расхода"
            return
        }
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await viewModel.pushExpense(
                    amount: amt,
                    account: selectedAccount,
                    category: categoryText.isEmpty ? nil : categoryText,
                    description: desc,
                    comment: commentText
                )
                await MainActor.run {
                    onDismiss()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

#endif
