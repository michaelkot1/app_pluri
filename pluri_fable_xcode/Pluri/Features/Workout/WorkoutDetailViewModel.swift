import Foundation
import Observation

/// Workout Detail actions (M4-05/06): skip via `PlanStore`, workout notes via
/// the local session repository (creating/resuming a session on first save).
@MainActor
@Observable
final class WorkoutDetailViewModel {
    private(set) var notesDraft = ""
    private(set) var isSkipping = false
    var errorMessage: String?

    private let sessionID: UUID
    private let repository: any WorkoutSessionRepository
    private let userIDProvider: () -> UUID?

    init(
        sessionID: UUID,
        repository: any WorkoutSessionRepository,
        userIDProvider: @escaping () -> UUID?
    ) {
        self.sessionID = sessionID
        self.repository = repository
        self.userIDProvider = userIDProvider
    }

    /// Loads existing workout-level notes from an in-progress (or none).
    func loadNotes() {
        errorMessage = nil
        guard let session = try? repository.inProgressSession(for: sessionID) else {
            notesDraft = ""
            return
        }
        notesDraft = session.notes ?? ""
    }

    func updateNotesDraft(_ text: String) {
        notesDraft = text
    }

    /// First Notes save from Detail creates/resumes the in-progress session,
    /// then writes notes (SPEC §14 #53 — interim, reversible).
    func saveNotes() {
        errorMessage = nil
        guard let userID = userIDProvider() else {
            errorMessage = PlanMutationError.missingUser.userFacingMessage
            return
        }

        do {
            let session = try repository.startOrResume(
                planWorkoutId: sessionID,
                userId: userID
            )
            let trimmed = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            try repository.updateWorkoutNotes(
                sessionId: session.id,
                notes: trimmed.isEmpty ? nil : trimmed
            )
            notesDraft = trimmed
        } catch {
            errorMessage = PlanChangeErrorMessage.message(for: error)
        }
    }

    /// Skips a `.scheduled` workout, then discards any local in-progress
    /// session so Skip doesn't orphan progress (SPEC §14 #53).
    func skip(using planStore: PlanStore) async {
        guard !isSkipping else { return }
        isSkipping = true
        errorMessage = nil
        defer { isSkipping = false }

        do {
            try await planStore.skipWorkout(id: sessionID)
            if let inProgress = try? repository.inProgressSession(for: sessionID) {
                try? repository.discard(sessionId: inProgress.id)
            }
        } catch {
            errorMessage = PlanChangeErrorMessage.message(for: error)
        }
    }
}
