import Foundation

/// Use Case: sell engine and atomically reflect finance side effects.
final class SellEngineUseCase {
    private let engineRepository: EngineRepository
    private let operationRepository: OperationRepository
    private let accountRepository: AccountRepository

    init(
        engineRepository: EngineRepository,
        operationRepository: OperationRepository,
        accountRepository: AccountRepository
    ) {
        self.engineRepository = engineRepository
        self.operationRepository = operationRepository
        self.accountRepository = accountRepository
    }

    @discardableResult
    func execute(_ dto: SellEngineDTO) async throws -> SellEngineResult {
        guard var engine = try await engineRepository.findByID(dto.engineId) else {
            throw AppError.notFound(message: "Двигатель с ID \(dto.engineId) не найден")
        }

        let soldAt = dto.soldAt ?? Date()
        try engine.sell(on: soldAt)
        let savedEngine = try await engineRepository.save(engine)

        let amount = dto.saleAmount ?? savedEngine.sellPrice
        let operation = OperationEntity(
            id: UUID().uuidString,
            companyId: savedEngine.companyId,
            type: .income,
            amount: amount,
            accountId: dto.accountId,
            category: dto.category,
            comment: dto.comment,
            createdAt: soldAt,
            relatedEngineId: savedEngine.id
        )
        try operation.validate()
        let savedOperation = try await operationRepository.save(operation)

        try await accountRepository.updateBalance(accountId: dto.accountId, delta: amount)
        guard let updatedAccount = try await accountRepository.findByID(dto.accountId) else {
            throw AppError.notFound(message: "Счет с ID \(dto.accountId) не найден после обновления баланса")
        }

        return SellEngineResult(
            engine: savedEngine,
            operation: savedOperation,
            account: updatedAccount
        )
    }
}

struct SellEngineDTO {
    let engineId: String
    let accountId: String
    let saleAmount: Decimal?
    let soldAt: Date?
    let category: String?
    let comment: String

    init(
        engineId: String,
        accountId: String,
        saleAmount: Decimal? = nil,
        soldAt: Date? = nil,
        category: String? = nil,
        comment: String = ""
    ) {
        self.engineId = engineId
        self.accountId = accountId
        self.saleAmount = saleAmount
        self.soldAt = soldAt
        self.category = category
        self.comment = comment
    }
}

struct SellEngineResult {
    let engine: EngineItemEntity
    let operation: OperationEntity
    let account: AccountEntity
}
