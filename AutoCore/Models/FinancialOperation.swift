import Foundation

struct FinancialOperation: Identifiable {
    let id: Int64
    let type: FinancialOperationEntity.OperationType
    let amount: Decimal
    let paymentMethod: FinancialOperationEntity.PaymentMethod
    let cashReceived: Decimal?
    let changeGiven: Decimal?
    let account: FinancialOperationEntity.Account
    let relatedMotorID: Int64?
    let createdAt: Date
    let createdByUser: String
    let comment: String
    let source: String
    let details: String
    let category: String?
    let description: String
}
