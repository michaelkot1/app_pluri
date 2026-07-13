import Foundation
import os.log

/// Thin async wrapper around the pure `PlanEngine` (M1-16): loads the exercise
/// catalog from the offline-first `ExerciseCatalogStore` (refreshing from
/// WorkoutX only if stale), then runs the deterministic engine off the main
/// actor.
///
/// The engine itself stays pure and `nonisolated`; this service exists only to
/// bridge it to the `@MainActor` store and to keep heavy work off the main
/// actor. It's the client-side stand-in for the future `generate-plan` Edge
/// Function (PLAN §1.3).
@MainActor
@Observable
final class PlanGenerationService {
    private let store: ExerciseCatalogStore
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "PlanGenerationService")

    init(store: ExerciseCatalogStore) {
        self.store = store
    }

    /// Generates a plan for the given input, refreshing the catalog first if
    /// needed. Throws `PlanEngineError` on an empty catalog or when no
    /// exercises survive the equipment/injury filters.
    func generatePlan(for input: PlanInput) async throws -> GeneratedPlan {
        await store.refreshIfNeeded()

        let catalog = try store.cachedExercises()
        guard !catalog.isEmpty else {
            logger.error("Plan generation failed: exercise catalog is empty")
            throw PlanEngineError.emptyCatalog
        }

        let seed = input.deterministicSeed
        // The engine is pure and `Sendable`-friendly, so run it off the main
        // actor to keep the "Generating…" animation smooth.
        return try await Task.detached(priority: .userInitiated) {
            try PlanEngine.generate(input: input, catalog: catalog, seed: seed)
        }.value
    }
}
