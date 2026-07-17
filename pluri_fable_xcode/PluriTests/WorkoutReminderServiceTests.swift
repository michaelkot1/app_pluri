import Foundation
import Testing
import UserNotifications
@testable import Pluri

/// M3-15 / M3-16 — the real `WorkoutReminderService`: explicit opt-in,
/// authorized vs denied permission, scheduling at 8 AM local, cancel on
/// disable / completed / past, and idempotent reconcile (SPEC §14 #48).
@Suite("WorkoutReminderService")
@MainActor
struct WorkoutReminderServiceTests {
    // MARK: - Fixtures

    private let calendar = Calendar.current

    /// A Monday at start-of-day, walked forward from a fixed epoch so the
    /// fixture is deterministic in any time zone.
    private var monday: Date {
        var date = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_752_364_800))
        while calendar.component(.weekday, from: date) != Weekday.monday.rawValue {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: monday) ?? monday
    }

    /// 8:00 AM local on `day(offset)`.
    private func eightAM(onDayOffset offset: Int) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: day(offset))
        components.hour = WorkoutReminderCandidate.fireHour
        return calendar.date(from: components) ?? day(offset)
    }

    private func makeSession(
        id: UUID = UUID(),
        title: String,
        dayOffset: Int?,
        status: WorkoutStatus = .scheduled,
        orderIndex: Int
    ) -> PlannedSession {
        let date = dayOffset.map(day)
        return PlannedSession(
            id: id,
            title: title,
            indexInWeek: orderIndex + 1,
            weekday: date.flatMap { Weekday(rawValue: calendar.component(.weekday, from: $0)) },
            date: date,
            status: status,
            workoutType: .weights,
            orderIndex: orderIndex,
            durationMinutes: 45,
            exercises: []
        )
    }

    private func makePlan(sessions: [PlannedSession]) -> GeneratedPlan {
        GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .scheduled,
            sessionDurationMinutes: 45,
            startDate: monday,
            weeks: [PlanWeek(number: 1, sessions: sessions)],
            seed: 1
        )
    }

    private func makeService(
        center: MockUserNotificationCenterClient = MockUserNotificationCenterClient(),
        userID: String? = "user-a",
        optedIn: Bool = false,
        now: Date? = nil
    ) -> (service: WorkoutReminderService, center: MockUserNotificationCenterClient, defaults: UserDefaults) {
        let suiteName = "pluri.tests.reminders.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(optedIn, forKey: WorkoutReminderService.preferenceKey(forUserID: userID))

        let service = WorkoutReminderService(
            center: center,
            defaults: defaults,
            calendar: calendar,
            userIDProvider: { userID }
        )
        if let now {
            service.now = { now }
        } else {
            // Default "now" is Monday 07:00 — before today's 8 AM fire, so a
            // today-dated session is still eligible.
            let sevenAM = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: monday) ?? monday
            service.now = { sevenAM }
        }
        return (service, center, defaults)
    }

    // MARK: - Opt-in / permission

    @Test("Opting in requests authorization and schedules when granted")
    func optInRequestsAuthorizationAndSchedules() async {
        let center = MockUserNotificationCenterClient()
        center.currentStatus = .notDetermined
        center.grantsAuthorization = true
        let (service, _, _) = makeService(center: center)

        let workoutID = UUID()
        let plan = makePlan(sessions: [
            makeSession(id: workoutID, title: "Push Day", dayOffset: 2, orderIndex: 0),
        ])

        await service.setRemindersEnabled(true, plan: plan)

        #expect(center.requestAuthorizationCount == 1)
        #expect(service.isRemindersEnabled)
        #expect(!service.isSystemPermissionDenied)
        #expect(center.pendingRequests.map(\.identifier) == [
            WorkoutReminderCandidate.identifierPrefix + workoutID.uuidString,
        ])
    }

    @Test("Denial reverts the toggle, persists opted-out, and cancels")
    func denialRevertsToggleAndCancels() async {
        let center = MockUserNotificationCenterClient()
        center.currentStatus = .notDetermined
        center.grantsAuthorization = false
        let (service, _, defaults) = makeService(center: center, userID: "user-a")

        let plan = makePlan(sessions: [
            makeSession(title: "Push Day", dayOffset: 2, orderIndex: 0),
        ])
        await service.setRemindersEnabled(true, plan: plan)

        #expect(!service.isRemindersEnabled)
        #expect(service.isSystemPermissionDenied)
        #expect(defaults.bool(forKey: WorkoutReminderService.preferenceKey(forUserID: "user-a")) == false)
        #expect(center.pendingRequests.isEmpty)
    }

    @Test("Already-denied status never re-prompts and keeps the toggle off")
    func alreadyDeniedDoesNotReprompt() async {
        let center = MockUserNotificationCenterClient()
        center.currentStatus = .denied
        let (service, _, _) = makeService(center: center)

        await service.setRemindersEnabled(true, plan: nil)

        #expect(center.requestAuthorizationCount == 0)
        #expect(!service.isRemindersEnabled)
        #expect(service.isSystemPermissionDenied)
    }

    // MARK: - Scheduling filters

    @Test("Authorized + opted-in schedules only dated scheduled sessions at 8 AM local")
    func schedulesDatedScheduledAtEightAM() async throws {
        let center = MockUserNotificationCenterClient()
        center.currentStatus = .authorized
        let (service, _, _) = makeService(center: center, optedIn: true)

        let keepID = UUID()
        let plan = makePlan(sessions: [
            makeSession(id: keepID, title: "Keep Me", dayOffset: 2, orderIndex: 0),
            makeSession(title: "Flexible", dayOffset: nil, orderIndex: 1),
            makeSession(title: "Done", dayOffset: 3, status: .completed, orderIndex: 2),
            makeSession(title: "Skipped", dayOffset: 4, status: .skipped, orderIndex: 3),
        ])

        await service.reconcileReminders(for: plan)

        #expect(center.pendingRequests.count == 1)
        let request = try #require(center.pendingRequests.first)
        #expect(request.identifier == WorkoutReminderCandidate.identifierPrefix + keepID.uuidString)
        #expect(request.content.title == "Keep Me")
        #expect(request.content.body == "Time for today's workout.")

        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 8)
        #expect(trigger.dateComponents.day == calendar.component(.day, from: day(2)))
    }

    @Test("A today session whose 8 AM fire time already passed is skipped")
    func skipsPastFireTimeToday() async {
        let center = MockUserNotificationCenterClient()
        center.currentStatus = .authorized
        // Now is Monday 09:00 — today's 8 AM fire has already passed.
        let nineAM = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: monday) ?? monday
        let (service, _, _) = makeService(center: center, optedIn: true, now: nineAM)

        let todayID = UUID()
        let tomorrowID = UUID()
        let plan = makePlan(sessions: [
            makeSession(id: todayID, title: "Today", dayOffset: 0, orderIndex: 0),
            makeSession(id: tomorrowID, title: "Tomorrow", dayOffset: 1, orderIndex: 1),
        ])

        await service.reconcileReminders(for: plan)

        #expect(center.pendingRequests.map(\.identifier) == [
            WorkoutReminderCandidate.identifierPrefix + tomorrowID.uuidString,
        ])
    }

    @Test("Empty title falls back to Workout")
    func emptyTitleFallsBack() {
        let candidates = WorkoutReminderCandidate.candidates(
            in: makePlan(sessions: [
                makeSession(title: "", dayOffset: 2, orderIndex: 0),
            ]),
            now: eightAM(onDayOffset: 0).addingTimeInterval(-3600),
            calendar: calendar
        )
        #expect(candidates.map(\.title) == ["Workout"])
    }

    // MARK: - Move / cancel / disable / idempotence

    @Test("Moving a workout updates the same identifier's fire date")
    func moveUpdatesSameIdentifier() async throws {
        let center = MockUserNotificationCenterClient()
        center.currentStatus = .authorized
        let (service, _, _) = makeService(center: center, optedIn: true)

        let workoutID = UUID()
        let original = makePlan(sessions: [
            makeSession(id: workoutID, title: "Push", dayOffset: 2, orderIndex: 0),
        ])
        await service.reconcileReminders(for: original)
        #expect(center.pendingRequests.count == 1)

        let moved = makePlan(sessions: [
            makeSession(id: workoutID, title: "Push", dayOffset: 5, orderIndex: 0),
        ])
        await service.reconcileReminders(for: moved)

        #expect(center.pendingRequests.count == 1)
        let request = try #require(center.pendingRequests.first)
        #expect(request.identifier == WorkoutReminderCandidate.identifierPrefix + workoutID.uuidString)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.day == calendar.component(.day, from: day(5)))
    }

    @Test("Completed, deleted, and past sessions are cancelled after reconcile")
    func cancelsCompletedDeletedPast() async {
        let center = MockUserNotificationCenterClient()
        center.currentStatus = .authorized
        let (service, _, _) = makeService(center: center, optedIn: true)

        let keepID = UUID()
        let dropID = UUID()
        let initial = makePlan(sessions: [
            makeSession(id: keepID, title: "Keep", dayOffset: 2, orderIndex: 0),
            makeSession(id: dropID, title: "Drop", dayOffset: 3, orderIndex: 1),
        ])
        await service.reconcileReminders(for: initial)
        #expect(center.pendingRequests.count == 2)

        // Drop is now completed; Keep remains scheduled.
        let updated = makePlan(sessions: [
            makeSession(id: keepID, title: "Keep", dayOffset: 2, orderIndex: 0),
            makeSession(id: dropID, title: "Drop", dayOffset: 3, status: .completed, orderIndex: 1),
        ])
        await service.reconcileReminders(for: updated)

        #expect(center.pendingRequests.map(\.identifier) == [
            WorkoutReminderCandidate.identifierPrefix + keepID.uuidString,
        ])
        #expect(center.removedIdentifiers.contains(WorkoutReminderCandidate.identifierPrefix + dropID.uuidString))
    }

    @Test("Disabling reminders cancels all pending workout reminders")
    func disableCancelsAll() async {
        let center = MockUserNotificationCenterClient()
        center.currentStatus = .authorized
        let (service, _, _) = makeService(center: center, optedIn: true)

        let plan = makePlan(sessions: [
            makeSession(title: "A", dayOffset: 2, orderIndex: 0),
            makeSession(title: "B", dayOffset: 3, orderIndex: 1),
        ])
        await service.reconcileReminders(for: plan)
        #expect(center.pendingRequests.count == 2)

        await service.setRemindersEnabled(false, plan: plan)

        #expect(!service.isRemindersEnabled)
        #expect(center.pendingRequests.isEmpty)
    }

    @Test("Repeated reconcile is idempotent for the same desired set")
    func repeatedReconcileIsIdempotent() async {
        let center = MockUserNotificationCenterClient()
        center.currentStatus = .authorized
        let (service, _, _) = makeService(center: center, optedIn: true)

        let a = UUID()
        let b = UUID()
        let plan = makePlan(sessions: [
            makeSession(id: a, title: "A", dayOffset: 2, orderIndex: 0),
            makeSession(id: b, title: "B", dayOffset: 3, orderIndex: 1),
        ])

        await service.reconcileReminders(for: plan)
        let firstIDs = Set(center.pendingRequests.map(\.identifier))
        await service.reconcileReminders(for: plan)
        let secondIDs = Set(center.pendingRequests.map(\.identifier))

        #expect(firstIDs == secondIDs)
        #expect(secondIDs.count == 2)
    }

    @Test("Reconcile never throws when the center fails to add")
    func reconcileSwallowsCenterErrors() async {
        struct Boom: Error {}
        let center = MockUserNotificationCenterClient()
        center.currentStatus = .authorized
        center.addError = Boom()
        let (service, _, _) = makeService(center: center, optedIn: true)

        let plan = makePlan(sessions: [
            makeSession(title: "A", dayOffset: 2, orderIndex: 0),
        ])

        // Must not throw.
        await service.reconcileReminders(for: plan)
        #expect(center.pendingRequests.isEmpty)
    }

    @Test("Opted-out reconcile cancels without scheduling")
    func optedOutCancelsWithoutScheduling() async {
        let center = MockUserNotificationCenterClient()
        center.currentStatus = .authorized
        // Seed a leftover pending reminder as if a previous opt-in left it.
        let leftoverID = WorkoutReminderCandidate.identifierPrefix + UUID().uuidString
        let leftover = UNNotificationRequest(
            identifier: leftoverID,
            content: UNMutableNotificationContent(),
            trigger: nil
        )
        center.pendingRequests = [leftover]

        let (service, _, _) = makeService(center: center, optedIn: false)
        let plan = makePlan(sessions: [
            makeSession(title: "A", dayOffset: 2, orderIndex: 0),
        ])

        await service.reconcileReminders(for: plan)

        #expect(center.pendingRequests.isEmpty)
        #expect(center.removedIdentifiers.contains(leftoverID))
        #expect(center.addedRequests.isEmpty)
    }

    @Test("Preference keys are user-scoped")
    func preferenceKeysAreUserScoped() {
        #expect(
            WorkoutReminderService.preferenceKey(forUserID: "alice")
                == "pluri.notifications.workoutRemindersEnabled.alice"
        )
        #expect(
            WorkoutReminderService.preferenceKey(forUserID: nil)
                == "pluri.notifications.workoutRemindersEnabled.device"
        )
    }
}
