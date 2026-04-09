import SwiftUI
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

#if os(iOS)

enum ThemePreference: Int {
    case system = 0
    case light = 1
    case dark = 2

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: return "Системная"
        case .light:  return "Светлая"
        case .dark:   return "Тёмная"
        }
    }
}

/// Отдельное полноэкранное iOS‑приложение для бухгалтера.
@main
struct AutoCoreAccountingApp: App {
    @StateObject private var appState: AppState
    @AppStorage("themePreference") private var themePreferenceRaw: Int = ThemePreference.system.rawValue

    private var themePreference: ThemePreference {
        ThemePreference(rawValue: themePreferenceRaw) ?? .system
    }

    init() {
        FirebaseApp.configure()
        let db = Firestore.firestore()
        var settings = db.settings
        settings.isPersistenceEnabled = true
        db.settings = settings
        _appState = StateObject(wrappedValue: AppState())
    }
    
    var body: some Scene {
        WindowGroup {
            IOSAuthRootView(appState: appState)
                .preferredColorScheme(themePreference.colorScheme)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

#endif

