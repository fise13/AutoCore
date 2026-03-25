//
//  IOSInvoiceScanFlowView.swift
//  AutoCore
//
//  Поток: выбор изображения → OCR → экран редактирования → подтверждение.
//

import SwiftUI
import PhotosUI

#if os(iOS)

struct IOSInvoiceScanFlowView: View {
    let companyId: String
    let currentUserEmail: String
    var onDismiss: () -> Void
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var scannedInvoice: ScannedInvoice?
    @State private var isScanning = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    private let scanner = InvoiceScannerService()
    
    var body: some View {
        NavigationStack {
            Group {
                if let invoice = scannedInvoice {
                    IOSInvoiceEditView(
                        invoice: Binding(
                            get: { invoice },
                            set: { scannedInvoice = $0 }
                        ),
                        companyId: companyId,
                        currentUserEmail: currentUserEmail,
                        onDismiss: {
                            onDismiss()
                            dismiss()
                        }
                    )
                } else {
                    scanSourceView
                }
            }
            .navigationTitle("Скан накладной")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundStyle(IOSPalette.flowlyBlue)
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                Task { await loadAndScan(from: newValue) }
            }
        }
    }
    
    private var scanSourceView: some View {
        ZStack {
            IOSScreenBackground()
            VStack(spacing: Spacing.x3) {
                if isScanning {
                    ProgressView("Распознавание текста…")
                        .tint(IOSPalette.flowlyBlue)
                    Spacer()
                } else {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Выбрать фото накладной", systemImage: "photo.on.rectangle.angled")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(IOSPalette.flowlyBlue)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    
                    Text("Или сделайте скриншот накладной и выберите его здесь")
                        .font(.caption)
                        .foregroundStyle(IOSPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(IOSPalette.negative)
                            .padding()
                    }
                }
            }
            .padding(Spacing.x3)
        }
    }
    
    private func loadAndScan(from item: PhotosPickerItem?) async {
        guard let item else { return }
        isScanning = true
        errorMessage = nil
        defer { isScanning = false }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                let invoice = await scanner.scanImage(image: image)
                await MainActor.run {
                    scannedInvoice = invoice
                }
            } else {
                await MainActor.run {
                    errorMessage = "Не удалось загрузить изображение"
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#endif
