import Foundation
import SwiftData
import Testing
@testable import pluri_fable_xcode

/// Pins the root cause of the "plan generation always fails on fresh install"
/// bug and verifies the fix (Supabase-seeded catalog as the source —
/// SPEC §14 #25).
///
/// Root cause: the live WorkoutX free tier caps every `/exercises` response
/// at 10 rows regardless of the requested `limit`, so `fetchFullCatalog`
/// needed ~133 requests for the 1,327-exercise catalog and hit the
/// 30-requests/window burst limit (429) before completing. The refresh
/// failure left the SwiftData cache empty → `PlanEngineError.emptyCatalog`
/// on every attempt.
@Suite("Exercise catalog source")
struct ExerciseCatalogSourceTests {

    /// A client that mimics the live WorkoutX free tier: it serves at most
    /// `pageCap` rows per request no matter what `limit` the caller asks for,
    /// and rejects requests beyond a burst budget the way the API 429s.
    struct PageCappedClient: WorkoutXClient {
        let fixtures: [Exercise]
        let pageCap: Int
        let requestBudget: Int

        // Reference-typed counter so the Sendable struct can mutate it.
        final class Counter: @unchecked Sendable {
            var count = 0
        }
        let counter = Counter()

        func fetchExercises(limit: Int, offset: Int) async throws -> WorkoutXExercisePage {
            counter.count += 1
            guard counter.count <= requestBudget else {
                throw WorkoutXClientError.rateLimited
            }
            let page = fixtures.dropFirst(offset).prefix(min(limit, pageCap))
            return WorkoutXExercisePage(exercises: Array(page), total: fixtures.count)
        }

        func fetchExercise(id: String) async throws -> Exercise {
            guard let exercise = fixtures.first(where: { $0.id == id }) else {
                throw WorkoutXClientError.notFound
            }
            return exercise
        }
    }

    static func makeFixtures(count: Int) -> [Exercise] {
        (1...count).map { index in
            Exercise(
                id: String(format: "%04d", index),
                name: "Exercise \(index)",
                bodyPart: "Chest",
                equipment: "Body Weight",
                targetMuscle: "Pectorals",
                secondaryMuscles: [],
                instructions: [],
                imageURL: nil,
                videoURL: nil
            )
        }
    }

    @Test("fetchFullCatalog survives a server-side page cap smaller than pageSize")
    func fullCatalogSurvivesPageCap() async throws {
        let fixtures = Self.makeFixtures(count: 55)
        // Enough budget: 55 rows at 10/page = 6 requests.
        let client = PageCappedClient(fixtures: fixtures, pageCap: 10, requestBudget: 10)
        let all = try await client.fetchFullCatalog(pageSize: 100)
        #expect(all.count == 55)
        #expect(all.map(\.id) == fixtures.map(\.id))
    }

    @Test("Root cause: a page-capped, rate-limited source cannot deliver the catalog")
    func pageCapPlusRateLimitFailsFullFetch() async {
        // 1,327-row catalog at 10 rows/page needs 133 requests; the live API
        // allows ~30 per burst window. Reproduced in miniature here.
        let fixtures = Self.makeFixtures(count: 400)
        let client = PageCappedClient(fixtures: fixtures, pageCap: 10, requestBudget: 30)
        await #expect(throws: WorkoutXClientError.rateLimited) {
            _ = try await client.fetchFullCatalog(pageSize: 100)
        }
    }

    @Test("Fix: the full generation path succeeds from the Supabase-seeded catalog")
    func planGeneratesFromSupabaseCatalog() async throws {
        // End-to-end over the network: Supabase `exercises` (anon read) →
        // SwiftData cache → PlanEngine. This is the exact code path
        // `PlanGeneratingView` runs on a fresh install.
        let schema = Schema([CachedExercise.self, ExerciseCatalogSyncState.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ExerciseCatalogStore(
            modelContext: container.mainContext,
            client: SupabaseExerciseCatalogClient()
        )
        let service = PlanGenerationService(store: store)

        let input = PlanInput(
            goal: .buildMuscle,
            experience: .oneToSixMonths,
            regularity: .onAndOff,
            equipment: Set(EquipmentCatalog.all),
            injuries: [.back: 3],
            trainingDays: [.monday, .wednesday, .friday],
            scheduleType: .scheduled,
            planLengthWeeks: 6,
            sessionDurationMinutes: 60,
            startDate: .now
        )

        let plan = try await service.generatePlan(for: input)

        #expect(plan.weekCount == 6)
        #expect(plan.sessionsPerWeek == 3)
        // The full 1,327-row snapshot must have landed in the cache.
        let cached = try store.cachedExercises()
        #expect(cached.count > 1000)
        // And the injury filter must hold against the real catalog.
        for exercise in plan.weeks.flatMap({ $0.sessions.flatMap(\.exercises) }) {
            #expect(exercise.bodyPart != "Back")
        }
    }
}
