import Foundation

/// Сервис для синхронизации финансовых операций с Supabase
/// Читает pending операции из outbox и отправляет их в Supabase
@MainActor
final class SupabaseSyncService {
    private let database: DatabaseService
    private let supabaseClient: SupabaseClient
    private let logger: LoggingService
    private let authService: SupabaseAuthService
    private var syncTask: Task<Void, Never>?
    private let maxRetries = 3
    
    init(
        database: DatabaseService,
        supabaseClient: SupabaseClient,
        authService: SupabaseAuthService,
        logger: LoggingService = .shared
    ) {
        self.database = database
        self.supabaseClient = supabaseClient
        self.authService = authService
        self.logger = logger
    }
    
    /// Запустить синхронизацию (фоновая задача)
    func startSync() {
        guard syncTask == nil else { return }
        
        syncTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                do {
                    try await self.processOutbox()
                    // Пауза между попытками синхронизации
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 секунд
                } catch {
                    self.logger.error("Error in sync loop", error: error)
                    // При ошибке ждём дольше перед следующей попыткой
                    try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 секунд
                }
            }
        }
    }
    
    /// Остановить синхронизацию
    func stopSync() {
        syncTask?.cancel()
        syncTask = nil
    }
    
    /// Обработать outbox (отправить все pending операции)
    func processOutbox() async throws {
        // Проверяем авторизацию ПЕРЕД обработкой outbox
        guard authService.isAuthenticated else {
            logger.info("Supabase sync skipped: user not authenticated", correlationID: UUIDv7.generateString())
            print("⚠️ Supabase sync skipped: user not authenticated")
            return
        }
        
        // Получаем company_id из текущего пользователя
        guard let companyId = authService.currentUserId else {
            logger.error("Supabase sync skipped: cannot get company_id from auth", correlationID: UUIDv7.generateString())
            print("❌ Supabase sync skipped: cannot get company_id from auth")
            return
        }
        
        let correlationID = UUIDv7.generateString()
        logger.info("Processing outbox", correlationID: correlationID)
        print("🔄 Processing outbox with company_id=\(companyId)")
        
        // Получаем pending операции
        let pendingOperations = try await Task.detached { [weak self] in
            guard let self = self else { return [DatabaseService.OutboxOperation]() }
            return try self.database.fetchPendingOutboxOperations()
        }.value
        
        guard !pendingOperations.isEmpty else {
            logger.info("No pending operations in outbox", correlationID: correlationID)
            return
        }
        
        logger.info("Found \(pendingOperations.count) pending operations", correlationID: correlationID)
        print("📦 Found \(pendingOperations.count) pending operations")
        
        // Отправляем каждую операцию
        for operation in pendingOperations {
            do {
                // Декодируем payload из outbox
                guard let jsonData = operation.payloadJSON.data(using: .utf8) else {
                    logger.error("Invalid JSON payload for operation \(operation.id)", correlationID: correlationID)
                    try await markAsFailed(operationID: operation.id, error: "Invalid JSON payload")
                    continue
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                let originalDTO = try decoder.decode(FinancialOperationDTO.self, from: jsonData)
                
                // Преобразуем в Supabase DTO с company_id из текущего пользователя
                // Логируем для диагностики RLS
                print("🔍 Creating DTO: company_id=\(companyId), user_id from auth=\(authService.currentUser?.id ?? "nil")")
                guard let supabaseDTO = createSupabaseDTO(from: originalDTO, companyId: companyId) else {
                    logger.error("Failed to create Supabase DTO for operation \(operation.id): missing company_id", correlationID: correlationID)
                    try await markAsFailed(operationID: operation.id, error: "Missing company_id")
                    continue
                }
                
                // Проверяем, что все обязательные поля заполнены
                guard !supabaseDTO.type.isEmpty,
                      supabaseDTO.amount > 0,
                      !supabaseDTO.account.isEmpty else {
                    logger.error("Invalid Supabase DTO for operation \(operation.id): missing required fields", correlationID: correlationID)
                    try await markAsFailed(operationID: operation.id, error: "Missing required fields")
                    continue
                }
                
                // Отправляем в Supabase
                try await supabaseClient.sendFinancialOperation(supabaseDTO)
                
                // Помечаем как отправленную
                try await markAsSent(operationID: operation.id)
                
                logger.info("Operation \(operation.id) synced successfully", correlationID: correlationID)
                
            } catch {
                logger.error("Failed to sync operation \(operation.id)", error: error, correlationID: correlationID)
                
                // Увеличиваем retry count
                let newRetryCount = operation.retryCount + 1
                
                if newRetryCount >= maxRetries {
                    // Превышен лимит попыток - помечаем как failed
                    try await markAsFailed(operationID: operation.id, error: error.localizedDescription)
                } else {
                    // Обновляем retry count
                    try await updateRetryCount(operationID: operation.id, retryCount: newRetryCount, error: error.localizedDescription)
                }
            }
        }
    }
    
    /// Создать Supabase DTO из исходного DTO
    private func createSupabaseDTO(from dto: FinancialOperationDTO, companyId: UUID) -> SupabaseFinancialOperationDTO? {
        
        // Преобразуем amount из String в Double
        guard let amountDouble = Double(dto.amount) else {
            print("❌ Invalid amount format: \(dto.amount)")
            return nil
        }
        
        // Проверяем обязательные поля
        guard !dto.type.isEmpty,
              !dto.account.isEmpty else {
            print("❌ Missing required fields: type=\(dto.type), account=\(dto.account)")
            return nil
        }
        
        let supabaseDTO = SupabaseFinancialOperationDTO(
            companyId: companyId,
            type: dto.type,
            amount: amountDouble,
            account: dto.account,
            comment: dto.comment.isEmpty ? nil : dto.comment
        )
        
        print("✅ Created Supabase DTO with company_id=\(companyId), type=\(dto.type), amount=\(amountDouble), account=\(dto.account)")
        
        return supabaseDTO
    }
    
    /// Пометить операцию как отправленную
    private func markAsSent(operationID: String) async throws {
        let database = self.database
        try await Task.detached {
            try database.markOutboxOperationAsSent(operationID: operationID)
        }.value
    }
    
    /// Пометить операцию как failed
    private func markAsFailed(operationID: String, error: String) async throws {
        let database = self.database
        try await Task.detached {
            try database.markOutboxOperationAsFailed(operationID: operationID, error: error)
        }.value
    }
    
    /// Обновить retry count
    private func updateRetryCount(operationID: String, retryCount: Int, error: String) async throws {
        let database = self.database
        try await Task.detached {
            try database.updateOutboxOperationRetryCount(operationID: operationID, retryCount: retryCount, error: error)
        }.value
    }
}

// OutboxOperation определена в DatabaseService
