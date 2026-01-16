import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var appViewModel: AppViewModel?
    @Published var errorMessage: String?

    init() {
        do {
            let database = try DatabaseService()
            appViewModel = AppViewModel(database: database)
        } catch {
            errorMessage = "Не удалось открыть базу данных: \(error.localizedDescription)"
        }
    }
}
