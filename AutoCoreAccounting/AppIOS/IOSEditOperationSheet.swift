//
//  IOSEditOperationSheet.swift
//  AutoCoreAccounting
//
//  Редактирование финансовой операции.
//

import SwiftUI

#if os(iOS)

struct IOSEditOperationSheet: View {
    let operation: FinancialOperation
    @ObservedObject var viewModel: IOSAccountingViewModel
    var onDismiss: () -> Void

    @State private var amountText: String
    @State private var selectedAccount: FinancialOperationEntity.Account
    @State private var categoryText: String
    @State private var descriptionText: String
    @State private var commentText: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(operation: FinancialOperation, viewModel: IOSAccountingViewModel, onDismiss: @escaping () -> Void) {
        self.operation = operation
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ""
        _amountText = State(initialValue: formatter.string(from: operation.amount as NSDecimalNumber) ?? "")
        _selectedAccount = State(initialValue: operation.account)
        _categoryText = State(initialValue: operation.category ?? "")
        _descriptionText = State(initialValue: operation.description)
        _commentText = State(initialValue: operation.comment)
    }

    private var amount: Decimal? {
        let cleaned = amountText.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleaned)
    }

    private var typeName: String {
        switch operation.type {
        case .sale: return "Продажа"
        case .income: return "Приход"
        case .expense: return "Расход"
        case .refund: return "Возврат"
        case .transfer: return "Перевод"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IOSScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.x3) {
                        typeInfo
                        amountField
                        accountSelector
                        if operation.type == .expense {
                            categoryField
                        }
                        descriptionField
                        commentField
                        if let err = errorMessage {
                            IOSStatusBanner(type: .error, message: err, onDismiss: { errorMessage = nil })
                        }
                    }
                    .padding(Spacing.x3)
                }
            }
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { onDismiss(); dismiss() }
                        .foregroundStyle(IOSPalette.flowlyBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(IOSPalette.flowlyBlue)
                    } else {
                        Button("Сохранить") { saveChanges() }
                            .fontWeight(.semibold)
                            .foregroundStyle(IOSPalette.flowlyBlue)
                            .disabled(amount == nil || (amount ?? 0) <= 0)
                    }
                }
            }
            .disabled(isSaving)
        }
    }

    private var typeInfo: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(IOSPalette.flowlyBlue)
            Text("Тип: \(typeName)")
                .font(IOSDesign.Typography.body.weight(.medium))
                .foregroundStyle(IOSPalette.textPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
                .fill(IOSPalette.flowlyBlueSubtle)
        )
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Сумма, ₸")
                .font(IOSDesign.Typography.caption)
                .foregroundStyle(IOSPalette.textSecondary)
            TextField("0", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(IOSPalette.textPrimary)
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

    private var accountSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Счёт")
                .font(IOSDesign.Typography.caption)
                .foregroundStyle(IOSPalette.textSecondary)
            HStack(spacing: 12) {
                accountBtn(.cashbox, title: "Касса", icon: "banknote.fill")
                accountBtn(.kaspi, title: "Каспи", icon: "creditcard.fill")
            }
        }
    }

    private func accountBtn(_ account: FinancialOperationEntity.Account, title: String, icon: String) -> some View {
        let isSelected = selectedAccount == account
        return Button {
            IOSHaptics.selection()
            withAnimation(IOSMotion.quick) { selectedAccount = account }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14, weight: .medium))
                Text(title).font(.subheadline.weight(.medium))
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

    private var categoryField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Категория")
                .font(IOSDesign.Typography.caption)
                .foregroundStyle(IOSPalette.textSecondary)
            TextField("Аренда, Закупка…", text: $categoryText)
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

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Описание")
                .font(IOSDesign.Typography.caption)
                .foregroundStyle(IOSPalette.textSecondary)
            TextField("Описание операции", text: $descriptionText)
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
            Text("Комментарий")
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

    private func saveChanges() {
        guard let amt = amount, amt > 0 else {
            errorMessage = "Введите сумму больше нуля"
            IOSHaptics.notification(.error)
            return
        }
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await viewModel.updateOperation(
                    operation,
                    newAmount: amt,
                    newAccount: selectedAccount,
                    newCategory: categoryText.isEmpty ? nil : categoryText,
                    newDescription: descriptionText,
                    newComment: commentText
                )
                IOSHaptics.notification(.success)
                await MainActor.run { onDismiss(); dismiss() }
            } catch {
                IOSHaptics.notification(.error)
                await MainActor.run { errorMessage = error.localizedDescription; isSaving = false }
            }
        }
    }
}

#endif
