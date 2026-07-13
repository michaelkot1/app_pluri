import Foundation

/// One page of the exercise catalog, as returned by `WorkoutXClient.fetchExercises`.
struct WorkoutXExercisePage: Sendable {
    let exercises: [Exercise]

    /// Total number of exercises in the full catalog (not just this page).
    let total: Int
}

/// Fetches the exercise catalog. Abstracted behind a protocol so a live
/// `URLSession`-backed implementation and a deterministic mock (for
/// previews/tests) can share call sites — see PLAN §3.
protocol WorkoutXClient: Sendable {
    /// Fetches one page of the exercise catalog, most-stable-ordering first.
    func fetchExercises(limit: Int, offset: Int) async throws -> WorkoutXExercisePage

    /// Fetches a single exercise by its catalog id.
    func fetchExercise(id: String) async throws -> Exercise
}

extension WorkoutXClient {
    /// Fetches the entire catalog by paging through `fetchExercises`.
    ///
    /// The catalog is ~1,300 exercises and rarely changes, so callers should
    /// prefer the SwiftData-backed `ExerciseCatalogStore` (which calls this
    /// only on a staleness-based refresh) over calling this directly.
    func fetchFullCatalog(pageSize: Int = 100) async throws -> [Exercise] {
        var offset = 0
        var all: [Exercise] = []
        while true {
            let page = try await fetchExercises(limit: pageSize, offset: offset)
            guard !page.exercises.isEmpty else { break }
            all.append(contentsOf: page.exercises)
            offset += page.exercises.count
            if all.count >= page.total { break }
        }
        return all
    }
}
