import Foundation
import Testing
@testable import Pluri

/// M3-07 — workout color mapping (SPEC §14 #41): persisted token strings win
/// when recognizable; otherwise the workout type's default token applies.
@Suite("WorkoutColorResolver")
struct WorkoutColorResolverTests {
    private func makeSession(type: WorkoutType, color: String?) -> PlannedSession {
        PlannedSession(
            title: "Session",
            indexInWeek: 1,
            weekday: nil,
            date: nil,
            workoutType: type,
            color: color,
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

    @Test("A persisted known token wins over the type default")
    func persistedTokenWins() {
        let session = makeSession(type: .weights, color: "statusBlue")
        #expect(WorkoutColorResolver.token(for: session) == .statusBlue)
    }

    @Test("Token matching tolerates case and separator differences")
    func tokenNormalization() {
        #expect(WorkoutColorResolver.token(named: "status_blue") == .statusBlue)
        #expect(WorkoutColorResolver.token(named: "BRANDORANGE") == .brandOrange)
        #expect(WorkoutColorResolver.token(named: "accent-lavender") == .accentLavender)
    }

    @Test("An unrecognized persisted color falls back to the type default")
    func unknownColorFallsBack() {
        let session = makeSession(type: .cardio, color: "#FF00AA")
        #expect(WorkoutColorResolver.token(for: session) == .statusBlue)
    }
}
