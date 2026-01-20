import Foundation

/// HTTP клиент для работы с Supabase
/// Единая точка входа для всех запросов к Supabase API
final class SupabaseClient {
    private let baseURL: String
    private let apiKey: String
    private weak var authService: SupabaseAuthService?
    private let session: URLSession
    private let jsonEncoder: JSONEncoder
    
    init(
        baseURL: String,
        apiKey: String,
        authService: SupabaseAuthService? = nil
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.authService = authService
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
        
        self.jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    /// Получить access token из auth service
    private func getAccessToken() -> String? {
        // Получаем токен из SupabaseAuthService если доступен
        if let authService = authService {
            return authService.currentAccessToken
        }
        
        // Fallback: используем сохранённый токен из UserDefaults
        guard let jsonString = UserDefaults.standard.string(forKey: "supabase_session"),
              let data = jsonString.data(using: .utf8),
              let sessionData = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let accessToken = sessionData["access_token"] else {
            return nil
        }
        return accessToken
    }
    
    /// Отправить финансовую операцию в Supabase
    func sendFinancialOperation(_ operation: SupabaseFinancialOperationDTO) async throws {
        guard let url = URL(string: "\(baseURL)/rest/v1/financial_operations") else {
            throw SupabaseError.invalidURL
        }
        
        // Кодируем payload один раз
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let jsonData: Data
        do {
            jsonData = try encoder.encode(operation)
            
            // Логируем payload перед отправкой
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📦 Supabase payload: \(jsonString)")
            }
        } catch {
            print("❌ Failed to encode payload: \(error)")
            throw SupabaseError.encodingError(error)
        }
        
        // Выполняем запрос (с автоматическим обновлением токена при необходимости)
        try await performRequest(url: url, jsonData: jsonData)
    }
    
    /// Выполнить HTTP запрос с автоматическим обновлением токена
    private func performRequest(url: URL, jsonData: Data, isRetry: Bool = false) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData
        
        // Получаем access token из auth service
        if let token = getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if isRetry {
                print("🔄 Using refreshed token for retry request (token length: \(token.count))")
            }
        } else {
            print("⚠️ No access token available for Supabase request")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.invalidResponse
            }
            
            // Логируем response
            let statusCode = httpResponse.statusCode
            if let responseBody = String(data: data, encoding: .utf8) {
                print("📥 Supabase response [\(statusCode)]: \(responseBody)")
            } else {
                print("📥 Supabase response [\(statusCode)]: (empty body)")
            }
            
            guard (200...299).contains(statusCode) else {
                if statusCode == 401 && !isRetry {
                    // Токен истек - пытаемся обновить и повторить запрос
                    if let authService = authService {
                        print("🔄 Access token expired, attempting to refresh...")
                        do {
                            // Вызываем refreshToken - Swift автоматически переключится на MainActor,
                            // так как SupabaseAuthService помечен @MainActor
                            try await authService.refreshToken()
                            print("🔄 Retrying request with refreshed token...")
                            
                            // Повторяем запрос с новым токеном
                            // Если запрос вернет ошибку (например 403), она будет обработана ниже
                            try await performRequest(url: url, jsonData: jsonData, isRetry: true)
                            return // Успешно после обновления токена
                        } catch let refreshError as SupabaseError {
                            // Ошибка refresh токена (например, refresh token тоже истек)
                            print("❌ Failed to refresh token: \(refreshError)")
                            throw refreshError
                        } catch {
                            // Другие ошибки при refresh
                            print("❌ Failed to refresh token: \(error)")
                            throw SupabaseError.unauthorized
                        }
                    }
                    throw SupabaseError.unauthorized
                } else if statusCode == 403 {
                    // 403 означает проблему с RLS или правами доступа
                    if isRetry {
                        // Это повторный запрос после refresh - значит токен валидный, но RLS блокирует
                        if let errorBody = String(data: data, encoding: .utf8) {
                            print("❌ Supabase RLS policy violation (403) after token refresh: \(errorBody)")
                            print("   This means the token is valid but RLS policy is blocking the INSERT")
                            print("   Check that company_id matches auth.uid() in your RLS policy")
                        }
                    } else {
                        // Первый запрос с 403 - возможно токен невалидный или нет прав
                        if let errorBody = String(data: data, encoding: .utf8) {
                            print("❌ Supabase forbidden (403): \(errorBody)")
                        }
                    }
                    throw SupabaseError.forbidden
                } else if statusCode >= 500 {
                    throw SupabaseError.serverError(statusCode: statusCode)
                } else {
                    // Логируем детали ошибки
                    if let errorBody = String(data: data, encoding: .utf8) {
                        print("❌ Supabase error body: \(errorBody)")
                    }
                    throw SupabaseError.httpError(statusCode: statusCode)
                }
            }
            
            if !isRetry {
                print("✅ Successfully synced operation to Supabase")
            } else {
                print("✅ Successfully synced operation to Supabase after token refresh")
            }
        } catch let error as SupabaseError {
            throw error
        } catch {
            throw SupabaseError.networkError(error)
        }
    }
    
    /// Обновить access token
    func updateAccessToken(_ token: String?) {
        // В Swift структуры immutable, поэтому нужно создать новый экземпляр
        // Но для простоты используем внутреннее свойство
        // В реальном приложении можно использовать actor или class
    }
}

/// DTO для отправки финансовой операции в Supabase
struct FinancialOperationDTO: Codable {
    let type: String
    let amount: String
    let paymentMethod: String
    let cashReceived: String?
    let changeGiven: String?
    let account: String
    let relatedMotorId: Int64?
    let createdAt: Date
    let createdByUser: String
    let comment: String
    let source: String
    let details: String
    let category: String?
    let description: String
    
    init(from entity: FinancialOperationEntity) {
        self.type = entity.type.rawValue
        self.amount = String(describing: entity.amount)
        self.paymentMethod = entity.paymentMethod.rawValue
        self.cashReceived = entity.cashReceived.map { String(describing: $0) }
        self.changeGiven = entity.changeGiven.map { String(describing: $0) }
        self.account = entity.account.rawValue
        self.relatedMotorId = entity.relatedMotorID
        self.createdAt = entity.createdAt
        self.createdByUser = entity.createdByUser
        self.comment = entity.comment
        self.source = entity.source
        self.details = entity.details
        self.category = entity.category
        self.description = entity.description
    }
}

/// DTO для отправки в Supabase REST API
/// Соответствует схеме таблицы financial_operations в Supabase
struct SupabaseFinancialOperationDTO: Encodable {
    let companyId: UUID
    let type: String
    let amount: Double
    let account: String
    let comment: String?
    
    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case type
        case amount
        case account
        case comment
    }
}

enum SupabaseError: LocalizedError {
    case invalidURL
    case encodingError(Error)
    case networkError(Error)
    case invalidResponse
    case unauthorized
    case forbidden
    case httpError(statusCode: Int)
    case serverError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL Supabase"
        case .encodingError(let error):
            return "Ошибка кодирования данных: \(error.localizedDescription)"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .invalidResponse:
            return "Неверный ответ от сервера"
        case .unauthorized:
            return "Не авторизован"
        case .forbidden:
            return "Доступ запрещён"
        case .httpError(let code):
            return "HTTP ошибка: \(code)"
        case .serverError(let code):
            return "Ошибка сервера: \(code)"
        }
    }
}
