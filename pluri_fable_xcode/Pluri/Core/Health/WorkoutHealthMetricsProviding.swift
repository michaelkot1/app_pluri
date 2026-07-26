import Foundation
import Observation

/// Live heart rate + active energy while a workout session is running (M4-11).
/// Streams only during an unpaused active segment; Insights / Pluri Score stay M5.
@MainActor
protocol WorkoutHealthMetricsProviding: AnyObject {
    var isAuthorized: Bool { get }
    /// Beats per minute when authorized and a sample is available; otherwise nil.
    var heartRateBPM: Double? { get }
    /// Active energy kilocalories for the current streaming window; nil when unavailable.
    var activeEnergyKilocalories: Double? { get }

    func requestAuthorization() async
    /// Begin observing samples. No-op when unauthorized.
    func startStreaming()
    /// Stop observing; clears displayed values.
    func stopStreaming()
}

/// Test / preview double for live workout metrics (M4-11).
@MainActor
@Observable
final class MockWorkoutHealthMetricsProvider: WorkoutHealthMetricsProviding {
    private(set) var isAuthorized: Bool
    private(set) var heartRateBPM: Double?
    private(set) var activeEnergyKilocalories: Double?
    private(set) var isStreaming = false
    private(set) var authorizationRequestCount = 0
    private(set) var startStreamingCount = 0
    private(set) var stopStreamingCount = 0

    var nextHeartRateBPM: Double? = 128
    var nextActiveEnergyKilocalories: Double? = 42

    init(isAuthorized: Bool = false) {
        self.isAuthorized = isAuthorized
    }

    func requestAuthorization() async {
        authorizationRequestCount += 1
        isAuthorized = true
    }

    func startStreaming() {
        startStreamingCount += 1
        guard isAuthorized else {
            isStreaming = false
            heartRateBPM = nil
            activeEnergyKilocalories = nil
            return
        }
        isStreaming = true
        heartRateBPM = nextHeartRateBPM
        activeEnergyKilocalories = nextActiveEnergyKilocalories
    }

    func stopStreaming() {
        stopStreamingCount += 1
        isStreaming = false
        heartRateBPM = nil
        activeEnergyKilocalories = nil
    }

    /// Test helper: flip authorization without going through the request path.
    func setAuthorized(_ authorized: Bool) {
        isAuthorized = authorized
        if !authorized {
            stopStreaming()
        }
    }
}
