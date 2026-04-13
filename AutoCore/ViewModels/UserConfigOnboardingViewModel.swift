#if os(macOS)

import Foundation
import Combine

@MainActor
final class UserConfigOnboardingViewModel: ObservableObject {
    @Published var step: Int = 1
    @Published var config: UserConfig

    private let store: UserConfigStore

    init(store: UserConfigStore) {
        self.store = store
        self.config = store.loadDraft() ?? UserConfig.template(.warehouse)
    }

    var totalSteps: Int { 4 }
    var canGoBack: Bool { step > 1 }
    var canGoForward: Bool {
        switch step {
        case 2:
            return config.columns.contains(where: { $0.isVisible })
        default:
            return true
        }
    }

    func selectBusinessType(_ type: BusinessType) {
        config = UserConfig.template(type)
        persistDraft()
    }

    func setColumnTitle(_ title: String, for columnID: String) {
        guard let idx = config.columns.firstIndex(where: { $0.id == columnID }) else { return }
        config.columns[idx].title = title
        persistDraft()
    }

    func setColumnVisible(_ isVisible: Bool, for columnID: String) {
        guard let idx = config.columns.firstIndex(where: { $0.id == columnID }) else { return }
        let visibleCount = config.columns.filter(\.isVisible).count
        if !isVisible && config.columns[idx].isVisible && visibleCount <= 1 {
            return
        }
        config.columns[idx].isVisible = isVisible
        persistDraft()
    }

    func setDateFormat(_ format: String) {
        config.dateFormat = format
        persistDraft()
    }

    func setUseAutoDate(_ value: Bool) {
        config.useAutoDate = value
        persistDraft()
    }

    func setShowSaleDate(_ value: Bool) {
        config.showSaleDate = value
        persistDraft()
    }

    func next() {
        guard canGoForward else { return }
        step = min(totalSteps, step + 1)
        persistDraft()
    }

    func back() {
        step = max(1, step - 1)
        persistDraft()
    }

    func complete() {
        store.save(config)
        store.clearDraft()
    }

    private func persistDraft() {
        store.saveDraft(config)
    }
}

#endif
