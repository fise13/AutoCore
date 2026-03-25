//
//  IOSInvoiceEditView.swift
//  AutoCore
//
//  Редактирование распознанной накладной и подтверждение (Operation + InventoryMovement + Document).
//

import SwiftUI

#if os(iOS)

struct IOSInvoiceEditView: View {
    @Binding var invoice: ScannedInvoice
    let companyId: String
    let currentUserEmail: String
    var onDismiss: () -> Void
    
    @State private var items: [InvoiceItem] = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.groupingSeparator = " "
        return f
    }()
    
    var body: some View {
        ZStack {
            IOSScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.x3) {
                    Text("Проверьте данные и нажмите «Создать»")
                        .font(.subheadline)
                        .foregroundStyle(IOSPalette.textSecondary)
                    
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        invoiceItemRow(index: index, item: item)
                    }
                    
                    if items.isEmpty {
                        Text("Строки не распознаны. Добавьте вручную или выберите другое фото.")
                            .font(.subheadline)
                            .foregroundStyle(IOSPalette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    
                    Divider().overlay(IOSPalette.border)
                    
                    HStack {
                        Text("Итого")
                            .font(.headline)
                            .foregroundStyle(IOSPalette.textPrimary)
                        Spacer()
                        Text("\(currencyFormatter.string(from: totalAmount as NSDecimalNumber) ?? "0") ₸")
                            .font(.title2.bold())
                            .foregroundStyle(IOSPalette.flowlyBlue)
                    }
                    .padding(.vertical, 8)
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(IOSPalette.negative)
                    }
                }
                .padding(Spacing.x3)
            }
            .disabled(isSaving)
            
            if isSaving {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Создание операции…")
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
        .onAppear {
            if items.isEmpty {
                items = invoice.items
            }
        }
        .navigationTitle("Редактирование")
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
                Button("Создать") {
                    saveAndCreate()
                }
                .fontWeight(.semibold)
                .foregroundStyle(IOSPalette.flowlyBlue)
                .disabled(isSaving || items.isEmpty || totalAmount <= 0)
            }
        }
    }
    
    private var totalAmount: Decimal {
        items.reduce(0) { $0 + $1.total }
    }
    
    private func invoiceItemRow(index: Int, item: InvoiceItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Название", text: Binding(
                get: { item.name },
                set: { new in updateItem(at: index) { $0.name = new } }
            ))
            .textFieldStyle(.plain)
            .font(.subheadline)
            .padding(8)
            .background(IOSPalette.backgroundElevated)
            .cornerRadius(8)
            
            HStack(spacing: 12) {
                Text("Кол-во")
                    .font(.caption)
                    .foregroundStyle(IOSPalette.textSecondary)
                TextField("1", value: Binding(
                    get: { item.quantity },
                    set: { newVal in updateItem(at: index) { $0.quantity = newVal } }
                ), format: .number)
                .keyboardType(.decimalPad)
                .frame(width: 80)
                .padding(8)
                .background(IOSPalette.backgroundElevated)
                .cornerRadius(8)
                
                Text("Цена, ₸")
                    .font(.caption)
                    .foregroundStyle(IOSPalette.textSecondary)
                TextField("0", value: Binding(
                    get: { item.price },
                    set: { newVal in updateItem(at: index) { $0.price = newVal } }
                ), format: .number)
                .keyboardType(.decimalPad)
                .padding(8)
                .background(IOSPalette.backgroundElevated)
                .cornerRadius(8)
                
                Spacer()
                Text("\(currencyFormatter.string(from: item.total as NSDecimalNumber) ?? "0") ₸")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(IOSPalette.textPrimary)
            }
        }
        .padding(12)
        .background(IOSPalette.backgroundLayer)
        .cornerRadius(12)
    }
    
    private func updateItem(at index: Int, _ block: (inout InvoiceItem) -> Void) {
        guard index < items.count else { return }
        var copy = items[index]
        block(&copy)
        items[index] = copy
    }
    
    private func saveAndCreate() {
        let finalInvoice = ScannedInvoice(
            id: invoice.id,
            scannedAt: invoice.scannedAt,
            items: items,
            rawText: invoice.rawText
        )
        isSaving = true
        errorMessage = nil
        
        let confirmService = InvoiceScanConfirmService(
            financialSync: FirestoreFinancialSyncService(),
            inventoryRepository: FirestoreInventoryRepository(),
            movementRepository: FirestoreInventoryMovementRepository()
        )
        
        Task {
            do {
                try await confirmService.confirmInvoice(
                    companyId: companyId,
                    currentUserEmail: currentUserEmail,
                    invoice: finalInvoice
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
