import Foundation
import UIKit
import Combine
import UserNotifications

#if os(iOS)

@MainActor
final class IOSInvoiceScanViewModel: ObservableObject {
    @Published var scannedInvoice: ScannedInvoice?
    @Published var isLoading = false
    @Published var scanProgress: Double = 0
    @Published var scanStatus: String = "Готов к сканированию"
    @Published var errorMessage: String?

    private let scanner: InvoiceScannerService

    init(scanner: InvoiceScannerService = InvoiceScannerService()) {
        self.scanner = scanner
    }

    func processImage(_ image: UIImage) async {
        isLoading = true
        scanProgress = 0.05
        scanStatus = "Подготовка изображения…"
        errorMessage = nil
        let progressTask = Task { [weak self] in
            await self?.simulateProgress()
        }
        defer {
            progressTask.cancel()
            isLoading = false
        }
        do {
            scanStatus = "AI анализирует документ…"
            let invoice = try await scanner.scanImage(image: image)
            scannedInvoice = invoice
            scanProgress = 1.0
            let confidence = invoice.aiConfidence ?? 0
            scanStatus = confidence > 0 ? "Готово: \(Int((max(0, min(1, confidence))) * 100))%" : "Готово"
            await notifyCompletion(
                title: "Скан завершён",
                body: confidence > 0
                    ? "AI уверенность: \(Int((max(0, min(1, confidence))) * 100))%."
                    : "Проверьте распознанные данные перед сохранением."
            )
            if invoice.items.isEmpty {
                errorMessage = "AI не смог распознать позиции. Проверьте данные вручную."
            }
        } catch {
            errorMessage = error.localizedDescription
            scanProgress = 1.0
            scanStatus = "Нужна ручная проверка"
            scannedInvoice = ScannedInvoice(items: [], rawText: nil, aiWarnings: ["Не удалось извлечь данные автоматически."])
            await notifyCompletion(
                title: "Скан требует проверки",
                body: "AI не смог корректно извлечь все поля. Откройте предпросмотр и проверьте данные."
            )
        }
    }

    private func simulateProgress() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 130_000_000)
            await MainActor.run {
                guard isLoading else { return }
                if scanProgress < 0.88 {
                    scanProgress += 0.035
                } else {
                    scanProgress += 0.004
                }
                if scanProgress > 0.97 {
                    scanProgress = 0.97
                }
            }
        }
    }

    private func notifyCompletion(title: String, body: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        default:
            break
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "invoice-scan-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}

#endif
