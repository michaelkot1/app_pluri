#if DEBUG
import Foundation
import UserNotifications

extension WorkoutReminderService {
    /// Preview-only factory: a reminder service backed by the mock center in
    /// a scripted authorization/opt-in state, isolated from the app's real
    /// UserDefaults.
    static func preview(
        status: UNAuthorizationStatus = .notDetermined,
        optedIn: Bool = false
    ) -> WorkoutReminderService {
        let center = MockUserNotificationCenterClient()
        center.currentStatus = status

        let defaults = UserDefaults(suiteName: "pluri.previews.notifications") ?? .standard
        defaults.set(optedIn, forKey: preferenceKey(forUserID: nil))

        return WorkoutReminderService(center: center, defaults: defaults)
    }
}
#endif
