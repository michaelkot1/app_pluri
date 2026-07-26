import Foundation
import Observation

/// Best-effort Apple Health workout write on completion Save (M4-13).
/// Failures must never roll back the local session or plan check-off (SPEC §14 #50f).
@MainActor
protocol WorkoutHealthWriting: AnyObject {
    func requestAuthorization() async
    /// Persists a completed workout sample. Throws when HealthKit rejects the write.
    func writeWorkout(
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        activityType: String
    ) async throws
}

/// Test / preview double for Apple Health workout writes (M4-13).
@MainActor
@Observable
final class MockWorkoutHealthWriter: WorkoutHealthWriting {
    private(set) var authorizationRequestCount = 0
    private(set) var writeCalls: [WriteCall] = []
    /// When true, the next `writeWorkout` throws, then clears.
    var shouldFailNextWrite = false
    var isAuthorized = true

    struct WriteCall: Equatable, Sendable {
        var startedAt: Date
        var endedAt: Date
        var durationSeconds: Int
        var activityType: String
    }

    enum MockError: Error, Equatable {
        case writeFailed
    }

    func requestAuthorization() async {
        authorizationRequestCount += 1
        isAuthorized = true
    }

    func writeWorkout(
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        activityType: String
    ) async throws {
        writeCalls.append(
            WriteCall(
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                activityType: activityType
            )
        )
        if shouldFailNextWrite {
            shouldFailNextWrite = false
            throw MockError.writeFailed
        }
    }
}
