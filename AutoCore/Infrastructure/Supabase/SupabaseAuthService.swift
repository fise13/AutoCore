import Foundation

/// Supabase Auth Service
/// Реализация авторизации через Supabase Auth
@MainActor
final class SupabaseAuthService: AuthService {
    private let baseURL: String
    private let apiKey: String
    private let session: URLSession
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    
    private(set) var currentUser: UserEntity?
    private var authStateContinuation: AsyncStream<AuthState>.Continuation?
    
    var authStateStream: AsyncStream<AuthState> {
        AsyncStream { continuation in
            self.authStateContinuation = continuation
            
            // Отправляем текущее состояние
            if let user = currentUser {
                continuation.yield(.authenticated(user))
            } else {
                continuation.yield(.unauthenticated)
            }
            
            continuation.onTermination = { @Sendable _ in
                // Cleanup если нужно
            }
        }
    }
    
    init(baseURL: String, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
        
        self.jsonEncoder = JSONEncoder()
        jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
        
        self.jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // Загружаем сохранённую сессию при старте
        loadSavedSession()
    }
    
    /// Вход с email и паролем
    func signIn(email: String, password: String) async throws -> UserEntity {
        // Устанавливаем состояние authenticating
        authStateContinuation?.yield(.authenticating)
        
        guard let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=password") else {
            authStateContinuation?.yield(.unauthenticated)
            throw AuthError.invalidCredentials
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        let body: [String: String] = [
            "email": email,
            "password": password
        ]
        
        do {
            request.httpBody = try jsonEncoder.encode(body)
        } catch {
            authStateContinuation?.yield(.unauthenticated)
            throw AuthError.unknown(error.localizedDescription)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                authStateContinuation?.yield(.unauthenticated)
                throw AuthError.networkError("Invalid response")
            }
            
            // Логируем raw response для диагностики
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Supabase auth raw response [\(httpResponse.statusCode)]: \(responseString)")
            }
            
            // Логируем raw response для диагностики
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Supabase auth raw response [\(httpResponse.statusCode)]: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                // Пробуем декодировать ответ
                do {
                    // Сначала пробуем декодировать как JSON объект
                    guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        throw AuthError.networkError("Invalid JSON format")
                    }
                    
                    // Извлекаем обязательные поля
                    guard let accessToken = jsonObject["access_token"] as? String,
                          let refreshToken = jsonObject["refresh_token"] as? String,
                          let userDict = jsonObject["user"] as? [String: Any],
                          let userId = userDict["id"] as? String else {
                        print("❌ Missing required fields in Supabase auth response")
                        print("   JSON keys: \(jsonObject.keys)")
                        authStateContinuation?.yield(.unauthenticated)
                        throw AuthError.networkError("Missing required fields in response")
                    }
                    
                    let userEmail = userDict["email"] as? String ?? ""
                    
                    // Сохраняем токен (создаём минимальный SupabaseUser для сохранения)
                    let userForSession = SupabaseUser(
                        id: userId,
                        email: userEmail,
                        aud: userDict["aud"] as? String,
                        role: userDict["role"] as? String,
                        emailConfirmedAt: userDict["email_confirmed_at"] as? String,
                        phone: userDict["phone"] as? String,
                        confirmedAt: userDict["confirmed_at"] as? String,
                        lastSignInAt: userDict["last_sign_in_at"] as? String,
                        appMetadata: nil,
                        userMetadata: nil,
                        identities: nil,
                        createdAt: userDict["created_at"] as? String,
                        updatedAt: userDict["updated_at"] as? String
                    )
                    saveSession(accessToken: accessToken, refreshToken: refreshToken, user: userForSession)
                    
                    // Создаём UserEntity
                    let userEntity = UserEntity(
                        id: userId,
                        email: userEmail,
                        displayName: userEmail.isEmpty ? nil : userEmail,
                        provider: .email
                    )
                    
                    currentUser = userEntity
                    authStateContinuation?.yield(.authenticated(userEntity))
                    
                    print("✅ Supabase user authenticated: uid=\(userId)")
                    
                    return userEntity
                } catch let error as AuthError {
                    authStateContinuation?.yield(.unauthenticated)
                    throw error
                } catch {
                    // Если декодирование не удалось, логируем ошибку
                    print("❌ Failed to decode Supabase auth response: \(error)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("   Response body: \(responseString)")
                    }
                    authStateContinuation?.yield(.unauthenticated)
                    throw AuthError.networkError("Invalid response format: \(error.localizedDescription)")
                }
            } else {
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("❌ Supabase auth error [\(httpResponse.statusCode)]: \(errorBody)")
                }
                
                authStateContinuation?.yield(.unauthenticated)
                
                if httpResponse.statusCode == 401 {
                    throw AuthError.invalidCredentials
                } else {
                    throw AuthError.networkError("HTTP \(httpResponse.statusCode)")
                }
            }
        } catch let error as AuthError {
            authStateContinuation?.yield(.unauthenticated)
            throw error
        } catch {
            authStateContinuation?.yield(.unauthenticated)
            throw AuthError.networkError(error.localizedDescription)
        }
    }
    
    /// Вход через Google (не поддерживается в Supabase Auth для macOS)
    func signInWithGoogle() async throws -> UserEntity {
        throw AuthError.notSupported("Google sign-in not supported for Supabase Auth")
    }
    
    /// Выход из системы
    func signOut() throws {
        // Очищаем сохранённую сессию
        clearSession()
        
        currentUser = nil
        authStateContinuation?.yield(.unauthenticated)
        
        print("✅ Supabase user signed out")
    }
    
    /// Проверить, авторизован ли пользователь
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    /// Получить ID текущего пользователя (для использования как company_id)
    var currentUserId: UUID? {
        guard let user = currentUser else { return nil }
        return UUID(uuidString: user.id)
    }
    
    /// Получить текущий access token
    var currentAccessToken: String? {
        guard let jsonString = UserDefaults.standard.string(forKey: "supabase_session"),
              let data = jsonString.data(using: .utf8),
              let sessionData = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let accessToken = sessionData["access_token"] else {
            return nil
        }
        return accessToken
    }
    
    /// Обновить access token используя refresh token
    func refreshToken() async throws {
        guard let jsonString = UserDefaults.standard.string(forKey: "supabase_session"),
              let data = jsonString.data(using: .utf8),
              let sessionData = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let refreshToken = sessionData["refresh_token"] else {
            throw AuthError.invalidCredentials
        }
        
        guard let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=refresh_token") else {
            throw AuthError.networkError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: String] = [
            "refresh_token": refreshToken
        ]
        
        do {
            request.httpBody = try jsonEncoder.encode(body)
        } catch {
            throw AuthError.unknown(error.localizedDescription)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.networkError("Invalid response")
            }
            
            if let responseBodyString = String(data: data, encoding: .utf8) {
                print("🔄 Supabase refresh token response [\(httpResponse.statusCode)]: \(responseBodyString)")
            }
            
            if httpResponse.statusCode == 200 {
                guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let accessToken = jsonObject["access_token"] as? String,
                      let newRefreshToken = jsonObject["refresh_token"] as? String,
                      let userDict = jsonObject["user"] as? [String: Any],
                      let userId = userDict["id"] as? String else {
                    print("❌ Supabase refresh token response parsing failed")
                    throw AuthError.networkError("Failed to parse refresh token response")
                }
                
                // Извлекаем email (может быть опциональным)
                let userEmail = userDict["email"] as? String ?? ""
                
                // Обновляем сессию с новыми токенами
                let userForSession = SupabaseUser(
                    id: userId,
                    email: userEmail,
                    aud: userDict["aud"] as? String,
                    role: userDict["role"] as? String,
                    emailConfirmedAt: userDict["email_confirmed_at"] as? String,
                    phone: userDict["phone"] as? String,
                    confirmedAt: userDict["confirmed_at"] as? String,
                    lastSignInAt: userDict["last_sign_in_at"] as? String,
                    appMetadata: nil,
                    userMetadata: nil,
                    identities: nil,
                    createdAt: userDict["created_at"] as? String,
                    updatedAt: userDict["updated_at"] as? String
                )
                
                saveSession(accessToken: accessToken, refreshToken: newRefreshToken, user: userForSession)
                
                print("✅ Access token refreshed successfully")
            } else {
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("❌ Supabase refresh token error [\(httpResponse.statusCode)]: \(errorBody)")
                }
                
                if httpResponse.statusCode == 401 {
                    // Refresh token тоже истек - нужно перелогиниться
                    clearSession()
                    currentUser = nil
                    authStateContinuation?.yield(.unauthenticated)
                    throw AuthError.invalidCredentials
                } else {
                    throw AuthError.networkError("HTTP \(httpResponse.statusCode)")
                }
            }
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Session Management
    
    private func saveSession(accessToken: String, refreshToken: String, user: SupabaseUser) {
        let sessionData: [String: Any] = [
            "access_token": accessToken,
            "refresh_token": refreshToken,
            "user_id": user.id,
            "user_email": user.email ?? ""
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: sessionData)
            if let jsonString = String(data: data, encoding: .utf8) {
                UserDefaults.standard.set(jsonString, forKey: "supabase_session")
            }
        } catch {
            print("❌ Failed to save session: \(error)")
        }
    }
    
    private func loadSavedSession() {
        guard let jsonString = UserDefaults.standard.string(forKey: "supabase_session"),
              let data = jsonString.data(using: .utf8),
              let sessionData = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let userId = sessionData["user_id"],
              let userEmail = sessionData["user_email"] else {
            return
        }
        
        // Восстанавливаем пользователя из сохранённой сессии
        // В реальном приложении нужно проверить токен через Supabase API
        let userEntity = UserEntity(
            id: userId,
            email: userEmail,
            displayName: userEmail,
            provider: .email
        )
        
        currentUser = userEntity
        print("✅ Restored Supabase session: uid=\(userId)")
    }
    
    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: "supabase_session")
    }
}

// MARK: - Supabase Auth Response Models

private struct SupabaseAuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int?
    let tokenType: String?
    let user: SupabaseUser
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case user
    }
}

private struct SupabaseUser: Codable {
    let id: String
    let email: String?
    let aud: String?
    let role: String?
    let emailConfirmedAt: String?
    let phone: String?
    let confirmedAt: String?
    let lastSignInAt: String?
    let appMetadata: [String: AnyCodable]?
    let userMetadata: [String: AnyCodable]?
    let identities: [SupabaseIdentity]?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case aud
        case role
        case emailConfirmedAt = "email_confirmed_at"
        case phone
        case confirmedAt = "confirmed_at"
        case lastSignInAt = "last_sign_in_at"
        case appMetadata = "app_metadata"
        case userMetadata = "user_metadata"
        case identities
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct SupabaseIdentity: Codable {
    let id: String
    let userId: String
    let identityData: [String: AnyCodable]
    let provider: String
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case identityData = "identity_data"
        case provider
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// Helper для декодирования любых JSON значений
private struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Пробуем декодировать различные типы по порядку
        // Используем do-catch для каждого типа, так как decode может выбросить ошибку
        do {
            let bool = try container.decode(Bool.self)
            value = bool
            return
        } catch {}
        
        do {
            let int = try container.decode(Int.self)
            value = int
            return
        } catch {}
        
        do {
            let double = try container.decode(Double.self)
            value = double
            return
        } catch {}
        
        do {
            let string = try container.decode(String.self)
            value = string
            return
        } catch {}
        
        do {
            let array = try container.decode([AnyCodable].self)
            value = array.map { $0.value }
            return
        } catch {}
        
        do {
            let dictionary = try container.decode([String: AnyCodable].self)
            value = dictionary.mapValues { $0.value }
            return
        } catch {}
        
        // Если ничего не подошло
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
}
