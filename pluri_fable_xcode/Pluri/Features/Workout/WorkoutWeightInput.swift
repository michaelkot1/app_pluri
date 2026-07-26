import Foundation

/// Filters and parses inline Log weight text (M4-19).
/// Empty = bodyweight / omitted weight; digits + one decimal separator (`.` or `,`).
enum WorkoutWeightInput {
    enum ParseResult: Equatable, Sendable {
        /// Blank — log with `nil` weight (bodyweight).
        case empty
        case valid(Double)
        case invalid
    }

    /// Keeps digits and at most one decimal separator (`.` or `,`).
    static func filtered(_ raw: String) -> String {
        var result = ""
        var sawSeparator = false
        for character in raw {
            if character.isNumber {
                result.append(character)
            } else if (character == "." || character == ","), !sawSeparator {
                result.append(character)
                sawSeparator = true
            }
        }
        return result
    }

    /// Parses user weight text after optional filtering. Locale commas normalize to `.`.
    static func parse(_ text: String) -> ParseResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }

        let normalized = trimmed.replacing(",", with: ".")
        // Lone / trailing separator alone is incomplete.
        if normalized == "." { return .invalid }
        guard let value = Double(normalized), value.isFinite, value >= 0 else {
            return .invalid
        }
        return .valid(value)
    }

    /// `true` when Log may proceed (empty bodyweight or a finite non-negative number).
    static func canLog(_ text: String) -> Bool {
        switch parse(text) {
        case .empty, .valid: true
        case .invalid: false
        }
    }
}
