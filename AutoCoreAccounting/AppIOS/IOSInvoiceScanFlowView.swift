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
    @StateObject private var viewModel = IOSInvoiceScanViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if let invoice = viewModel.scannedInvoice {
                    IOSInvoiceEditView(
                        invoice: Binding(
                            get: { invoice },
                            set: { viewModel.scannedInvoice = $0 }
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
                if viewModel.isLoading {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(IOSPalette.progressTrack, lineWidth: 10)
                                .frame(width: 110, height: 110)
                            Circle()
                                .trim(from: 0, to: max(0.02, min(1, viewModel.scanProgress)))
                                .stroke(
                                    IOSPalette.accentGradient,
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 110, height: 110)
                                .animation(IOSMotion.standard, value: viewModel.scanProgress)
                            Text("\(Int(max(0, min(1, viewModel.scanProgress)) * 100))%")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(IOSPalette.textPrimary)
                        }
                        Text(viewModel.scanStatus)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(IOSPalette.textPrimary)
                        Text("Можно свернуть экран и вернуться позже: результат сохранится в этой сессии.")
                            .font(.caption)
                            .foregroundStyle(IOSPalette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(Spacing.x3)
                    .frame(maxWidth: .infinity)
                    .background(IOSPalette.backgroundLayer)
                    .cornerRadius(20)
                    Spacer(minLength: 0)
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
                    
                    if let err = viewModel.errorMessage {
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
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await viewModel.processImage(image)
            } else {
                await MainActor.run { viewModel.errorMessage = "Не удалось загрузить изображение" }
            }
        } catch {
            await MainActor.run { viewModel.errorMessage = error.localizedDescription }
        }
    }
}

#endif
