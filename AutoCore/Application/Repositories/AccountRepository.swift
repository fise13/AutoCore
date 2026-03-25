import Foundation

/// Repository interface for MVP accounts and balances.
protocol AccountRepository {
    func save(_ account: AccountEntity) async throws -> AccountEntity
    func findByID(_ id: String) async throws -> AccountEntity?
    func findAll(companyId: String) async throws -> [AccountEntity]
    func updateBalance(accountId: String, delta: Decimal) async throws
}
