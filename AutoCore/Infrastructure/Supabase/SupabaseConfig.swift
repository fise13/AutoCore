import Foundation

/// Конфигурация для подключения к Supabase
struct SupabaseConfig {
    let baseURL: String
    let apiKey: String
    let accessToken: String?
    let companyId: UUID?
    
    /// Загрузить конфигурацию из переменных окружения, Info.plist или использовать значения по умолчанию
    static func load() -> SupabaseConfig {
        // Сначала пробуем переменные окружения (для разработки)
        if let baseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"],
           let apiKey = ProcessInfo.processInfo.environment["SUPABASE_API_KEY"] {
            let accessToken = ProcessInfo.processInfo.environment["SUPABASE_ACCESS_TOKEN"]
            let companyIdString = ProcessInfo.processInfo.environment["SUPABASE_COMPANY_ID"]
            let companyId = companyIdString.flatMap { UUID(uuidString: $0) }
            return SupabaseConfig(baseURL: baseURL, apiKey: apiKey, accessToken: accessToken, companyId: companyId)
        }
        
        // Затем пробуем Info.plist
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let baseURL = plist["SupabaseURL"] as? String,
           let apiKey = plist["SupabaseAPIKey"] as? String {
            let accessToken = plist["SupabaseAccessToken"] as? String
            let companyIdString = plist["SupabaseCompanyId"] as? String
            let companyId = companyIdString.flatMap { UUID(uuidString: $0) }
            return SupabaseConfig(baseURL: baseURL, apiKey: apiKey, accessToken: accessToken, companyId: companyId)
        }
        
        // Используем значения по умолчанию из предоставленных данных
        // company_id можно получить из переменной окружения или использовать фиксированный UUID
        let companyIdString = ProcessInfo.processInfo.environment["SUPABASE_COMPANY_ID"]
        let companyId = companyIdString.flatMap { UUID(uuidString: $0) }
        
        return SupabaseConfig(
            baseURL: "https://vfqivqthphewghmvwrne.supabase.co",
            apiKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmcWl2cXRocGhld2dobXZ3cm5lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg4Mzk4ODYsImV4cCI6MjA4NDQxNTg4Nn0.U96BFws-ApbCxbGH6Y3SrqCLHYg0hvABi5yNJ3kmAFo",
            accessToken: nil,
            companyId: companyId
        )
    }
    
    /// Проверить, настроена ли конфигурация
    var isConfigured: Bool {
        !baseURL.isEmpty && !apiKey.isEmpty
    }
}
