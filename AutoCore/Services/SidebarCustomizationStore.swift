#if os(macOS)

import Foundation

final class SidebarCustomizationStore {
    static let shared = SidebarCustomizationStore()
    static let didChangeNotification = Notification.Name("SidebarCustomizationStore.didChange")
    private let key = "SidebarCustomization.v1"
    private let defaults = UserDefaults.standard

    private init() {}

    func load() -> SidebarCustomization {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(SidebarCustomization.self, from: data) else {
            return .default
        }
        return value
    }

    func save(_ customization: SidebarCustomization) {
        guard let data = try? JSONEncoder().encode(customization) else { return }
        defaults.set(data, forKey: key)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}

#endif
