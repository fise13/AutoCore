//
//  IOSInvoiceScanFlowView.swift
//  AutoCore
//
//  Поток: выбор изображения → OCR → экран редактирования → подтверждение.
//

import SwiftUI
import PhotosUI
import UIKit
import VisionKit

#if os(iOS)

struct IOSInvoiceScanFlowView: View {
    let companyId: String
    let currentUserEmail: String
    var onDismiss: () -> Void
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var capturedPhoto: UIImage?
    @State private var scannedDocumentImage: UIImage?
    @State private var isSourceDialogPresented = false
    @State private var isCameraPresented = false
    @State private var isDocumentScannerPresented = false
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
            .onChange(of: capturedPhoto) { _, image in
                guard let image else { return }
                Task { await viewModel.processImage(image) }
            }
            .onChange(of: scannedDocumentImage) { _, image in
                guard let image else { return }
                Task { await viewModel.processImage(image) }
            }
            .confirmationDialog(
                "Источник накладной",
                isPresented: $isSourceDialogPresented,
                titleVisibility: .visible
            ) {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Выбрать из фото", systemImage: "photo.on.rectangle.angled")
                }

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        isCameraPresented = true
                    } label: {
                        Label("Сделать фото", systemImage: "camera")
                    }

                    if VNDocumentCameraViewController.isSupported {
                        Button {
                            isDocumentScannerPresented = true
                        } label: {
                            Label("Сделать документ", systemImage: "doc.text.viewfinder")
                        }
                    }
                }

                Button("Отмена", role: .cancel) {}
            }
            .sheet(isPresented: $isCameraPresented) {
                IOSImageCameraSheet(image: $capturedPhoto)
            }
            .sheet(isPresented: $isDocumentScannerPresented) {
                IOSDocumentScannerSheet(image: $scannedDocumentImage)
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
                    Button {
                        isSourceDialogPresented = true
                    } label: {
                        Label("Добавить накладную", systemImage: "plus.viewfinder")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(IOSPalette.flowlyBlue)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    
                    Text("Можно выбрать фото, сделать фото камерой или скан документа через VisionKit")
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

private struct IOSImageCameraSheet: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: IOSImageCameraSheet

        init(parent: IOSImageCameraSheet) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
    }
}

private struct IOSDocumentScannerSheet: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: IOSDocumentScannerSheet

        init(parent: IOSDocumentScannerSheet) {
            self.parent = parent
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0 else {
                parent.dismiss()
                return
            }
            parent.image = scan.imageOfPage(at: 0)
            parent.dismiss()
        }
    }
}

#endif
