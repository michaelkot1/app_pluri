import Foundation
import Observation

/// Drives Apple Health connection status + Connect CTA for Connected Apps,
/// Profile, and the Plan nudge (M5-03 / SPEC §14 #57b / #78).
///
/// Connect always goes through the system HealthKit sheet — Pluri never sends the user
/// out to the Settings app. HealthKit presents that sheet whenever any requested type
/// has not been asked about yet, so the CTA stays available while anything is missing:
/// read authorization is deliberately uninformative, so "missing" is judged from
/// `HealthKitReading`'s prompt-needed status plus a probe for readable samples.
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

    /// True once a completed Connect left categories unreadable — iOS treats those as
    /// already answered and draws nothing, so tapping again can't bring the sheet back.
    private(set) var connectLeftCategoriesClosed = false

    init(healthKit: any HealthKitReading, calendar: Calendar = .current) {
        self.healthKit = healthKit
        self.calendar = calendar
        self.authorizationStatus = healthKit.authorizationStatus
    }

    /// Connected / Partly connected / Not connected / Not available.
    var statusLabel: String {
        switch authorizationStatus {
        case .authorized:
            hasCompleteAccess ? "Connected" : "Partly connected"
        case .notDetermined, .denied:
            "Not connected"
        case .unavailable:
            "Not available"
        }
    }

    /// Everything Pluri reads is granted and returning samples.
    var hasCompleteAccess: Bool {
        authorizationStatus == .authorized && unreadableMetrics.isEmpty
    }

    /// Offered whenever HealthKit exists and something is still missing. Tapping it always
    /// calls `requestAuthorization`; iOS decides whether the sheet appears.
    var showsConnectButton: Bool {
        switch authorizationStatus {
        case .unavailable:
            false
        case .notDetermined, .denied:
            true
        case .authorized:
            !unreadableMetrics.isEmpty
        }
    }

    /// Privacy note when fully connected, otherwise gentle guidance — text only, since
    /// Pluri never hands the user off to Settings (SPEC §14 #78).
    var footerText: String {
        switch authorizationStatus {
        case .unavailable:
            "Apple Health isn't available on this device."
        case .notDetermined:
            "Connect to show Today's Health on Home and Insights. Pluri never uploads your Health samples."
        case .denied:
            "Apple Health didn't hand over access last time. Tap Connect to ask again — Pluri never uploads your Health samples."
        case .authorized:
            if unreadableMetrics.isEmpty {
                "Steps, sleep, heart rate, and active energy stay on this device for Home tiles, Insights, and Pluri Score."
            } else if connectLeftCategoriesClosed {
                "Apple Health only asks once per category, so Connect won't bring the prompt back for \(unreadableMetricList). You can switch those on whenever you like in the Settings app, under Privacy & Security › Health › Pluri. Pluri works fine without them."
            } else {
                "Pluri can't read \(unreadableMetricList) yet. Tap Connect and Apple Health will ask about whatever it hasn't asked about before."
            }
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
        if hasCompleteAccess {
            connectLeftCategoriesClosed = false
        }
    }

    /// Presents the system HealthKit sheet, then refreshes status. Never leaves the app.
    func connect() async {
        guard showsConnectButton, !isConnecting else { return }
        isConnecting = true
        defer { isConnecting = false }
        await healthKit.requestAuthorization()
        await refresh()
        connectLeftCategoriesClosed = !hasCompleteAccess
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
