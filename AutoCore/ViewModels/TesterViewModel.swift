import Foundation
import SwiftUI
import Combine

@MainActor
final class TesterViewModel: ObservableObject {
    @Published var databaseStats: DatabaseStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    let database: DatabaseService
    var companyId: String
    var onDataChanged: (() -> Void)?

    /// Инкремент при закрытии окна — отбрасываем поздние обновления UI.
    private var workGeneration: UInt = 0

    init(database: DatabaseService, companyId: String = "", onDataChanged: (() -> Void)? = nil) {
        self.database = database
        self.companyId = companyId
        self.onDataChanged = onDataChanged
    }

    func invalidatePendingWork() {
        workGeneration &+= 1
        errorMessage = nil
        successMessage = nil
        isLoading = false
    }

    struct DatabaseStats {
        let brandsCount: Int
        let enginesCount: Int
        let motorsCount: Int
        let soldMotorsCount: Int
        let serviceRecordsCount: Int
        let serviceRecordsByCategory: [String: Int]
        let specificCategoriesCount: Int
        let specificRecordsCount: Int
    }

    func refreshStats() {
        let gen = workGeneration
        isLoading = true
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let brands = try database.fetchBrands()
                let engines = try database.fetchEngines(brandID: nil)
                let allMotors = try database.fetchMotors(filter: DatabaseService.MotorFilter(), limit: nil, offset: 0)
                let soldMotors = try database.fetchMotors(filter: DatabaseService.MotorFilter(availability: .sold), limit: nil, offset: 0)
                let serviceRecords = try database.fetchAllServiceRecords()
                let specificCategories = try database.fetchAllSpecificCategories()
                let specificRecords = try database.fetchAllSpecificRecords()

                var recordsByCategory: [String: Int] = [:]
                for record in serviceRecords {
                    recordsByCategory[record.category, default: 0] += 1
                }

                let stats = DatabaseStats(
                    brandsCount: brands.count,
                    enginesCount: engines.count,
                    motorsCount: allMotors.count,
                    soldMotorsCount: soldMotors.count,
                    serviceRecordsCount: serviceRecords.count,
                    serviceRecordsByCategory: recordsByCategory,
                    specificCategoriesCount: specificCategories.count,
                    specificRecordsCount: specificRecords.count
                )

                await MainActor.run { [weak self] in
                    guard let self, gen == self.workGeneration else { return }
                    self.updateStats(stats)
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, gen == self.workGeneration else { return }
                    self.setError(String(format: L10n.TesterError.statsFormat, error.localizedDescription))
                }
            }
        }
    }

    func clearAllServiceRecords() {
        runDestructive(genSnapshot: workGeneration) { try $0.deleteAllServiceRecords() } success: { L10n.TesterSuccess.serviceRecordsDeleted }
    }

    func clearAllMotors() {
        runDestructive(genSnapshot: workGeneration) { try $0.deleteAllMotors() } success: { L10n.TesterSuccess.motorsDeleted }
    }

    func clearAllEngines() {
        runDestructive(genSnapshot: workGeneration) { try $0.deleteAllEngines() } success: { L10n.TesterSuccess.enginesDeleted }
    }

    func clearAllBrands() {
        runDestructive(genSnapshot: workGeneration) { try $0.deleteAllBrands() } success: { L10n.TesterSuccess.brandsDeleted }
    }

    func clearAllSpecificCategories() {
        runDestructive(genSnapshot: workGeneration) { try $0.deleteAllSpecificCategories() } success: { L10n.TesterSuccess.specificCategoriesDeleted }
    }

    func clearAllSpecificRecords() {
        runDestructive(genSnapshot: workGeneration) { try $0.deleteAllSpecificRecords() } success: { L10n.TesterSuccess.specificRecordsDeleted }
    }

    func clearAllData() {
        runDestructive(genSnapshot: workGeneration) { try $0.deleteAllData() } success: { L10n.TesterSuccess.databaseCleared }
    }

    private func runDestructive(genSnapshot: UInt, work: @escaping (DatabaseService) throws -> Void, success: @escaping () -> String) {
        isLoading = true
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try work(database)
                await MainActor.run { [weak self] in
                    guard let self, genSnapshot == self.workGeneration else { return }
                    self.setSuccess(success())
                    self.refreshStats()
                    self.onDataChanged?()
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, genSnapshot == self.workGeneration else { return }
                    self.setError(String(format: L10n.TesterError.deleteFormat, error.localizedDescription))
                }
            }
        }
    }

    func exportDatabaseInfo() -> String {
        guard let stats = databaseStats else { return L10n.TesterExport.statsNotLoaded }

        var info = "=== \(L10n.Tester.databaseStats) ===\n\n"
        info += "\(L10n.Tester.brands): \(stats.brandsCount)\n"
        info += "\(L10n.Tester.engines): \(stats.enginesCount)\n"
        info += "\(L10n.Tester.motors): \(stats.motorsCount)\n"
        info += "\(L10n.Tester.soldMotors): \(stats.soldMotorsCount)\n"
        info += "\(L10n.Tester.serviceRecords): \(stats.serviceRecordsCount)\n"
        info += "\(L10n.Tester.specificCategories): \(stats.specificCategoriesCount)\n"
        info += "\(L10n.Tester.specificRecordsNew): \(stats.specificRecordsCount)\n\n"

        if !stats.serviceRecordsByCategory.isEmpty {
            info += "\(L10n.Tester.byCategory)\n"
            for (category, count) in stats.serviceRecordsByCategory.sorted(by: { $0.key < $1.key }) {
                info += "  \(category): \(count)\n"
            }
        }

        return info
    }

    @MainActor
    private func updateStats(_ stats: DatabaseStats) {
        self.databaseStats = stats
        self.isLoading = false
    }

    @MainActor
    private func setError(_ message: String) {
        self.errorMessage = message
        self.isLoading = false
        let gen = workGeneration
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard gen == self.workGeneration else { return }
            self.errorMessage = nil
        }
    }

    @MainActor
    private func setSuccess(_ message: String) {
        self.successMessage = message
        self.isLoading = false
        let gen = workGeneration
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard gen == self.workGeneration else { return }
            self.successMessage = nil
        }
    }

    func optimizeDatabase() {
        let gen = workGeneration
        isLoading = true
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try database.optimizeDatabase()
                await MainActor.run { [weak self] in
                    guard let self, gen == self.workGeneration else { return }
                    self.setSuccess(L10n.TesterSuccess.optimized)
                    self.refreshStats()
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, gen == self.workGeneration else { return }
                    self.setError(String(format: L10n.TesterError.optimizeFormat, error.localizedDescription))
                }
            }
        }
    }

    func exportDatabaseBackup() {
        let gen = workGeneration
        isLoading = true
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let backupPath = try database.createBackup()
                await MainActor.run { [weak self] in
                    guard let self, gen == self.workGeneration else { return }
                    self.setSuccess(String(format: L10n.TesterSuccess.backupCreatedFormat, backupPath))
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, gen == self.workGeneration else { return }
                    self.setError(String(format: L10n.TesterError.backupFormat, error.localizedDescription))
                }
            }
        }
    }

    func migrateFinancialOperationsToFirestore() {
        guard !companyId.isEmpty else {
            setError(L10n.TesterError.companyRequired)
            return
        }

        let gen = workGeneration
        isLoading = true
        let database = self.database
        let companyId = self.companyId

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                var filter = DatabaseService.FinancialOperationFilter()
                filter.fromDate = nil
                filter.toDate = nil
                filter.limit = nil
                filter.offset = nil
                let ops = try database.fetchFinancialOperations(filter: filter)

                let sync = FirestoreFinancialSyncService()
                var pushed = 0
                for (index, op) in ops.enumerated() {
                    if index % 10 == 0 {
                        let continueWork = await MainActor.run { [weak self] in
                            guard let self else { return false }
                            return gen == self.workGeneration
                        }
                        guard continueWork else {
                            await MainActor.run { [weak self] in self?.isLoading = false }
                            return
                        }
                    }
                    guard let type = FinancialOperationEntity.OperationType(rawValue: op.type),
                          let paymentMethod = FinancialOperationEntity.PaymentMethod(rawValue: op.paymentMethod),
                          let account = FinancialOperationEntity.Account(rawValue: op.account) else { continue }
                    let entity = FinancialOperationEntity(
                        id: op.id,
                        type: type,
                        amount: op.amount,
                        paymentMethod: paymentMethod,
                        cashReceived: op.cashReceived,
                        changeGiven: op.changeGiven,
                        account: account,
                        relatedMotorID: op.relatedMotorID,
                        createdAt: op.createdAt,
                        createdByUser: op.createdByUser,
                        comment: op.comment,
                        source: op.source,
                        details: op.details,
                        category: op.category,
                        description: op.description
                    )
                    try await sync.pushOperation(entity, companyId: companyId)
                    pushed += 1
                }

                await MainActor.run { [weak self] in
                    guard let self, gen == self.workGeneration else { return }
                    self.setSuccess(String(format: L10n.TesterSuccess.migrationDoneFormat, Int64(pushed), Int64(ops.count)))
                    self.refreshStats()
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, gen == self.workGeneration else { return }
                    self.setError(String(format: L10n.TesterError.migrationFormat, error.localizedDescription))
                }
            }
        }
    }
}
