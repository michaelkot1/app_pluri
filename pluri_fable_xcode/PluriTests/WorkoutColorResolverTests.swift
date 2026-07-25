import Foundation
import Testing
@testable import Pluri

/// M3-07 / M3-21 — workout color mapping (SPEC §14 #41d): persisted token
/// strings win when recognizable; else the session focus color; otherwise
/// the workout type's default token applies.
@Suite("WorkoutColorResolver")
struct WorkoutColorResolverTests {
    private func makeSession(
        type: WorkoutType,
        color: String?,
        focus: SessionFocusCode? = nil
    ) -> PlannedSession {
        PlannedSession(
            title: "Session",
            indexInWeek: 1,
            weekday: nil,
            date: nil,
            workoutType: type,
            color: color,
            focus: focus,
            durationMinutes: 45,
            exercises: []
        )
    }

    @Test("Each workout type falls back to its default token", arguments: [
        (WorkoutType.weights, WorkoutColorToken.brandOrange),
        (WorkoutType.cardio, WorkoutColorToken.statusBlue),
        (WorkoutType.flexibility, WorkoutColorToken.accentLavender),
    ])
    func typeFallback(type: WorkoutType, expected: WorkoutColorToken) {
        #expect(WorkoutColorResolver.token(for: makeSession(type: type, color: nil)) == expected)
    }

    @Test("A persisted known token wins over focus and the type default")
    func persistedTokenWins() {
        let session = makeSession(type: .weights, color: "statusBlue", focus: .pull)
        #expect(WorkoutColorResolver.token(for: session) == .statusBlue)
    }

    @Test("Focus color wins when persisted color is missing (SPEC §14 #41d)")
    func focusFallbackWhenColorMissing() {
        let session = makeSession(type: .weights, color: nil, focus: .pull)
        #expect(WorkoutColorResolver.token(for: session) == SessionFocus.pull.colorToken)
    }

    @Test("Unrecognized persisted color falls through to focus, then type")
    func unknownColorFallsThroughToFocus() {
        let withFocus = makeSession(type: .cardio, color: "#FF00AA", focus: .legs)
        #expect(WorkoutColorResolver.token(for: withFocus) == SessionFocus.legs.colorToken)

        let withoutFocus = makeSession(type: .cardio, color: "#FF00AA", focus: nil)
        #expect(WorkoutColorResolver.token(for: withoutFocus) == .statusBlue)
    }

    @Test("Token matching tolerates case and separator differences")
    func tokenNormalization() {
        #expect(WorkoutColorResolver.token(named: "status_blue") == .statusBlue)
        #expect(WorkoutColorResolver.token(named: "BRANDORANGE") == .brandOrange)
        #expect(WorkoutColorResolver.token(named: "accent-lavender") == .accentLavender)
    }
}
