import Foundation
import Observation

/// Drives Apple Health connection status + Connect CTA for Connected Apps,
/// Profile, and the Plan nudge (M5-03 / SPEC §14 #57b).
@MainActor
@Observable
final class AppleHealthConnectionViewModel {
    private let healthKit: any HealthKitReading

    private(set) var authorizationStatus: HealthKitReadAuthorizationStatus
    private(set) var isConnecting = false

    init(healthKit: any HealthKitReading) {
        self.healthKit = healthKit
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

    /// Gentle Settings guidance when denied; default privacy note otherwise.
    var footerText: String {
        switch authorizationStatus {
        case .denied:
            "Apple Health access is turned off for Pluri in iOS Settings. You can turn it on there whenever you're ready."
        case .unavailable:
            "Apple Health isn't available on this device."
        case .authorized:
            "Steps, sleep, heart rate, and active energy stay on this device for Home tiles, Insights, and Pluri Score."
        case .notDetermined:
            "Connect to show Today's Health on Home and Insights. Pluri never uploads your Health samples."
        }
    }

    func refresh() async {
        await healthKit.refreshAuthorizationStatus()
        authorizationStatus = healthKit.authorizationStatus
    }

    /// Presents the system HealthKit sheet, then refreshes status.
    func connect() async {
        guard showsConnectButton, !isConnecting else { return }
        isConnecting = true
        defer { isConnecting = false }
        await healthKit.requestAuthorization()
        await refresh()
    }
}
