import Foundation
import Observation

/// Drives Apple Health connection status + Connect CTA for Connected Apps,
/// Profile, and the Plan nudge (M5-03 / SPEC §14 #57b).
///
/// HealthKit never reports which *read* types the user actually granted, so after a
/// completed prompt this model probes a short window of samples and names the
/// categories Pluri still can't see — that's the only honest way to explain partial
/// grants instead of leaving Home and Insights quietly empty (SPEC §14 #78).
@MainActor
@Observable
final class AppleHealthConnectionViewModel {
    /// Days of history used to tell "granted but no samples" from "not granted".
    static let probeDayCount = 7

    private let healthKit: any HealthKitReading
    private let calendar: Calendar

    private(set) var authorizationStatus: HealthKitReadAuthorizationStatus
    private(set) var isConnecting = false

    /// Categories with no readable samples in the probe window, once connected.
    private(set) var unreadableMetrics: [HealthMetricKind] = []

    init(healthKit: any HealthKitReading, calendar: Calendar = .current) {
        self.healthKit = healthKit
        self.calendar = calendar
        self.authorizationStatus = healthKit.authorizationStatus
    }

    /// Connected / Not connected / Not available — Profile + Connected Apps labels.
    var statusLabel: String {
        switch authorizationStatus {
        case .authorized:
            "Connected"
        case .notDetermined, .denied:
            "Not connected"
        case .unavailable:
            "Not available"
        }
    }

    /// Connect only when the system still wants a prompt (never after denial).
    var showsConnectButton: Bool {
        authorizationStatus == .notDetermined
    }

    /// Once iOS has taken the answer it won't ask again, so offer Settings instead.
    var showsSettingsLink: Bool {
        switch authorizationStatus {
        case .authorized, .denied:
            true
        case .notDetermined, .unavailable:
            false
        }
    }

    /// Gentle Settings guidance when denied or partially granted; privacy note otherwise.
    var footerText: String {
        switch authorizationStatus {
        case .denied:
            "Apple Health access is turned off for Pluri in iOS Settings. You can turn it on there whenever you're ready."
        case .unavailable:
            "Apple Health isn't available on this device."
        case .authorized:
            if unreadableMetrics.isEmpty {
                "Steps, sleep, heart rate, and active energy stay on this device for Home tiles, Insights, and Pluri Score."
            } else {
                "Pluri can't read \(unreadableMetricList) yet. Open Settings › Privacy & Security › Health › Pluri to turn those categories on."
            }
        case .notDetermined:
            "Connect to show Today's Health on Home and Insights. Pluri never uploads your Health samples."
        }
    }

    /// "Steps", "Steps and Sleep", "Steps, Sleep, and Heart Rate".
    var unreadableMetricList: String {
        unreadableMetrics.map(\.title).formatted(.list(type: .and))
    }

    func refresh() async {
        await healthKit.refreshAuthorizationStatus()
        authorizationStatus = healthKit.authorizationStatus
        await refreshUnreadableMetrics()
    }

    /// Presents the system HealthKit sheet, then refreshes status.
    func connect() async {
        guard showsConnectButton, !isConnecting else { return }
        isConnecting = true
        defer { isConnecting = false }
        await healthKit.requestAuthorization()
        await refresh()
    }

    // MARK: - Private

    /// A completed prompt can still leave every category off; reads then come back
    /// empty rather than failing, so sample presence is the only available signal.
    private func refreshUnreadableMetrics() async {
        guard authorizationStatus == .authorized else {
            unreadableMetrics = []
            return
        }

        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(
            byAdding: .day,
            value: -(Self.probeDayCount - 1),
            to: today
        ) ?? today
        let history = await healthKit.dailyHistory(
            from: start,
            through: today,
            calendar: calendar
        )

        unreadableMetrics = HealthMetricKind.allCases.filter { metric in
            !history.contains { $0[keyPath: metric.snapshotValue] != nil }
        }
    }
}
