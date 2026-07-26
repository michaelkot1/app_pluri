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

    init(isOnline: Bool = true) {
        self.isOnline = isOnline
    }

    func start() {}
    func stop() {}

    /// Flip online and fire the satisfied hook (mirrors path-monitor behavior).
    func goOnline() {
        isOnline = true
        onPathSatisfied?()
    }
}

/// `NWPathMonitor`-backed reachability. Uses a private monitor queue because
/// the Network framework API requires one (AGENTS: GCD only when an API forces it).
@MainActor
final class PathMonitorReachability: NetworkReachability {
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.codewithmikey.pluri.reachability")
    private(set) var isOnline = true
    var onPathSatisfied: (() -> Void)?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let online = path.status == .satisfied
                let becameOnline = online && !self.isOnline
                self.isOnline = online
                if becameOnline {
                    self.onPathSatisfied?()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func stop() {
        monitor.cancel()
    }
}
