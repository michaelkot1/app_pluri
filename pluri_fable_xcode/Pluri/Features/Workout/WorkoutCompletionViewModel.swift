import Foundation
import Observation

/// Completion summary (M4-12/13/14/19): Discard / Save, optional Apple Health write,
/// per-exercise results, then plan check-off via `PlanStore.markWorkoutCompleted`.
@MainActor
@Observable
final class WorkoutCompletionViewModel {
    struct SetResult: Identifiable, Equatable, Sendable {
        var id: UUID
        var setNumber: Int
        var reps: Int?
        var weightKg: Double?
        var durationSeconds: Int?
    }

    struct ExerciseResult: Identifiable, Equatable, Sendable {
        var id: String
        var exerciseName: String
        var sets: [SetResult]
    }

    private(set) var workoutName = "Workout"
    private(set) var datePerformed = Date.now
    private(set) var plannedDurationMinutes = 0
    private(set) var actualDurationSeconds = 0
    private(set) var totalReps = 0
    /// Per-exercise set logs for the post-Save results review (SPEC §14 #56).
    private(set) var exerciseResults: [ExerciseResult] = []
    /// Prefills from the in-progress session notes (SPEC §14 #56).
    var notesDraft = ""
    /// Default **off** — opt-in only (SPEC §14 #56).
    var syncToAppleHealth = false
    private(set) var isSaving = false
    private(set) var isDiscarding = false
    /// True after Discard, or after the user taps Done following Save.
    private(set) var didFinish = false
    /// True after local complete + plan check-off succeeded (Health may still have failed).
    private(set) var didSaveLocally = false
    var errorMessage: String?
    /// Soft inline Health failure copy — never blocks or rolls back Save (SPEC §14 #56).
    var healthSyncMessage: String?

    private let planWorkoutID: UUID
    private let workoutSessionID: UUID
    private let elapsedSecondsHint: Int
    private let repository: any WorkoutSessionRepository
    private let healthWriter: any WorkoutHealthWriting
    private var activityType = "workout"
    private var startedAt = Date.now
    private var usesImperialUnits = false

    init(
        planWorkoutID: UUID,
        workoutSessionID: UUID,
        elapsedSecondsHint: Int,
        repository: any WorkoutSessionRepository,
        healthWriter: (any WorkoutHealthWriting)? = nil
    ) {
        self.planWorkoutID = planWorkoutID
        self.workoutSessionID = workoutSessionID
        self.elapsedSecondsHint = elapsedSecondsHint
        self.repository = repository
        self.healthWriter = healthWriter ?? MockWorkoutHealthWriter()
        self.actualDurationSeconds = max(0, elapsedSecondsHint)
    }

    var plannedDurationLabel: String {
        Duration.seconds(plannedDurationMinutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    var actualDurationLabel: String {
        WorkoutScreenViewModel.formatElapsed(actualDurationSeconds)
    }

    var datePerformedLabel: String {
        datePerformed.formatted(date: .abbreviated, time: .omitted)
    }

    /// Loads plan title / planned duration and session totals / notes / set logs.
    func load(using planStore: PlanStore) {
        errorMessage = nil
        healthSyncMessage = nil
        usesImperialUnits = planStore.profile?.units == "imperial"

        if let plan = planStore.plan,
           let session = PlanMutator.session(withID: planWorkoutID, in: plan)
        {
            workoutName = session.title
            plannedDurationMinutes = session.durationMinutes
        }

        guard let record = try? repository.session(id: workoutSessionID) else {
            actualDurationSeconds = max(0, elapsedSecondsHint)
            exerciseResults = []
            return
        }

        startedAt = record.startedAt
        // Date performed = calendar day of `startedAt` (SPEC §14 #56).
        datePerformed = Calendar.current.startOfDay(for: record.startedAt)
        activityType = record.activityType
        notesDraft = record.notes ?? ""
        actualDurationSeconds = record.durationSeconds
            ?? record.accumulatedActiveSeconds
        if actualDurationSeconds == 0 {
            actualDurationSeconds = max(0, elapsedSecondsHint)
        }
        totalReps = record.setLogs.reduce(0) { partial, log in
            partial + (log.reps ?? 0)
        }
        exerciseResults = Self.groupedExerciseResults(from: record.setLogs)
    }

    /// Formats a set line in the spirit of Insights `setLine` (kg/lb from profile).
    func setLine(for set: SetResult) -> String {
        var parts = ["Set \(set.setNumber.formatted(.number))"]
        if let reps = set.reps {
            parts.append("\(reps.formatted(.number)) reps")
        }
        if let weightKg = set.weightKg {
            if usesImperialUnits {
                let pounds = Measurement(value: weightKg, unit: UnitMass.kilograms)
                    .converted(to: .pounds)
                    .value
                parts.append(
                    "\(pounds.formatted(.number.precision(.fractionLength(0...1)))) lb"
                )
            } else {
                parts.append(
                    "\(weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg"
                )
            }
        }
        if let durationSeconds = set.durationSeconds, durationSeconds > 0 {
            parts.append(
                Duration.seconds(durationSeconds)
                    .formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated))
            )
        }
        return parts.joined(separator: " · ")
    }

    func updateNotesDraft(_ text: String) {
        notesDraft = text
    }

    /// Drops the local session only — plan stays `.scheduled` (SPEC §14 #50b / #52d).
    func discard() async {
        guard !isDiscarding, !isSaving, !didSaveLocally else { return }
        isDiscarding = true
        errorMessage = nil
        healthSyncMessage = nil
        defer { isDiscarding = false }

        do {
            try repository.discard(sessionId: workoutSessionID)
            didFinish = true
        } catch {
            errorMessage = PlanChangeErrorMessage.message(for: error)
        }
    }

    /// Save order (M4-14): local `complete` → optional Health → `markWorkoutCompleted`.
    /// Health failure leaves `syncedToHealth` false, sets a soft message, never rolls back.
    func save(using planStore: PlanStore) async {
        guard !isSaving, !isDiscarding, !didSaveLocally else { return }
        isSaving = true
        errorMessage = nil
        healthSyncMessage = nil
        defer { isSaving = false }

        let trimmedNotes = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        let endedAt = Date.now
        let duration = max(0, actualDurationSeconds)

        do {
            try repository.complete(
                sessionId: workoutSessionID,
                endedAt: endedAt,
                durationSeconds: duration,
                notes: notes
            )
            notesDraft = trimmedNotes

            if syncToAppleHealth {
                await writeHealthBestEffort(
                    startedAt: startedAt,
                    endedAt: endedAt,
                    durationSeconds: duration
                )
            }

            try await planStore.markWorkoutCompleted(
                id: planWorkoutID,
                sessionId: workoutSessionID
            )

            didSaveLocally = true
            // Stay on completion for results review (and soft Health message if any);
            // Done dismisses (SPEC §14 #56).
        } catch {
            errorMessage = PlanChangeErrorMessage.message(for: error)
        }
    }

    /// After Save, user reviews results (and any soft Health message) then leaves.
    func acknowledgeHealthMessageAndFinish() {
        guard didSaveLocally else { return }
        healthSyncMessage = nil
        didFinish = true
    }

    static func groupedExerciseResults(from logs: [SetLogRecord]) -> [ExerciseResult] {
        let sorted = logs.sorted {
            if $0.exerciseName != $1.exerciseName {
                return $0.exerciseName.localizedStandardCompare($1.exerciseName)
                    == .orderedAscending
            }
            return $0.setNumber < $1.setNumber
        }
        var results: [ExerciseResult] = []
        for log in sorted {
            let set = SetResult(
                id: log.id,
                setNumber: log.setNumber,
                reps: log.reps,
                weightKg: log.weightKg,
                durationSeconds: log.durationSeconds
            )
            if let index = results.firstIndex(where: { $0.exerciseName == log.exerciseName }) {
                results[index].sets.append(set)
            } else {
                results.append(
                    ExerciseResult(
                        id: log.exerciseName,
                        exerciseName: log.exerciseName,
                        sets: [set]
                    )
                )
            }
        }
        return results
    }

    private func writeHealthBestEffort(
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int
    ) async {
        await healthWriter.requestAuthorization()
        do {
            try await healthWriter.writeWorkout(
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                activityType: activityType
            )
            try repository.markSyncedToHealth(sessionId: workoutSessionID)
        } catch {
            healthSyncMessage =
                "Couldn't sync this workout to Apple Health. Your workout is still saved."
        }
    }
}
