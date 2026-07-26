import Foundation
import Observation

/// Live Workout Screen (M4-09/10/11): running timer, Pause / Resume / Stop (= pause),
/// hold-to-finish → completion, inline set logging, and HealthKit metrics while unpaused.
@MainActor
@Observable
final class WorkoutScreenViewModel {
    /// Soft flag: a local in-progress session exists (after Start or Detail Notes).
    private(set) var isSessionInProgress = false
    /// Live timer has begun (Screen Start); soft Detail-notes sessions stay false.
    private(set) var hasStartedLiveTimer = false
    private(set) var isRunning = false
    private(set) var isPaused = false
    private(set) var displayedElapsedSeconds = 0
    private(set) var workoutSessionID: UUID?
    private(set) var exerciseNotesDraft: [UUID: String] = [:]
    private(set) var loggedSetCountByExercise: [UUID: Int] = [:]
    /// Increments on successful log for sensory feedback.
    private(set) var logFeedbackTick = 0
    var errorMessage: String?
    var selectedExerciseID: UUID?
    /// Ask Pluri honest stub visibility (SPEC §14 #50e).
    var showsAskPluriStub = false
    /// Set when hold-to-finish hands off to the completion summary (M4-12 / §14 #55c).
    private(set) var pendingCompletion: WorkoutCompletionHandoff?

    private let sessionID: UUID
    private let repository: any WorkoutSessionRepository
    private let userIDProvider: () -> UUID?
    private let catalogLookup: (String) -> Exercise?
    private let syncEngine: (any SyncEngine)?
    private let healthMetrics: any WorkoutHealthMetricsProviding
    private let usesImperialUnits: () -> Bool

    private var tickTask: Task<Void, Never>?

    init(
        sessionID: UUID,
        repository: any WorkoutSessionRepository,
        userIDProvider: @escaping () -> UUID?,
        catalogLookup: @escaping (String) -> Exercise? = { _ in nil },
        syncEngine: (any SyncEngine)? = nil,
        healthMetrics: (any WorkoutHealthMetricsProviding)? = nil,
        usesImperialUnits: @escaping () -> Bool = { false }
    ) {
        self.sessionID = sessionID
        self.repository = repository
        self.userIDProvider = userIDProvider
        self.catalogLookup = catalogLookup
        self.syncEngine = syncEngine
        self.healthMetrics = healthMetrics ?? MockWorkoutHealthMetricsProvider()
        self.usesImperialUnits = usesImperialUnits
    }

    var heartRateDisplay: String {
        guard healthMetrics.isAuthorized, let bpm = healthMetrics.heartRateBPM else {
            return "—"
        }
        return bpm.formatted(.number.precision(.fractionLength(0)))
    }

    var caloriesDisplay: String {
        guard healthMetrics.isAuthorized, let kcal = healthMetrics.activeEnergyKilocalories else {
            return "—"
        }
        return kcal.formatted(.number.precision(.fractionLength(0)))
    }

    var formattedElapsed: String {
        Self.formatElapsed(displayedElapsedSeconds)
    }

    var showsLiveControls: Bool {
        hasStartedLiveTimer
    }

    /// Syncs pause / elapsed / notes after launch (SPEC §14 #50c).
    func refreshSessionState() {
        errorMessage = nil
        pendingCompletion = nil
        guard let session = try? repository.inProgressSession(for: sessionID) else {
            isSessionInProgress = false
            workoutSessionID = nil
            hasStartedLiveTimer = false
            isRunning = false
            isPaused = false
            displayedElapsedSeconds = 0
            loggedSetCountByExercise = [:]
            stopTickLoop()
            healthMetrics.stopStreaming()
            return
        }
        applySession(session)
        rebuildLoggedSetCounts(from: session)
        if isRunning {
            startTickLoop()
            startHealthStreamingIfNeeded()
        } else {
            stopTickLoop()
            healthMetrics.stopStreaming()
        }
    }

    /// Creates/resumes the local session and begins the running timer segment.
    func start() {
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
            workoutSessionID = session.id
            isSessionInProgress = true
            try repository.resume(sessionId: session.id)
            if let refreshed = try repository.session(id: session.id) {
                applySession(refreshed)
            }
            startTickLoop()
            Task {
                await healthMetrics.requestAuthorization()
                startHealthStreamingIfNeeded()
            }
        } catch {
            errorMessage = PlanChangeErrorMessage.message(for: error)
        }
    }

    func pause() {
        errorMessage = nil
        guard let workoutSessionID else { return }
        do {
            try repository.pause(sessionId: workoutSessionID)
            if let session = try repository.session(id: workoutSessionID) {
                applySession(session)
            }
            stopTickLoop()
            healthMetrics.stopStreaming()
        } catch {
            errorMessage = PlanChangeErrorMessage.message(for: error)
        }
    }

    func resume() {
        errorMessage = nil
        guard let workoutSessionID else { return }
        do {
            try repository.resume(sessionId: workoutSessionID)
            if let session = try repository.session(id: workoutSessionID) {
                applySession(session)
            }
            startTickLoop()
            startHealthStreamingIfNeeded()
        } catch {
            errorMessage = PlanChangeErrorMessage.message(for: error)
        }
    }

    /// Stop pauses the live timer (SPEC §14 #55c). Hold-to-finish is the only
    /// path to the completion summary.
    func stop() {
        pause()
    }

    /// Hold-to-finish: persist elapsed and prepare completion handoff.
    func finish() {
        finishHandoff()
    }

    func clearPendingCompletion() {
        pendingCompletion = nil
    }

    func selectExercise(_ exerciseID: UUID?) {
        selectedExerciseID = exerciseID
        if let exerciseID {
            loadExerciseNotesDraft(for: exerciseID)
        }
    }

    func updateExerciseNotesDraft(_ text: String, for exerciseID: UUID) {
        exerciseNotesDraft[exerciseID] = text
    }

    func notesDraft(for exerciseID: UUID) -> String {
        exerciseNotesDraft[exerciseID] ?? ""
    }

    func description(for exercise: PlannedExercise) -> String {
        guard let catalog = catalogLookup(exercise.exerciseID) else { return "" }
        let joined = catalog.instructions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        return joined
    }

    func catalogExercise(for exercise: PlannedExercise) -> Exercise? {
        catalogLookup(exercise.exerciseID)
    }

    /// Prefer the planned exercise's stored media URL; fall back to catalog.
    func resolvedImageURL(for exercise: PlannedExercise) -> URL? {
        exercise.imageURL ?? catalogLookup(exercise.exerciseID)?.imageURL
    }

    func saveExerciseNotes(for exerciseID: UUID) {
        errorMessage = nil
        guard let userID = userIDProvider() else {
            errorMessage = PlanMutationError.missingUser.userFacingMessage
            return
        }

        do {
            let session: WorkoutSessionRecord
            if let workoutSessionID, let existing = try repository.session(id: workoutSessionID) {
                session = existing
            } else {
                session = try repository.startOrResume(
                    planWorkoutId: sessionID,
                    userId: userID
                )
                workoutSessionID = session.id
                isSessionInProgress = true
            }

            let trimmed = notesDraft(for: exerciseID)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            try repository.updateExerciseNotes(
                sessionId: session.id,
                workoutExerciseId: exerciseID,
                notes: trimmed.isEmpty ? nil : trimmed
            )
            exerciseNotesDraft[exerciseID] = trimmed
            // Soft notes must not start the live timer (SPEC §14 #55).
            if let refreshed = try repository.session(id: session.id) {
                applySession(refreshed)
            }
        } catch {
            errorMessage = PlanChangeErrorMessage.message(for: error)
        }
    }

    /// Logs a set immediately (kg canonical). `weightDisplay` is in profile units.
    /// Rejects non-finite or negative weights; `nil` means bodyweight / omitted.
    func logSet(
        exercise: PlannedExercise,
        reps: Int,
        weightDisplay: Double?,
        durationSeconds: Int? = nil
    ) {
        errorMessage = nil
        if let weightDisplay, !(weightDisplay.isFinite && weightDisplay >= 0) {
            errorMessage = "Enter a valid weight, or leave it blank."
            return
        }
        guard let userID = userIDProvider() else {
            errorMessage = PlanMutationError.missingUser.userFacingMessage
            return
        }

        do {
            let session: WorkoutSessionRecord
            if let workoutSessionID, let existing = try repository.session(id: workoutSessionID) {
                session = existing
            } else {
                session = try repository.startOrResume(
                    planWorkoutId: sessionID,
                    userId: userID
                )
                workoutSessionID = session.id
                isSessionInProgress = true
            }

            let nextSet = (loggedSetCountByExercise[exercise.id] ?? 0) + 1
            let weightKg = Self.weightKilograms(
                displayValue: weightDisplay,
                usesImperial: usesImperialUnits()
            )
            _ = try repository.upsertSetLog(
                sessionId: session.id,
                id: nil,
                workoutExerciseId: exercise.id,
                exerciseName: exercise.name,
                setNumber: nextSet,
                reps: durationSeconds == nil ? reps : nil,
                weightKg: durationSeconds == nil ? weightKg : nil,
                durationSeconds: durationSeconds
            )
            loggedSetCountByExercise[exercise.id] = nextSet
            logFeedbackTick += 1
            syncEngine?.enqueueSession(id: session.id)
        } catch {
            errorMessage = PlanChangeErrorMessage.message(for: error)
        }
    }

    func tearDown() {
        stopTickLoop()
        healthMetrics.stopStreaming()
    }

    static func formatElapsed(_ totalSeconds: Int) -> String {
        let seconds = max(0, totalSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return "\(hours):\(pad2(minutes)):\(pad2(secs))"
        }
        return "\(pad2(minutes)):\(pad2(secs))"
    }

    static func weightKilograms(displayValue: Double?, usesImperial: Bool) -> Double? {
        guard let displayValue else { return nil }
        if usesImperial {
            return Measurement(value: displayValue, unit: UnitMass.pounds)
                .converted(to: .kilograms)
                .value
        }
        return displayValue
    }

    // MARK: - Private

    private func finishHandoff() {
        errorMessage = nil
        guard let workoutSessionID else { return }
        do {
            if isRunning {
                try repository.pause(sessionId: workoutSessionID)
            }
            if let session = try repository.session(id: workoutSessionID) {
                applySession(session)
                pendingCompletion = WorkoutCompletionHandoff(
                    planWorkoutID: sessionID,
                    workoutSessionID: session.id,
                    elapsedSeconds: session.accumulatedActiveSeconds
                )
            }
            stopTickLoop()
            healthMetrics.stopStreaming()
        } catch {
            errorMessage = PlanChangeErrorMessage.message(for: error)
        }
    }

    private func applySession(_ session: WorkoutSessionRecord) {
        workoutSessionID = session.id
        isSessionInProgress = session.isInProgress
        hasStartedLiveTimer = session.hasStartedLiveTimer
        isPaused = session.isPaused && session.hasStartedLiveTimer
        isRunning = session.hasStartedLiveTimer && !session.isPaused
        displayedElapsedSeconds = session.displayedElapsedSeconds()
        var drafts = exerciseNotesDraft
        for (key, note) in session.exerciseNotesByWorkoutExerciseId {
            if let exerciseID = UUID(uuidString: key) {
                drafts[exerciseID] = note
            }
        }
        exerciseNotesDraft = drafts
    }

    private func rebuildLoggedSetCounts(from session: WorkoutSessionRecord) {
        var counts: [UUID: Int] = [:]
        for log in session.setLogs {
            guard let exerciseID = log.workoutExerciseId else { continue }
            counts[exerciseID] = max(counts[exerciseID] ?? 0, log.setNumber)
        }
        loggedSetCountByExercise = counts
    }

    private func startTickLoop() {
        stopTickLoop()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.tickElapsed()
            }
        }
    }

    private func stopTickLoop() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func tickElapsed() {
        guard let workoutSessionID,
              let session = try? repository.session(id: workoutSessionID)
        else { return }
        displayedElapsedSeconds = session.displayedElapsedSeconds()
    }

    private func startHealthStreamingIfNeeded() {
        guard isRunning else {
            healthMetrics.stopStreaming()
            return
        }
        healthMetrics.startStreaming()
    }

    private func loadExerciseNotesDraft(for exerciseID: UUID) {
        if exerciseNotesDraft[exerciseID] != nil { return }
        guard
            let session = try? repository.inProgressSession(for: sessionID),
            let note = session.exerciseNotesByWorkoutExerciseId[exerciseID.uuidString]
        else {
            exerciseNotesDraft[exerciseID] = ""
            return
        }
        exerciseNotesDraft[exerciseID] = note
    }

    private static func pad2(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

/// Payload for navigating to the completion summary after hold-to-finish.
struct WorkoutCompletionHandoff: Equatable, Sendable {
    var planWorkoutID: UUID
    var workoutSessionID: UUID
    var elapsedSeconds: Int
}
