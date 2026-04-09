//
//  IOSAddIncomeSheet.swift
//  AutoCore
//
//  Лист добавления прихода для iOS (бухгалтер).
//

import SwiftUI

#if os(iOS)

struct IOSAddIncomeSheet: View {
    let companyId: String
    @ObservedObject var viewModel: IOSAccountingViewModel
    var onDismiss: () -> Void
    
    @State private var amountText = ""
    @State private var selectedAccount: FinancialOperationEntity.Account = .cashbox
    @State private var descriptionText = ""
    @State private var commentText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var amountFocused: Bool
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
                        amountField
                        accountSelector
                        descriptionField
                        commentField
                        
                        if let err = errorMessage {
                            IOSStatusBanner(type: .error, message: err, onDismiss: { errorMessage = nil })
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(Spacing.x3)
                }
            }
            .navigationTitle("Приход")
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
                    if isSaving {
                        ProgressView()
                            .tint(IOSPalette.flowlyBlue)
                    } else {
                        Button("Сохранить") {
                            saveIncome()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(IOSPalette.flowlyBlue)
                        .disabled(amount == nil || (amount ?? 0) <= 0)
                    }
                }
            }
            .disabled(isSaving)
            .onAppear { amountFocused = true }
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Сумма, ₸")
                .font(IOSDesign.Typography.caption)
                .foregroundStyle(IOSPalette.textSecondary)
            TextField("0", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(IOSPalette.textPrimary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
                        .fill(IOSPalette.backgroundElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
                                .stroke(amountFocused ? IOSPalette.flowlyBlue.opacity(0.5) : IOSPalette.border, lineWidth: 1)
                        )
                )
                .focused($amountFocused)
        }
    }

    private var accountSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Куда внести")
                .font(IOSDesign.Typography.caption)
                .foregroundStyle(IOSPalette.textSecondary)
            HStack(spacing: 12) {
                accountButton(.cashbox, title: "Касса", icon: "banknote.fill")
                accountButton(.kaspi, title: "Каспи", icon: "creditcard.fill")
            }
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Описание (необязательно)")
                .font(IOSDesign.Typography.caption)
                .foregroundStyle(IOSPalette.textSecondary)
            TextField("Внесение средств", text: $descriptionText)
                .font(IOSDesign.Typography.body)
                .textFieldStyle(.plain)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
                        .fill(IOSPalette.backgroundElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
                                .stroke(IOSPalette.border, lineWidth: 1)
                        )
                )
        }
    }

    private var commentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Комментарий (необязательно)")
                .font(IOSDesign.Typography.caption)
                .foregroundStyle(IOSPalette.textSecondary)
            TextField("", text: $commentText)
                .font(IOSDesign.Typography.body)
                .textFieldStyle(.plain)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
                        .fill(IOSPalette.backgroundElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
                                .stroke(IOSPalette.border, lineWidth: 1)
                        )
                )
        }
    }
    
    private func accountButton(_ account: FinancialOperationEntity.Account, title: String, icon: String) -> some View {
        let isSelected = selectedAccount == account
        return Button {
            IOSHaptics.selection()
            withAnimation(IOSMotion.quick) {
                selectedAccount = account
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : IOSPalette.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
                    .fill(isSelected ? IOSPalette.flowlyBlue : IOSPalette.backgroundElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
                            .stroke(isSelected ? Color.clear : IOSPalette.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func saveIncome() {
        guard let amt = amount, amt > 0 else {
            errorMessage = "Введите сумму больше нуля"
            IOSHaptics.notification(.error)
            return
        }
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await viewModel.pushIncome(
                    amount: amt,
                    account: selectedAccount,
                    description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Внесение средств" : descriptionText,
                    comment: commentText
                )
                IOSHaptics.notification(.success)
                await MainActor.run {
                    onDismiss()
                    dismiss()
                }
            } catch {
                IOSHaptics.notification(.error)
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

#endif
