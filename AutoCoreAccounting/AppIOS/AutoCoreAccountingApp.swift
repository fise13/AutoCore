import SwiftUI
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

#if os(iOS)

/// Отдельное полноэкранное iOS‑приложение для бухгалтера.
@main
struct AutoCoreAccountingApp: App {
    @StateObject private var appState: AppState
    
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
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

#endif

