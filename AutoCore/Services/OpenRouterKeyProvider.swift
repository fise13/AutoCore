import Foundation

/// OpenRouter: ключ не храним в исходниках. Порядок: `OPENROUTER_API_KEY` / `OPENAI_API_KEY` в среде запуска,
/// затем `UserDefaults` (см. `defaults write` для `OPENROUTER_API_KEY`).
enum OpenRouterKeyProvider {
    private static let userDefaultsKey = "OPENROUTER_API_KEY"
    private static let legacyOpenAIKey = "OPENAI_API_KEY"

    static var resolved: String {
        let env = ProcessInfo.processInfo.environment
        if let k = env[userDefaultsKey]?.trimmedNonEmpty { return k }
        if let k = env[legacyOpenAIKey]?.trimmedNonEmpty { return k }
        if let k = UserDefaults.standard.string(forKey: userDefaultsKey)?.trimmedNonEmpty { return k }
        if let k = UserDefaults.standard.string(forKey: legacyOpenAIKey)?.trimmedNonEmpty { return k }
        return ""
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
