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
    }
    
    func refreshStats() {
        isLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let brands = try await Task { try self.database.fetchBrands() }.value
                let engines = try await Task { try self.database.fetchEngines(brandID: nil) }.value
                let allMotors = try await Task { try self.database.fetchMotors(filter: DatabaseService.MotorFilter(), limit: nil, offset: 0) }.value
                let soldMotors = try await Task { try self.database.fetchMotors(filter: DatabaseService.MotorFilter(availability: .sold), limit: nil, offset: 0) }.value
                let serviceRecords = try await Task { try self.database.fetchAllServiceRecords() }.value
                
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
                    serviceRecordsByCategory: recordsByCategory
                )
                
                await self.updateStats(stats)
            } catch {
                await self.setError("Ошибка получения статистики: \(error.localizedDescription)")
            }
        }
    }
    
    func clearAllServiceRecords() {
        isLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await Task { try self.database.deleteAllServiceRecords() }.value
                await self.setSuccess("Все специфичные записи удалены")
                await self.refreshStats()
                await self.onDataChanged?()
            } catch {
                await self.setError("Ошибка удаления: \(error.localizedDescription)")
            }
        }
    }
    
    func clearAllMotors() {
        isLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await Task { try self.database.deleteAllMotors() }.value
                await self.setSuccess("Все моторы удалены")
                await self.refreshStats()
                await self.onDataChanged?()
            } catch {
                await self.setError("Ошибка удаления: \(error.localizedDescription)")
            }
        }
    }
    
    func clearAllEngines() {
        isLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await Task { try self.database.deleteAllEngines() }.value
                await self.setSuccess("Все двигатели удалены")
                await self.refreshStats()
                await self.onDataChanged?()
            } catch {
                await self.setError("Ошибка удаления: \(error.localizedDescription)")
            }
        }
    }
    
    func clearAllBrands() {
        isLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await Task { try self.database.deleteAllBrands() }.value
                await self.setSuccess("Все бренды удалены")
                await self.refreshStats()
                await self.onDataChanged?()
            } catch {
                await self.setError("Ошибка удаления: \(error.localizedDescription)")
            }
        }
    }
    
    func clearAllData() {
        isLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await Task { try self.database.deleteAllData() }.value
                await self.setSuccess("Вся база данных очищена")
                await self.refreshStats()
                await self.onDataChanged?()
            } catch {
                await self.setError("Ошибка очистки: \(error.localizedDescription)")
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
        info += "Специфичные записи: \(stats.serviceRecordsCount)\n\n"
        
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.errorMessage = nil
        }
    }
    
    @MainActor
    private func setSuccess(_ message: String) {
        self.successMessage = message
        self.isLoading = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.successMessage = nil
        }
    }
}
