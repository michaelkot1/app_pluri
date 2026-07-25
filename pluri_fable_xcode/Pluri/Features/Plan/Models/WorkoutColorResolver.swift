import SwiftUI

/// The design-system color tokens a workout may be tinted with (calendar
/// dots, week-card color coding — SPEC §6). Raw values are the persisted
/// `plan_workouts.color` token keys.
nonisolated enum WorkoutColorToken: String, CaseIterable, Sendable {
    case brandOrange
    case brandOrangeDeep
    case brandCoralSoft
    case statusGreen
    case statusBlue
    case accentPink
    case accentLavender
}

@MainActor
extension WorkoutColorToken {
    /// The actual design-system color for this token.
    var color: Color {
        switch self {
        case .brandOrange: PluriColor.brandOrange
        case .brandOrangeDeep: PluriColor.brandOrangeDeep
        case .brandCoralSoft: PluriColor.brandCoralSoft
        case .statusGreen: PluriColor.statusGreen
        case .statusBlue: PluriColor.statusBlue
        case .accentPink: PluriColor.accentPink
        case .accentLavender: PluriColor.accentLavender
        }
    }
}

/// Maps a workout to its display color token (SPEC §14 #41d): the persisted
/// `PlannedSession.color` wins when it names a known token (matched after
/// normalization, so `status_blue` and `statusBlue` both resolve); else the
/// session focus's design-token color when `focus` is set; otherwise the
/// workout type's default — weights → brand orange, cardio → status blue,
/// flexibility → accent lavender. Tokens only, never ad-hoc hex.
nonisolated enum WorkoutColorResolver {
    static func token(for session: PlannedSession) -> WorkoutColorToken {
        if let raw = session.color, let match = token(named: raw) {
            return match
        }
        if let focus = session.focus {
            return SessionFocus.focus(for: focus).colorToken
        }
        return defaultToken(for: session.workoutType)
    }

    /// Resolves a persisted color string to a known token, tolerant of
    /// case and separator differences.
    static func token(named name: String) -> WorkoutColorToken? {
        let normalized = normalize(name)
        return WorkoutColorToken.allCases.first { normalize($0.rawValue) == normalized }
    }

    static func defaultToken(for type: WorkoutType) -> WorkoutColorToken {
        switch type {
        case .weights: .brandOrange
        case .cardio: .statusBlue
        case .flexibility: .accentLavender
        }
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
