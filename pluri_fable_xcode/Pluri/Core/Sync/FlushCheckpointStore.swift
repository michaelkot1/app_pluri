import Foundation

/// Crash-safe interim checkpoint while flush is in flight (M2-14).
/// Stores mapped DTOs in UserDefaults until flush succeeds — not a SyncEngine.
enum FlushCheckpointStore {
    private static let defaultsKey = "pluri.flush.pendingCheckpoint"

    nonisolated struct Checkpoint: Codable, Sendable, Equatable {
        var userID: UUID
        var profile: ProfileUpsertRow
        var planTree: PlanTreeCheckpoint
        var savedAt: Date
    }

    nonisolated struct PlanTreeCheckpoint: Codable, Sendable, Equatable {
        var plan: PlanInsertRow
        var workouts: [PlanWorkoutInsertRow]
        var exercises: [WorkoutExerciseInsertRow]
    }

    static func save(_ checkpoint: Checkpoint) {
        guard let data = try? JSONEncoder().encode(checkpoint) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func load() -> Checkpoint? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(Checkpoint.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
