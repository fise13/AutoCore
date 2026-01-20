import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var appViewModel: AppViewModel?
    @Published var errorMessage: String?
    @Published var recoveryState = RecoveryState()
    @Published var featureFlagService: FeatureFlagService?
    @Published var backupService: BackupService?
    @Published var settingsService: SettingsService?
    @Published var authViewModel: AuthViewModel?
    @Published var supabaseSyncService: SupabaseSyncService?
    
    private var cancellables = Set<AnyCancellable>()
    
    init(authService: AuthService? = nil) {
        // Инициализируем Supabase Auth Service
        let supabaseConfig = SupabaseConfig.load()
        let supabaseAuthService = SupabaseAuthService(
            baseURL: supabaseConfig.baseURL,
            apiKey: supabaseConfig.apiKey
        )
        
        // Используем переданный authService или SupabaseAuthService по умолчанию
        let finalAuthService = authService ?? supabaseAuthService
        self.authViewModel = AuthViewModel(authService: finalAuthService)
        
        // Подписываемся на изменения authState для принудительного обновления UI
        authViewModel?.$authState
            .sink { [weak self] _ in
                // Принудительно обновляем AppState для триггера обновления UI
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        do {
            let database = try DatabaseService()
            
            // Инициализируем Feature Flag Service
            featureFlagService = FeatureFlagService(database: database)
            
            // Инициализируем Backup Service
            backupService = BackupService(database: database)
            
            // Инициализируем Settings Service
            let settingsRepository = SQLiteSettingsRepository(database: database)
            settingsService = SettingsService(repository: settingsRepository)
            
            // Инициализируем Supabase Sync Service
            if supabaseConfig.isConfigured {
                // Используем созданный SupabaseAuthService
                let supabaseClient = SupabaseClient(
                    baseURL: supabaseConfig.baseURL,
                    apiKey: supabaseConfig.apiKey,
                    authService: supabaseAuthService
                )
                supabaseSyncService = SupabaseSyncService(
                    database: database,
                    supabaseClient: supabaseClient,
                    authService: supabaseAuthService
                )
                // Запускаем синхронизацию в фоне (будет работать только после логина)
                supabaseSyncService?.startSync()
                print("✅ Supabase Sync Service initialized and started")
            } else {
                print("⚠️ Supabase Sync Service not configured")
            }
            
            // Проверяем, открыта ли БД в read-only режиме
            if database.isReadOnly {
                recoveryState.enable(reason: .databaseValidationFailed(
                    "База данных открыта в режиме только для чтения из-за ошибок доступа"
                ))
            }
            
            appViewModel = AppViewModel(database: database, recoveryState: recoveryState, supabaseSyncService: supabaseSyncService)
        } catch {
            // При ошибке открытия БД пытаемся открыть в read-only режиме
            do {
                let database = try DatabaseService(readOnly: true)
                featureFlagService = FeatureFlagService(database: database)
                backupService = BackupService(database: database)
                let settingsRepository = SQLiteSettingsRepository(database: database)
                settingsService = SettingsService(repository: settingsRepository)
                
                // Инициализируем Supabase Sync Service
                let supabaseConfig = SupabaseConfig.load()
                if supabaseConfig.isConfigured {
                    // Создаём новый SupabaseAuthService для read-only режима
                    let supabaseAuthService = SupabaseAuthService(
                        baseURL: supabaseConfig.baseURL,
                        apiKey: supabaseConfig.apiKey
                    )
                    
                    let supabaseClient = SupabaseClient(
                        baseURL: supabaseConfig.baseURL,
                        apiKey: supabaseConfig.apiKey,
                        authService: supabaseAuthService
                    )
                    supabaseSyncService = SupabaseSyncService(
                        database: database,
                        supabaseClient: supabaseClient,
                        authService: supabaseAuthService
                    )
                    supabaseSyncService?.startSync()
                    print("✅ Supabase Sync Service initialized and started (read-only mode)")
                } else {
                    print("⚠️ Supabase Sync Service not configured")
                }
                
                recoveryState.enable(reason: .databaseOpenFailed(error.localizedDescription))
                appViewModel = AppViewModel(database: database, recoveryState: recoveryState, supabaseSyncService: supabaseSyncService)
            } catch {
                // Если и read-only не работает, показываем ошибку
            errorMessage = "Не удалось открыть базу данных: \(error.localizedDescription)"
            }
        }
    }
}
