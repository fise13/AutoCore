import Foundation

/// Use Case: create operation and update account balance.
final class CreateOperationUseCase {
    private let operationRepository: OperationRepository
    private let accountRepository: AccountRepository

    init(
        operationRepository: OperationRepository,
        accountRepository: AccountRepository
    ) {
        self.operationRepository = operationRepository
        self.accountRepository = accountRepository
    }

    @discardableResult
    func execute(_ dto: CreateOperationDTO) async throws -> OperationEntity {
        var operation = OperationEntity(
            id: dto.id ?? UUID().uuidString,
            companyId: dto.companyId,
            type: dto.type,
            amount: dto.amount,
            accountId: dto.accountId,
            category: dto.category,
            comment: dto.comment,
            createdAt: dto.createdAt ?? Date(),
            relatedEngineId: dto.relatedEngineId
        )

        try operation.validate()
        operation = try await operationRepository.save(operation)

        switch operation.type {
        case .income:
            try await accountRepository.updateBalance(accountId: operation.accountId, delta: operation.amount)
        case .expense:
            try await accountRepository.updateBalance(accountId: operation.accountId, delta: -operation.amount)
        case .transfer:
            try await accountRepository.updateBalance(accountId: operation.accountId, delta: -operation.amount)
            if let destinationAccountId = dto.transferAccountId {
                try await accountRepository.updateBalance(accountId: destinationAccountId, delta: operation.amount)
            }
        }

        return operation
    }
}

struct CreateOperationDTO {
    let id: String?
    let companyId: String
    let type: OperationEntity.OperationType
    let amount: Decimal
    let accountId: String
    let transferAccountId: String?
    let category: String?
    let comment: String
    let createdAt: Date?
    let relatedEngineId: String?

    init(
        id: String? = nil,
        companyId: String,
        type: OperationEntity.OperationType,
        amount: Decimal,
        accountId: String,
        transferAccountId: String? = nil,
        category: String? = nil,
        comment: String = "",
        createdAt: Date? = nil,
        relatedEngineId: String? = nil
    ) {
        self.id = id
        self.companyId = companyId
        self.type = type
        self.amount = amount
        self.accountId = accountId
        self.transferAccountId = transferAccountId
        self.category = category
        self.comment = comment
        self.createdAt = createdAt
        self.relatedEngineId = relatedEngineId
    }
}
