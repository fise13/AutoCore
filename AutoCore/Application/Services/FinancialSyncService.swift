//
//  FinancialSyncService.swift
//  AutoCore
//
//  Протокол синхронизации финансовых операций с облаком (Firestore).
//  macOS: push при сохранении, pull при запуске. iOS: чтение напрямую из Firestore.
//

import Foundation

/// Сервис синхронизации финансовых операций с Firestore
protocol FinancialSyncService: AnyObject {
    /// Записывает операцию в Firestore. Возвращает documentId.
    func pushOperation(_ entity: FinancialOperationEntity, companyId: String) async throws -> String
    
    /// Загружает операции компании из Firestore (since — опциональная дата для инкрементального pull).
    func pullOperations(companyId: String, since: Date?) async throws -> [FinancialOperationEntity]
    
    /// Загружает операции из Firestore и сливает в локальную SQLite (macOS).
    /// Используется при старте приложения и смене компании.
    func pullAndMergeFinancialOperations(companyId: String, database: DatabaseService) async throws
    
    /// Подписка на изменения: сначала кэш (офлайн), затем обновления при изменении данных.
    /// Используется на iOS для real-time + offline.
    func observeOperations(companyId: String) -> AsyncStream<[FinancialOperationEntity]>
}
