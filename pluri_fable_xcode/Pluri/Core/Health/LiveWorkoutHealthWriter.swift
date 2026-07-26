import Foundation
import HealthKit
import Observation
import os.log

/// HealthKit-backed workout writer for completion Save (M4-13).
/// Best-effort only — callers must never roll back local session/plan on failure.
@MainActor
@Observable
final class LiveWorkoutHealthWriter: WorkoutHealthWriting {
    private let store: HKHealthStore
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "WorkoutHealthWrite")

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let toShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        do {
            try await store.requestAuthorization(toShare: toShare, read: [])
        } catch {
            logger.error("HealthKit share authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func writeWorkout(
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        activityType: String
    ) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WorkoutHealthWriteError.healthDataUnavailable
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = Self.hkActivityType(for: activityType)
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: startedAt)

        let end = max(endedAt, startedAt.addingTimeInterval(TimeInterval(max(durationSeconds, 0))))
        try await builder.endCollection(at: end)
        try await builder.finishWorkout()
        logger.info("Wrote workout to Apple Health (\(durationSeconds)s)")
    }

    private static func hkActivityType(for activityType: String) -> HKWorkoutActivityType {
        switch activityType {
        case "cardio":
            return .running
        case "flexibility":
            return .flexibility
        default:
            return .traditionalStrengthTraining
        }
    }
}

enum WorkoutHealthWriteError: Error, Equatable {
    case healthDataUnavailable
}
