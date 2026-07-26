import Foundation
import SwiftData
import Testing
@testable import Pluri

/// M5-15 — Insights Performance / Workouts VM: unauthorized empty health copy,
/// day filter, and empty completed-session paths.
@Suite("InsightsViewModels")
@MainActor
struct InsightsViewModelTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            CachedExercise.self,
            ExerciseCatalogSyncState.self,
            WorkoutSessionRecord.self,
            SetLogRecord.self,
        ])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeRepository(
        in container: ModelContainer
    ) -> SwiftDataWorkoutSessionRepository {
        SwiftDataWorkoutSessionRepository(modelContext: container.mainContext)
    }

    @Test("Unauthorized health path uses Enable Health empty copy")
    func performanceUnauthorizedHealthEmptyCopy() async throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let healthKit = MockHealthKitReading(authorizationStatus: .denied)
        let viewModel = InsightsPerformanceViewModel(
            repository: repo,
            healthKit: healthKit,
            calendar: calendar,
            now: Date(timeIntervalSince1970: 1_784_073_600)
        )

        await viewModel.refreshHealthInsights()

        #expect(viewModel.healthAuthorizationStatus == .denied)
        #expect(viewModel.healthEmptyCopy == "Enable Health")
        // Engine still emits metric shells with nil averages; UI uses auth status
        // for the Enable Health card (SPEC §14 #61f).
        #expect(viewModel.healthInsights.allSatisfy { $0.recentAverage == nil })
        #expect(viewModel.isWeekEmpty)
        #expect(viewModel.isAllTimeEmpty)
    }

    @Test("Unavailable health path uses Not available empty copy")
    func performanceUnavailableHealthEmptyCopy() async throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let healthKit = MockHealthKitReading(authorizationStatus: .unavailable)
        let viewModel = InsightsPerformanceViewModel(
            repository: repo,
            healthKit: healthKit,
            calendar: calendar
        )

        await viewModel.refreshHealthInsights()

        #expect(viewModel.healthAuthorizationStatus == .unavailable)
        #expect(viewModel.healthEmptyCopy == "Not available")
        #expect(viewModel.healthInsights.allSatisfy { $0.recentAverage == nil })
    }

    @Test("Workouts day filter keeps matching startedAt day and clear restores all")
    func workoutsDayFilterAndClear() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planStore = PlanStore(mutationService: MockPlanMutationService())
        let dayA = Date(timeIntervalSince1970: 1_784_073_600) // 2026-07-15
        let dayB = dayA.addingTimeInterval(86_400)

        _ = try repo.createManualActivity(
            userId: UUID(),
            activityType: "workout",
            startedAt: dayA,
            durationSeconds: 600,
            distanceMeters: nil,
            notes: "Day A"
        )
        _ = try repo.createManualActivity(
            userId: UUID(),
            activityType: "cardio",
            startedAt: dayB,
            durationSeconds: 900,
            distanceMeters: 1_000,
            notes: "Day B"
        )

        let viewModel = InsightsWorkoutsViewModel(
            repository: repo,
            planStore: planStore,
            calendar: calendar
        )
        viewModel.refresh()
        #expect(viewModel.monthGroups.first?.workoutCount == 2)

        viewModel.applyDayFilter(dayA)
        #expect(viewModel.hasDayFilter)
        #expect(viewModel.monthGroups.count == 1)
        #expect(viewModel.monthGroups.first?.workoutCount == 1)
        #expect(viewModel.monthGroups.first?.workouts.first?.description == "Day A")

        viewModel.clearDayFilter()
        #expect(!viewModel.hasDayFilter)
        #expect(viewModel.monthGroups.first?.workoutCount == 2)
    }

    @Test("Empty repository yields empty Workouts groups")
    func workoutsEmptyPath() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let viewModel = InsightsWorkoutsViewModel(
            repository: repo,
            planStore: PlanStore(mutationService: MockPlanMutationService()),
            calendar: calendar
        )

        viewModel.refresh()

        #expect(viewModel.isEmpty)
        #expect(viewModel.monthGroups.isEmpty)
        #expect(viewModel.loadErrorMessage == nil)
    }
}
