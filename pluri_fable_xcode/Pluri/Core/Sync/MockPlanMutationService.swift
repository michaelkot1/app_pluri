import Foundation

/// In-memory mutation stand-in for previews and unit tests (M3-05): records
/// every call's row payloads so tests can assert exact call shapes, and can
/// fail the next call to exercise the store's optimistic rollback.
@MainActor
@Observable
final class MockPlanMutationService: PlanMutationServicing {
    struct MoveCall: Equatable {
        var planID: UUID
        var changedWorkouts: [PlanWorkoutInsertRow]
    }

    struct AddCall: Equatable {
        var planID: UUID
        var newWorkout: PlanWorkoutInsertRow
        var newExercises: [WorkoutExerciseInsertRow]
        var reorderedWorkouts: [PlanWorkoutInsertRow]
    }

    struct PlanSettingsCall: Equatable {
        var planID: UUID
        var update: PlanSettingsUpdateRow
    }

    struct ProfileSettingsCall: Equatable {
        var userID: UUID
        var update: ProfileSettingsUpdateRow
    }

    struct ReplaceCall: Equatable {
        var planID: UUID
        var insertingWorkouts: [PlanWorkoutInsertRow]
        var insertingExercises: [WorkoutExerciseInsertRow]
        var updatingWorkouts: [PlanWorkoutInsertRow]
        var deletingWorkoutIDs: [UUID]
    }

    struct ManagePlanCall: Equatable {
        var planID: UUID
        var planUpdate: PlanSettingsUpdateRow
        var profileUpdate: ProfileSettingsUpdateRow
        var insertingWorkouts: [PlanWorkoutInsertRow]
        var insertingExercises: [WorkoutExerciseInsertRow]
        var updatingWorkouts: [PlanWorkoutInsertRow]
        var deletingWorkoutIDs: [UUID]
    }

    /// Thrown by the next call, then cleared (matches the flush/restore mocks).
    var nextError: PluriSyncError?

    private(set) var moveCalls: [MoveCall] = []
    private(set) var addCalls: [AddCall] = []
    private(set) var planSettingsCalls: [PlanSettingsCall] = []
    private(set) var profileSettingsCalls: [ProfileSettingsCall] = []
    private(set) var replaceCalls: [ReplaceCall] = []
    private(set) var managePlanCalls: [ManagePlanCall] = []

    func moveWorkout(planID: UUID, changedWorkouts: [PlanWorkoutInsertRow]) async throws {
        try throwIfNeeded()
        moveCalls.append(MoveCall(planID: planID, changedWorkouts: changedWorkouts))
    }

    func addWorkout(
        planID: UUID,
        newWorkout: PlanWorkoutInsertRow,
        newExercises: [WorkoutExerciseInsertRow],
        reorderedWorkouts: [PlanWorkoutInsertRow]
    ) async throws {
        try throwIfNeeded()
        addCalls.append(
            AddCall(
                planID: planID,
                newWorkout: newWorkout,
                newExercises: newExercises,
                reorderedWorkouts: reorderedWorkouts
            )
        )
    }

    func updatePlanSettings(planID: UUID, update: PlanSettingsUpdateRow) async throws {
        try throwIfNeeded()
        planSettingsCalls.append(PlanSettingsCall(planID: planID, update: update))
    }

    func updateProfileSettings(userID: UUID, update: ProfileSettingsUpdateRow) async throws {
        try throwIfNeeded()
        profileSettingsCalls.append(ProfileSettingsCall(userID: userID, update: update))
    }

    func replaceRemainingWorkouts(
        planID: UUID,
        insertingWorkouts: [PlanWorkoutInsertRow],
        insertingExercises: [WorkoutExerciseInsertRow],
        updatingWorkouts: [PlanWorkoutInsertRow],
        deletingWorkoutIDs: [UUID]
    ) async throws {
        try throwIfNeeded()
        replaceCalls.append(
            ReplaceCall(
                planID: planID,
                insertingWorkouts: insertingWorkouts,
                insertingExercises: insertingExercises,
                updatingWorkouts: updatingWorkouts,
                deletingWorkoutIDs: deletingWorkoutIDs
            )
        )
    }

    func applyManagePlan(
        planID: UUID,
        planUpdate: PlanSettingsUpdateRow,
        profileUpdate: ProfileSettingsUpdateRow,
        insertingWorkouts: [PlanWorkoutInsertRow],
        insertingExercises: [WorkoutExerciseInsertRow],
        updatingWorkouts: [PlanWorkoutInsertRow],
        deletingWorkoutIDs: [UUID]
    ) async throws {
        try throwIfNeeded()
        managePlanCalls.append(
            ManagePlanCall(
                planID: planID,
                planUpdate: planUpdate,
                profileUpdate: profileUpdate,
                insertingWorkouts: insertingWorkouts,
                insertingExercises: insertingExercises,
                updatingWorkouts: updatingWorkouts,
                deletingWorkoutIDs: deletingWorkoutIDs
            )
        )
    }

    private func throwIfNeeded() throws {
        if let nextError {
            self.nextError = nil
            throw nextError
        }
    }
}
