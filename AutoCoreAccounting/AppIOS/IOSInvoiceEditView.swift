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
    @State private var invoiceType: InvoiceDocumentType = .expense
    @State private var documentKind: InvoiceDocumentKind = .invoice
    @State private var counterparty: String = ""
    @State private var requiresManualConfirmation = false
    @State private var manualConfirmed = false
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

                    Picker("Тип", selection: $invoiceType) {
                        ForEach(InvoiceDocumentType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Документ", selection: $documentKind) {
                        ForEach(InvoiceDocumentKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: documentKind) { _, newKind in
                        invoiceType = newKind.suggestedType
                    }

                    TextField("Контрагент", text: $counterparty)
                        .textFieldStyle(.roundedBorder)

                    qualityCard

                    if !invoice.aiWarnings.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(invoice.aiWarnings, id: \.self) { warning in
                                Label(warning, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(IOSPalette.houseOrange)
                            }
                        }
                        .padding(10)
                        .background(IOSPalette.houseOrange.opacity(0.1))
                        .cornerRadius(10)
                    }

                    if requiresManualConfirmation {
                        Toggle("Я проверил данные вручную", isOn: $manualConfirmed)
                            .font(.subheadline)
                    }
                    
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        invoiceItemRow(index: index, item: item)
                    }

                    if items.isEmpty {
                        Text("Строки не распознаны. Добавьте вручную.")
                            .font(.subheadline)
                            .foregroundStyle(IOSPalette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }

                    Button {
                        withAnimation(IOSMotion.standard) {
                            items.append(InvoiceItem(name: "", quantity: 1, price: 0))
                        }
                    } label: {
                        Label("Добавить строку", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(IOSPalette.flowlyBlue)
                    }

                    if let raw = invoice.rawText, !raw.isEmpty {
                        DisclosureGroup("Распознанный текст") {
                            Text(raw)
                                .font(.caption)
                                .foregroundStyle(IOSPalette.textSecondary)
                                .textSelection(.enabled)
                        }
                        .foregroundStyle(IOSPalette.textPrimary)
                        .padding(12)
                        .background(IOSPalette.backgroundElevated)
                        .cornerRadius(12)
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
            invoiceType = invoice.type
            documentKind = invoice.documentKind
            counterparty = invoice.counterparty ?? ""
            requiresManualConfirmation = (invoice.aiConfidence ?? 1) < 0.65
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
                .disabled(isSaving || items.isEmpty || totalAmount <= 0 || (requiresManualConfirmation && !manualConfirmed))
            }
        }
    }
    
    private var totalAmount: Decimal {
        items.reduce(0) { $0 + $1.total }
    }

    private var aiConfidencePercent: Int {
        Int((max(0, min(1, invoice.aiConfidence ?? 0))) * 100)
    }

    private var dataCoveragePercent: Int {
        var score = 0.0
        if !counterparty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 0.2 }
        if !items.isEmpty { score += 0.25 }
        let named = items.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        if !items.isEmpty {
            score += (Double(named) / Double(items.count)) * 0.25
        }
        let priced = items.filter { $0.price > 0 && $0.quantity > 0 }.count
        if !items.isEmpty {
            score += (Double(priced) / Double(items.count)) * 0.2
        }
        if totalAmount > 0 { score += 0.1 }
        return Int((max(0, min(1, score))) * 100)
    }

    private var totalsConsistencyPercent: Int {
        let sum = items.reduce(Decimal(0)) { $0 + $1.total }
        guard totalAmount > 0 else { return 0 }
        let diffDecimal = sum - totalAmount
        let diff = abs(NSDecimalNumber(decimal: diffDecimal).doubleValue)
        if diff <= 0.1 { return 100 }
        if diff <= 1.0 { return 90 }
        if diff <= 5.0 { return 70 }
        return 40
    }

    @ViewBuilder
    private var qualityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Качество распознавания")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(IOSPalette.textPrimary)
                Spacer()
                Text("\(aiConfidencePercent)%")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(aiConfidencePercent >= 75 ? IOSPalette.positive : IOSPalette.houseOrange)
            }
            IOSProgressBar(
                progress: Double(aiConfidencePercent) / 100,
                trackColor: IOSPalette.progressTrack,
                fillColor: aiConfidencePercent >= 75 ? IOSPalette.positive : IOSPalette.warning
            )
            .frame(height: 7)
            HStack(spacing: 8) {
                IOSTagChip(text: "Покрытие \(dataCoveragePercent)%", style: dataCoveragePercent >= 70 ? .positive : .warning)
                IOSTagChip(text: "Сходимость \(totalsConsistencyPercent)%", style: totalsConsistencyPercent >= 80 ? .positive : .warning)
            }
        }
        .padding(12)
        .background(IOSPalette.backgroundElevated)
        .cornerRadius(12)
    }
    
    private func invoiceItemRow(index: Int, item: InvoiceItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Название", text: Binding(
                    get: { item.name },
                    set: { new in updateItem(at: index) { $0.name = new } }
                ))
                .textFieldStyle(.plain)
                .font(.subheadline)

                Button {
                    withAnimation(IOSMotion.standard) {
                        if index < items.count { items.remove(at: index) }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(IOSPalette.textSecondary)
                }
            }
            .padding(8)
            .background(IOSPalette.backgroundElevated)
            .cornerRadius(8)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Кол-во").font(.caption2).foregroundStyle(IOSPalette.textSecondary)
                    TextField("1", value: Binding(
                        get: { item.quantity },
                        set: { newVal in updateItem(at: index) { $0.quantity = newVal } }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .font(.subheadline)
                    .padding(6)
                    .background(IOSPalette.backgroundElevated)
                    .cornerRadius(6)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Цена, ₸").font(.caption2).foregroundStyle(IOSPalette.textSecondary)
                    TextField("0", value: Binding(
                        get: { item.price },
                        set: { newVal in updateItem(at: index) { $0.price = newVal } }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .font(.subheadline)
                    .padding(6)
                    .background(IOSPalette.backgroundElevated)
                    .cornerRadius(6)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Итого").font(.caption2).foregroundStyle(IOSPalette.textSecondary)
                    Text("\(currencyFormatter.string(from: item.total as NSDecimalNumber) ?? "0") ₸")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(IOSPalette.textPrimary)
                        .padding(6)
                }
            }

            if documentKind == .invoice && invoiceType == .income {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Номер мотора (для продажи)")
                        .font(.caption2)
                        .foregroundStyle(IOSPalette.textSecondary)
                    TextField("Например: ABC12345", text: Binding(
                        get: { item.motorSerial ?? "" },
                        set: { newVal in
                            updateItem(at: index) { $0.motorSerial = newVal.trimmingCharacters(in: .whitespacesAndNewlines) }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                }
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
            type: invoiceType,
            documentKind: documentKind,
            counterparty: counterparty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : counterparty,
            items: items,
            rawText: invoice.rawText,
            aiWarnings: invoice.aiWarnings,
            aiConfidence: invoice.aiConfidence
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
