#if os(macOS)

import Foundation

final class UserConfigStore {
    static let shared = UserConfigStore()
    static let didChangeNotification = Notification.Name("UserConfigStore.didChange")

    private let defaults = UserDefaults.standard
    private let finalKey = "UserConfig.v1.final"
    private let draftKey = "UserConfig.v1.draft"

    private init() {}

    func load() -> UserConfig? {
        decode(forKey: finalKey)
    }

    func save(_ config: UserConfig) {
        encode(config, forKey: finalKey)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    func clear() {
        defaults.removeObject(forKey: finalKey)
    }

    func loadDraft() -> UserConfig? {
        decode(forKey: draftKey)
    }

    func saveDraft(_ config: UserConfig) {
        encode(config, forKey: draftKey)
    }

    func clearDraft() {
        defaults.removeObject(forKey: draftKey)
    }

    var hasCompletedOnboarding: Bool {
        load() != nil
    }

    private func decode(forKey key: String) -> UserConfig? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserConfig.self, from: data)
    }

    private func encode(_ config: UserConfig, forKey key: String) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: key)
    }
}

#endif
