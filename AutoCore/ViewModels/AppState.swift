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
    
    private var cancellables = Set<AnyCancellable>()
    
    init(authService: AuthService? = nil) {
        // Инициализируем AuthService и AuthViewModel сразу
        // Firebase уже инициализирован в AppDelegate при старте приложения
        let authService = authService ?? FirebaseAuthAdapter()
        self.authViewModel = AuthViewModel(authService: authService)
        
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
            
            // Проверяем, открыта ли БД в read-only режиме
            if database.isReadOnly {
                recoveryState.enable(reason: .databaseValidationFailed(
                    "База данных открыта в режиме только для чтения из-за ошибок доступа"
                ))
            }
            
            appViewModel = AppViewModel(database: database, recoveryState: recoveryState)
        } catch {
            // При ошибке открытия БД пытаемся открыть в read-only режиме
            do {
                let database = try DatabaseService(readOnly: true)
                featureFlagService = FeatureFlagService(database: database)
                backupService = BackupService(database: database)
                let settingsRepository = SQLiteSettingsRepository(database: database)
                settingsService = SettingsService(repository: settingsRepository)
                recoveryState.enable(reason: .databaseOpenFailed(error.localizedDescription))
                appViewModel = AppViewModel(database: database, recoveryState: recoveryState)
            } catch {
                // Если и read-only не работает, показываем ошибку
            errorMessage = "Не удалось открыть базу данных: \(error.localizedDescription)"
            }
        }
    }
}
