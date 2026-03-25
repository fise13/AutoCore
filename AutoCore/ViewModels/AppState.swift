import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

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
    /// Firebase UID для которого открыта локальная SQLite (если есть).
    private var boundUserId: String?

    /// Текущий companyId для текущего пользователя (если есть).
    var companyId: String {
        if let user = authViewModel?.currentUser {
            return user.companyId
        }
        return ""
    }

    init(authService: AuthService? = nil) {
        let authService = authService ?? FirebaseAuthService()
        self.authViewModel = AuthViewModel(authService: authService)

        authViewModel?.$authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.objectWillChange.send()
                self?.handleAuthStateChange(state)
            }
            .store(in: &cancellables)
    }

    private func handleAuthStateChange(_ state: AuthState) {
        switch state {
        case .unauthenticated:
            boundUserId = nil
            tearDownDatabaseStack()
            #if os(iOS)
            WidgetDataStore.clear()
            #endif
        case .authenticating:
            break
        case .authenticated(let user):
            if boundUserId == user.id { return }
            tearDownDatabaseStack()
            boundUserId = user.id
            errorMessage = nil
            do {
                let database = try DatabaseService(userId: user.id, readOnly: false)
                recoveryState.disable()
                attachDatabaseServices(database: database)
                if database.isReadOnly {
                    recoveryState.enable(reason: .databaseValidationFailed(
                        L10n.AppState.databaseReadonlyAccessErrors
                    ))
                }
            } catch {
                do {
                    let database = try DatabaseService(userId: user.id, readOnly: true)
                    recoveryState.enable(reason: .databaseOpenFailed(error.localizedDescription))
                    attachDatabaseServices(database: database)
                } catch {
                    boundUserId = nil
                    errorMessage = L10n.AppState.databaseOpenFailed(error.localizedDescription)
                }
            }
        }
    }

    private func tearDownDatabaseStack() {
        #if os(macOS)
        NotificationCenter.default.post(name: NSNotification.Name("AutoCoreTesterPanelDismiss"), object: nil)
        #endif
        appViewModel = nil
        backupService = nil
        featureFlagService = nil
        settingsService = nil
        recoveryState.disable()
    }

    private func attachDatabaseServices(database: DatabaseService) {
        featureFlagService = FeatureFlagService(database: database)
        backupService = BackupService(database: database)
        let settingsRepository = SQLiteSettingsRepository(database: database)
        settingsService = SettingsService(repository: settingsRepository)
        appViewModel = AppViewModel(database: database, recoveryState: recoveryState)
    }
}
