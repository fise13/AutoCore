import Foundation

struct FinancialOperation: Identifiable {
    let id: Int64
    let cloudDocumentId: String?
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
    
    init(
        id: Int64,
        cloudDocumentId: String? = nil,
        type: FinancialOperationEntity.OperationType,
        amount: Decimal,
        paymentMethod: FinancialOperationEntity.PaymentMethod,
        cashReceived: Decimal?,
        changeGiven: Decimal?,
        account: FinancialOperationEntity.Account,
        relatedMotorID: Int64?,
        createdAt: Date,
        createdByUser: String,
        comment: String,
        source: String,
        details: String,
        category: String?,
        description: String
    ) {
        self.id = id
        self.cloudDocumentId = cloudDocumentId
        self.type = type
        self.amount = amount
        self.paymentMethod = paymentMethod
        self.cashReceived = cashReceived
        self.changeGiven = changeGiven
        self.account = account
        self.relatedMotorID = relatedMotorID
        self.createdAt = createdAt
        self.createdByUser = createdByUser
        self.comment = comment
        self.source = source
        self.details = details
        self.category = category
        self.description = description
    }
}
