import Foundation
import OSLog
import UserNotifications

/// The real local-notification reminder service (M3-15, SPEC §14 #48): owns
/// the user's opt-in preference, gates system permission behind explicit
/// opt-in, and implements the `WorkoutReminderReconciling` hook `PlanStore`
/// fires after every successful remote plan write (SPEC §14 #44).
///
/// One instance (created in `AppRootView`) serves both roles: the
/// Notifications page binds its toggle to `isRemindersEnabled`, and
/// `PlanStore` calls `reconcileReminders(for:)` through the protocol.
@MainActor
@Observable
final class WorkoutReminderService: WorkoutReminderReconciling {
    /// Whether the user has opted into upcoming-workout reminders (drives
    /// the Notifications page toggle).
    private(set) var isRemindersEnabled = false

    /// True when iOS notification permission is denied — drives the gentle
    /// "enable notifications in iOS Settings" footer (never a scold).
    private(set) var isSystemPermissionDenied = false

    /// Injectable clock so "has this reminder time already passed" is
    /// testable.
    var now: () -> Date = { .now }

    private let center: any UserNotificationCenterClient
    private let defaults: UserDefaults
    private let calendar: Calendar
    /// Supplies the authenticated user's id so the opt-in preference is
    /// user-scoped and can't leak across accounts (SPEC §14 #48).
    private let userIDProvider: @MainActor () -> String?
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "WorkoutReminderService")

    init(
        center: any UserNotificationCenterClient,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        userIDProvider: @escaping @MainActor () -> String? = { nil }
    ) {
        self.center = center
        self.defaults = defaults
        self.calendar = calendar
        self.userIDProvider = userIDProvider
        isRemindersEnabled = defaults.bool(forKey: preferenceKey)
    }

    /// UserDefaults key for the opt-in, scoped to the signed-in user when
    /// available and a device-local fallback otherwise.
    nonisolated static func preferenceKey(forUserID userID: String?) -> String {
        "pluri.notifications.workoutRemindersEnabled.\(userID ?? "device")"
    }

    // MARK: - Notifications page API

    /// Re-reads the persisted opt-in for the current account and the system
    /// authorization status (call when the Notifications page appears). If
    /// the user revoked permission in iOS Settings while opted in, the
    /// opt-in reverts and pending reminders are cancelled.
    func refresh() async {
        isRemindersEnabled = defaults.bool(forKey: preferenceKey)
        let status = await center.authorizationStatus()
        isSystemPermissionDenied = status == .denied

        if isRemindersEnabled && !isAuthorized(status) && status != .notDetermined {
            persistOptIn(false)
            await removePendingWorkoutReminders()
        }
    }

    /// Handles the reminders toggle (SPEC §14 #48): opting in requests
    /// system permission first (only ever after this explicit opt-in);
    /// denial reverts the toggle and persists the opt-out. Opting out
    /// cancels every pending workout reminder.
    func setRemindersEnabled(_ enabled: Bool, plan: GeneratedPlan?) async {
        guard enabled else {
            persistOptIn(false)
            await removePendingWorkoutReminders()
            isSystemPermissionDenied = await center.authorizationStatus() == .denied
            return
        }

        var status = await center.authorizationStatus()
        if status == .notDetermined {
            do {
                status = try await center.requestAuthorization() ? .authorized : .denied
            } catch {
                logger.error("Notification authorization request failed: \(error.localizedDescription)")
                status = .denied
            }
        }

        if isAuthorized(status) {
            persistOptIn(true)
            isSystemPermissionDenied = false
            if let plan {
                await reconcileReminders(for: plan)
            }
        } else {
            persistOptIn(false)
            isSystemPermissionDenied = true
            await removePendingWorkoutReminders()
        }
    }

    // MARK: - WorkoutReminderReconciling

    /// Cancels every pending workout reminder, then — when opted in and
    /// authorized — schedules the desired upcoming set derived from the
    /// plan. Deliberately non-throwing: reminder trouble must never surface
    /// as a plan-mutation failure (SPEC §14 #44).
    func reconcileReminders(for plan: GeneratedPlan) async {
        let optedIn = defaults.bool(forKey: preferenceKey)
        let status = await center.authorizationStatus()

        await removePendingWorkoutReminders()
        guard optedIn, isAuthorized(status) else { return }

        for candidate in WorkoutReminderCandidate.candidates(in: plan, now: now(), calendar: calendar) {
            do {
                try await center.add(request(for: candidate))
            } catch {
                logger.error("Failed to schedule a workout reminder: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private

    private func request(for candidate: WorkoutReminderCandidate) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = candidate.title
        content.body = "Time for today's workout."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: candidate.fireDate
            ),
            repeats: false
        )
        return UNNotificationRequest(identifier: candidate.identifier, content: content, trigger: trigger)
    }

    private func removePendingWorkoutReminders() async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(WorkoutReminderCandidate.identifierPrefix) }
        guard !identifiers.isEmpty else { return }
        center.removePendingRequests(withIdentifiers: identifiers)
    }

    private func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    private var preferenceKey: String {
        Self.preferenceKey(forUserID: userIDProvider())
    }

    private func persistOptIn(_ enabled: Bool) {
        defaults.set(enabled, forKey: preferenceKey)
        isRemindersEnabled = enabled
    }
}
