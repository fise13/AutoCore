import Foundation

/// Utilities for normalizing product names, computing fuzzy similarity, and parsing local dates.
enum AccountingItemNormalizer {

    // MARK: - Advance keywords (checked case-insensitively)

    static let advanceKeywords: [String] = [
        "аванс", "предоплата", "prepayment", "advance",
        "задаток", "депозит", "предоп"
    ]

    // MARK: - Name normalization

    /// Lowercase + keep only alphanumeric characters.
    /// "EJ-253" → "ej253",  "Subaru EJ 253" → "subaruej253"
    static func normalize(_ name: String) -> String {
        name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    /// Split into meaningful tokens (≥ 2 chars each) for set-based matching.
    /// "Subaru EJ253" → {"subaru", "ej253"}
    static func tokenize(_ name: String) -> Set<String> {
        Set(
            name.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 2 }
        )
    }

    // MARK: - Similarity [0.0, 1.0]

    /// Compute a confidence score between two item names.
    ///
    /// Algorithm priority:
    /// 1. Exact match after normalization → 1.0
    /// 2. Token-based max-containment (how much of the smaller set appears in the larger)
    ///    This handles: "ej253" ↔ "subaru ej253" → 1.0
    /// 3. Levenshtein similarity, **capped at 0.79** to prevent false positives
    ///    between short codes like "EJ253" and "EJ254".
    static func similarity(_ a: String, _ b: String) -> Double {
        let normA = normalize(a)
        let normB = normalize(b)

        if normA == normB { return 1.0 }
        if normA.isEmpty || normB.isEmpty { return 0.0 }

        let tokA = tokenize(a)
        let tokB = tokenize(b)

        if !tokA.isEmpty, !tokB.isEmpty {
            let intersection = tokA.intersection(tokB)
            if !intersection.isEmpty {
                // Max-containment: what fraction of the smaller set is shared
                let containment = Double(intersection.count) / Double(min(tokA.count, tokB.count))
                return containment
            }
        }

        // Levenshtein as last resort, capped below the 0.8 threshold so it
        // never triggers a match on its own — only normalization/token checks can.
        return min(levenshteinSimilarity(normA, normB), 0.79)
    }

    // MARK: - Advance detection

    static func isAdvance(_ text: String) -> Bool {
        let lower = text.lowercased()
        return advanceKeywords.contains { lower.contains($0) }
    }

    // MARK: - Local date parsing (no UTC shift)

    /// Parse a date string treating it as LOCAL timezone (never UTC).
    /// Also handles Excel serial numbers.
    static func parseLocalDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Excel date serial (e.g. "45000")
        if let serial = Double(trimmed), serial > 40_000, serial < 100_000 {
            return excelSerialToLocalDate(serial)
        }

        let formats = [
            "dd.MM.yyyy", "d.MM.yyyy", "d.M.yyyy",
            "dd/MM/yyyy", "dd-MM-yyyy",
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "d.MM.yy", "dd.MM.yy"
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current   // LOCAL — never UTC

        for fmt in formats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    /// Convert Excel serial date to a local-timezone Date.
    /// Base: 1899-12-30 (Excel convention), local calendar.
    static func excelSerialToLocalDate(_ serial: Double) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        var comps = DateComponents()
        comps.year = 1899; comps.month = 12; comps.day = 30
        guard let base = cal.date(from: comps) else { return nil }
        return base.addingTimeInterval(serial * 86_400)
    }

    // MARK: - Levenshtein distance

    static func levenshteinSimilarity(_ a: String, _ b: String) -> Double {
        let dist = levenshteinDistance(Array(a), Array(b))
        let maxLen = max(a.count, b.count)
        guard maxLen > 0 else { return 1.0 }
        return 1.0 - Double(dist) / Double(maxLen)
    }

    static func levenshteinDistance<T: Equatable>(_ a: [T], _ b: [T]) -> Int {
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var dp = Array(0...b.count)
        for i in 1...a.count {
            var prev = dp[0]
            dp[0] = i
            for j in 1...b.count {
                let temp = dp[j]
                dp[j] = a[i - 1] == b[j - 1]
                    ? prev
                    : Swift.min(prev, Swift.min(dp[j], dp[j - 1])) + 1
                prev = temp
            }
        }
        return dp[b.count]
    }
}
