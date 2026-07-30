import Foundation
import Network

/// Online / offline probe for SyncEngine (M4-03). Injectable so tests can stub.
@MainActor
protocol NetworkReachability: AnyObject {
    var isOnline: Bool { get }
    /// Invoked on the main actor when the path becomes satisfied.
    var onPathSatisfied: (() -> Void)? { get set }
    func start()
    func stop()
}

/// Always-online stub for previews and tests that don't care about reachability.
@MainActor
final class AlwaysOnlineReachability: NetworkReachability {
    private(set) var isOnline = true
    var onPathSatisfied: (() -> Void)?

    func start() {}
    func stop() {}
}

/// Controllable reachability for unit tests.
@MainActor
final class MockNetworkReachability: NetworkReachability {
    var isOnline: Bool
    var onPathSatisfied: (() -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    var isMonitoring: Bool { startCount > stopCount }

    init(isOnline: Bool = true) {
        self.isOnline = isOnline
    }

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }

    /// Flip online and fire the satisfied hook (mirrors path-monitor behavior).
    func goOnline() {
        isOnline = true
        onPathSatisfied?()
    }

    func goOffline() {
        isOnline = false
    }
}

/// `NWPathMonitor`-backed reachability. Uses a private monitor queue because
/// the Network framework API requires one (AGENTS: GCD only when an API forces it).
@MainActor
final class PathMonitorReachability: NetworkReachability {
    private let monitorQueue = DispatchQueue(label: "com.codewithmikey.pluri.reachability")
    /// A cancelled `NWPathMonitor` never delivers another path update, so a
    /// stop → start cycle needs a brand-new monitor. Reusing the cancelled one
    /// froze `isOnline` at its last value forever (SPEC §14 #76).
    /// `nonisolated(unsafe)` so `deinit` can cancel without hopping to the main actor.
    private nonisolated(unsafe) var monitor: NWPathMonitor?
    private(set) var isOnline = true
    var onPathSatisfied: (() -> Void)?

    var isMonitoring: Bool { monitor != nil }

    func start() {
        guard monitor == nil else { return }
        // Assume online until the first path update. A stop → start cycle must
        // not leave `isOnline == false` while the new monitor is still spinning
        // up, or Ask Pluri `send()` rejects at the offline guard (SPEC §14 #76).
        isOnline = true
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { @MainActor in
                let online = path.status == .satisfied
                let becameOnline = online && !self.isOnline
                self.isOnline = online
                if becameOnline {
                    self.onPathSatisfied?()
                }
            }
        }
        self.monitor = monitor
        monitor.start(queue: monitorQueue)
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
    }

    deinit {
        monitor?.cancel()
    }

    #if DEBUG
    /// Test seam: force last-known status without a live path update.
    func setOnlineForTesting(_ online: Bool) {
        isOnline = online
    }
    #endif
}
