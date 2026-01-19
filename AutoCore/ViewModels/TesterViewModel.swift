import Foundation
import SwiftUI
import Combine

@MainActor
final class TesterViewModel: ObservableObject {
    @Published var isShowingTesterWindow = false
    @Published var databaseStats: DatabaseStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    let database: DatabaseService
    var onDataChanged: (() -> Void)?
    
    init(database: DatabaseService, onDataChanged: (() -> Void)? = nil) {
        self.database = database
        self.onDataChanged = onDataChanged
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
        Task { @MainActor in
            isLoading = true
        }
        
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let brands = try await Task { try database.fetchBrands() }.value
                let engines = try await Task { try database.fetchEngines(brandID: nil) }.value
                let allMotors = try await Task { try database.fetchMotors(filter: DatabaseService.MotorFilter(), limit: nil, offset: 0) }.value
                let soldMotors = try await Task { try database.fetchMotors(filter: DatabaseService.MotorFilter(availability: .sold), limit: nil, offset: 0) }.value
                let serviceRecords = try await Task { try database.fetchAllServiceRecords() }.value
                let specificCategories = try await Task { try database.fetchAllSpecificCategories() }.value
                let specificRecords = try await Task { try database.fetchAllSpecificRecords() }.value
                
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
                    self?.updateStats(stats)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка получения статистики: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func clearAllServiceRecords() {
        Task { @MainActor in
            isLoading = true
        }
        
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await Task { try database.deleteAllServiceRecords() }.value
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.setSuccess("Все специфичные записи удалены")
                    self.refreshStats()
                    self.onDataChanged?()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка удаления: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func clearAllMotors() {
        Task { @MainActor in
            isLoading = true
        }
        
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await Task { try database.deleteAllMotors() }.value
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.setSuccess("Все моторы удалены")
                    self.refreshStats()
                    self.onDataChanged?()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка удаления: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func clearAllEngines() {
        Task { @MainActor in
            isLoading = true
        }
        
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await Task { try database.deleteAllEngines() }.value
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.setSuccess("Все двигатели удалены")
                    self.refreshStats()
                    self.onDataChanged?()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка удаления: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func clearAllBrands() {
        Task { @MainActor in
            isLoading = true
        }
        
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await Task { try database.deleteAllBrands() }.value
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.setSuccess("Все бренды удалены")
                    self.refreshStats()
                    self.onDataChanged?()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка удаления: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func clearAllSpecificCategories() {
        Task { @MainActor in
            isLoading = true
        }
        
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await Task { try database.deleteAllSpecificCategories() }.value
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.setSuccess("Все специфичные категории удалены")
                    self.refreshStats()
                    self.onDataChanged?()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка удаления: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func clearAllSpecificRecords() {
        Task { @MainActor in
            isLoading = true
        }
        
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await Task { try database.deleteAllSpecificRecords() }.value
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.setSuccess("Все специфичные записи удалены")
                    self.refreshStats()
                    self.onDataChanged?()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка удаления: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func clearAllData() {
        Task { @MainActor in
            isLoading = true
        }
        
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await Task { try database.deleteAllData() }.value
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.setSuccess("Вся база данных очищена")
                    self.refreshStats()
                    self.onDataChanged?()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка очистки: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func exportDatabaseInfo() -> String {
        guard let stats = databaseStats else { return "Статистика не загружена" }
        
        var info = "=== Статистика базы данных ===\n\n"
        info += "Бренды: \(stats.brandsCount)\n"
        info += "Двигатели: \(stats.enginesCount)\n"
        info += "Моторы: \(stats.motorsCount)\n"
        info += "Проданные моторы: \(stats.soldMotorsCount)\n"
        info += "Специфичные записи: \(stats.serviceRecordsCount)\n"
        info += "Специфичные категории: \(stats.specificCategoriesCount)\n"
        info += "Специфичные записи (новые): \(stats.specificRecordsCount)\n\n"
        
        if !stats.serviceRecordsByCategory.isEmpty {
            info += "По категориям:\n"
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
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 секунды
            self.errorMessage = nil
        }
    }
    
    @MainActor
    private func setSuccess(_ message: String) {
        self.successMessage = message
        self.isLoading = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 секунды
            self.successMessage = nil
        }
    }
    
    func optimizeDatabase() {
        Task { @MainActor in
            isLoading = true
        }
        
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await Task { try database.optimizeDatabase() }.value
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.setSuccess("База данных оптимизирована")
                    self.refreshStats()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка оптимизации: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func exportDatabaseBackup() {
        Task { @MainActor in
            isLoading = true
        }
        
        let database = self.database
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let backupPath = try await Task { try database.createBackup() }.value
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.setSuccess("Резервная копия создана: \(backupPath)")
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setError("Ошибка создания резервной копии: \(error.localizedDescription)")
                }
            }
        }
    }
}
