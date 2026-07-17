import Foundation

/// One desired upcoming-workout reminder derived from the plan (M3-15):
/// which workout, what to call it, and when to fire (SPEC §14 #48).
nonisolated struct WorkoutReminderCandidate: Equatable, Sendable {
    /// Namespace for workout reminder request identifiers, so reconciliation
    /// can find (and cancel) exactly the reminders this service owns.
    static let identifierPrefix = "pluri.workout-reminder."

    /// Local-time hour reminders fire at on the workout's scheduled day.
    static let fireHour = 8

    let workoutID: UUID
    let title: String
    let fireDate: Date

    /// Stable per-workout identifier (`pluri.workout-reminder.<workoutUUID>`)
    /// so a moved workout updates its reminder instead of duplicating it.
    var identifier: String { Self.identifierPrefix + workoutID.uuidString }

    /// Pure derivation of the desired reminder set from a plan: dated,
    /// still-`scheduled` sessions whose 8 AM local fire time is still ahead
    /// of `now`. Flexible (undated) pool sessions and completed/skipped
    /// history are excluded; a today-dated workout whose fire time already
    /// passed is skipped rather than fired late (SPEC §14 #48).
    static func candidates(
        in plan: GeneratedPlan,
        now: Date,
        calendar: Calendar
    ) -> [WorkoutReminderCandidate] {
        plan.weeks
            .flatMap(\.sessions)
            .compactMap { session -> WorkoutReminderCandidate? in
                guard session.status == .scheduled, let date = session.date else { return nil }
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = fireHour
                guard let fireDate = calendar.date(from: components), fireDate > now else { return nil }
                return WorkoutReminderCandidate(
                    workoutID: session.id,
                    title: session.title.isEmpty ? "Workout" : session.title,
                    fireDate: fireDate
                )
            }
            .sorted { $0.fireDate < $1.fireDate }
    }
}
