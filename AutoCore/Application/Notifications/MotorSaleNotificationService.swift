import Foundation

#if os(macOS)
import UserNotifications

final class MotorSaleNotificationService {
    static let shared = MotorSaleNotificationService()

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let dedupeKey = "autocore.seen.motor.sale.operation.ids"

    private init() {}

    func handleRemoteMotorEvent(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        guard let operationType = userInfo[RemoteMotorSyncUserInfoKey.operationType] as? String else { return }
        guard operationType == FinancialOperationEntity.OperationType.sale.rawValue else { return }
        guard let motorID = userInfo[RemoteMotorSyncUserInfoKey.motorID] as? Int64 else { return }

        let operationDocumentId = (userInfo[RemoteMotorSyncUserInfoKey.operationDocumentId] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !operationDocumentId.isEmpty else { return }
        guard markAsProcessedIfNeeded(operationDocumentId) else { return }

        let soldDate = userInfo[RemoteMotorSyncUserInfoKey.soldDate] as? Date
        let soldDateText = soldDate.map(Self.formatDate) ?? "сейчас"
        let message = "Мотор #\(motorID) продан (\(soldDateText))"

        NotificationCenter.default.post(
            name: .motorSaleBannerRequested,
            object: nil,
            userInfo: [MotorSaleBannerUserInfoKey.message: message]
        )

        Task { await showSystemNotification(message: message) }
    }

    private func showSystemNotification(message: String) async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        case .denied:
            return
        default:
            break
        }

        let content = UNMutableNotificationContent()
        content.title = "AutoCore"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "motor-sale-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    private func markAsProcessedIfNeeded(_ operationDocumentId: String) -> Bool {
        var ids = defaults.stringArray(forKey: dedupeKey) ?? []
        if ids.contains(operationDocumentId) {
            return false
        }
        ids.append(operationDocumentId)
        if ids.count > 200 {
            ids = Array(ids.suffix(200))
        }
        defaults.set(ids, forKey: dedupeKey)
        return true
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}
#endif
