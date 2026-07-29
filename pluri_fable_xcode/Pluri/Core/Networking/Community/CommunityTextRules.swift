import Foundation

/// Shared create-post validation rules (SPEC §11 — title + ≥3 body words).
enum CommunityTextRules {
    static let minimumBodyWordCount = 3

    /// Whitespace-separated word count (trimmed empties ignored).
    static func wordCount(in text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.filter { !$0.isEmpty }.count
    }

    static func isValidPost(title: String, body: String) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty && wordCount(in: body) >= minimumBodyWordCount
    }
}
