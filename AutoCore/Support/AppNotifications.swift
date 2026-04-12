import Foundation

extension Notification.Name {
    static let motorGridSaveRequested = Notification.Name("MotorGridSaveRequested")
    static let motorGridUnsavedChangesChanged = Notification.Name("MotorGridUnsavedChangesChanged")
    static let remoteMotorSoldStatusChanged = Notification.Name("RemoteMotorSoldStatusChanged")
    static let motorSaleBannerRequested = Notification.Name("MotorSaleBannerRequested")
    static let financialSyncMerged = Notification.Name("FinancialSyncMerged")
}

enum RemoteMotorSyncUserInfoKey {
    static let motorID = "motorID"
    static let soldDate = "soldDate"
    static let companyId = "companyId"
    static let operationDocumentId = "operationDocumentId"
    static let operationType = "operationType"
    static let createdByUser = "createdByUser"
}

enum MotorSaleBannerUserInfoKey {
    static let message = "message"
}
