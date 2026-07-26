import Foundation
import Observation

/// Loads a completed session log for Insights detail (M5-17).
/// Used when the card has no `planWorkoutId` (manual "+") so plan Detail does not apply.
@MainActor
@Observable
final class InsightsCompletedSessionDetailViewModel {
    private let sessionID: UUID
    private let repository: any WorkoutSessionRepository
    private let planStore: PlanStore

    private(set) var title = "Activity"
    private(set) var subtitle = ""
    private(set) var notes: String?
    private(set) var durationSeconds = 0
    private(set) var distanceMeters: Double?
    private(set) var activityTypeLabel = "Workout"
    private(set) var isManualLog = false
    private(set) var startedAt: Date?
    private(set) var exercises: [WorkoutsListEngine.ExerciseSets] = []
    private(set) var loadErrorMessage: String?
    private(set) var isLoaded = false

    var usesImperialUnits: Bool {
        planStore.profile?.units == "imperial"
    }

    init(
        sessionID: UUID,
        repository: any WorkoutSessionRepository,
        planStore: PlanStore
    ) {
        self.sessionID = sessionID
        self.repository = repository
        self.planStore = planStore
    }

    func load() {
        do {
            guard let record = try repository.session(id: sessionID), record.endedAt != nil else {
                clearContent()
                loadErrorMessage = "We couldn't find that activity. Head back and pick another."
                isLoaded = true
                return
            }

            let planTitle = planTitle(for: record.planWorkoutId)
            title = WorkoutsListEngine.resolveDescription(
                planTitle: planTitle,
                notes: record.notes,
                activityType: record.activityType
            )
            activityTypeLabel = WorkoutsListEngine.activityTypeLabel(record.activityType)
            isManualLog = record.isManualLog
            notes = record.notes
            durationSeconds = max(0, record.durationSeconds ?? 0)
            distanceMeters = record.distanceMeters
            startedAt = record.startedAt

            var parts = [
                record.startedAt.formatted(date: .abbreviated, time: .shortened),
                activityTypeLabel,
            ]
            if record.isManualLog {
                parts.append("Manual")
            }
            subtitle = parts.joined(separator: " · ")

            let sortedLogs = record.setLogs.sorted {
                if $0.exerciseName != $1.exerciseName {
                    return $0.exerciseName.localizedStandardCompare($1.exerciseName) == .orderedAscending
                }
                return $0.setNumber < $1.setNumber
            }
            var grouped: [WorkoutsListEngine.ExerciseSets] = []
            for log in sortedLogs {
                let input = WorkoutsListEngine.SetLogInput(
                    id: log.id,
                    exerciseName: log.exerciseName,
                    setNumber: log.setNumber,
                    reps: log.reps,
                    weightKg: log.weightKg,
                    durationSeconds: log.durationSeconds
                )
                if let index = grouped.firstIndex(where: { $0.exerciseName == log.exerciseName }) {
                    grouped[index].sets.append(input)
                } else {
                    grouped.append(
                        WorkoutsListEngine.ExerciseSets(exerciseName: log.exerciseName, sets: [input])
                    )
                }
            }
            exercises = grouped
            loadErrorMessage = nil
            isLoaded = true
        } catch {
            clearContent()
            loadErrorMessage = "Couldn't load that activity."
            isLoaded = true
        }
    }

    private func clearContent() {
        title = "Activity"
        subtitle = ""
        notes = nil
        durationSeconds = 0
        distanceMeters = nil
        activityTypeLabel = "Workout"
        isManualLog = false
        startedAt = nil
        exercises = []
    }

    private func planTitle(for planWorkoutId: UUID?) -> String? {
        guard let planWorkoutId,
              let plan = planStore.plan
        else {
            return nil
        }
        return plan.weeks
            .flatMap(\.sessions)
            .first { $0.id == planWorkoutId }?
            .title
    }
}
