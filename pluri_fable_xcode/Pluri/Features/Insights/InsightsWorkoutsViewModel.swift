import Foundation
import Observation

/// Loads completed sessions for the Insights Workouts tab (M5-11 / M5-13).
@MainActor
@Observable
final class InsightsWorkoutsViewModel {
    private let repository: any WorkoutSessionRepository
    private let planStore: PlanStore
    private let calendar: Calendar

    var monthGroups: [WorkoutsListEngine.MonthGroup] = []
    /// When set, only sessions performed on this calendar day are shown (M5-13).
    var dayFilter: Date?
    var loadErrorMessage: String?
    private var allSessions: [WorkoutsListEngine.SessionInput] = []

    init(
        repository: any WorkoutSessionRepository,
        planStore: PlanStore,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.planStore = planStore
        self.calendar = calendar
    }

    var isEmpty: Bool {
        monthGroups.isEmpty && loadErrorMessage == nil
    }

    var hasDayFilter: Bool { dayFilter != nil }

    var dayFilterLabel: String? {
        guard let dayFilter else { return nil }
        return dayFilter.formatted(date: .abbreviated, time: .omitted)
    }

    var usesImperialUnits: Bool {
        planStore.profile?.units == "imperial"
    }

    func refresh() {
        do {
            let records = try repository.fetchAllCompletedSessions()
            allSessions = records.map { record in
                let planTitle = planTitle(for: record.planWorkoutId)
                let description = WorkoutsListEngine.resolveDescription(
                    planTitle: planTitle,
                    notes: record.notes,
                    activityType: record.activityType
                )
                return WorkoutsListEngine.SessionInput(
                    id: record.id,
                    startedAt: record.startedAt,
                    durationSeconds: record.durationSeconds,
                    distanceMeters: record.distanceMeters,
                    activityType: record.activityType,
                    isManualLog: record.isManualLog,
                    planWorkoutId: record.planWorkoutId,
                    description: description,
                    setLogs: record.setLogs.map { log in
                        WorkoutsListEngine.SetLogInput(
                            id: log.id,
                            exerciseName: log.exerciseName,
                            setNumber: log.setNumber,
                            reps: log.reps,
                            weightKg: log.weightKg,
                            durationSeconds: log.durationSeconds
                        )
                    }
                )
            }
            rebuildGroups()
            loadErrorMessage = nil
        } catch {
            allSessions = []
            monthGroups = []
            loadErrorMessage = "Couldn't load workouts yet."
        }
    }

    func applyDayFilter(_ date: Date) {
        dayFilter = calendar.startOfDay(for: date)
        rebuildGroups()
    }

    func clearDayFilter() {
        dayFilter = nil
        rebuildGroups()
    }

    private func rebuildGroups() {
        monthGroups = WorkoutsListEngine.groupByMonth(
            sessions: allSessions,
            calendar: calendar,
            dayFilter: dayFilter
        )
    }

    private func planTitle(for planWorkoutId: UUID?) -> String? {
        guard let planWorkoutId,
              let plan = planStore.plan
        else { return nil }
        return plan.weeks
            .flatMap(\.sessions)
            .first { $0.id == planWorkoutId }?
            .title
    }
}
