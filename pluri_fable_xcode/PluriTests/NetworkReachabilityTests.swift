import Foundation
import Testing
@testable import Pluri

@Suite("NetworkReachability")
@MainActor
struct NetworkReachabilityTests {

    @Test("Path monitor can be restarted after stop")
    func pathMonitorRestartsAfterStop() {
        // A cancelled NWPathMonitor never reports again, so `start()` must build
        // a fresh one — otherwise `isOnline` freezes and blocks sends (§14 #76).
        let reachability = PathMonitorReachability()

        reachability.start()
        #expect(reachability.isMonitoring)

        reachability.stop()
        #expect(reachability.isMonitoring == false)

        reachability.start()
        #expect(reachability.isMonitoring)

        reachability.stop()
    }

    @Test("Repeated starts do not stack monitors")
    func repeatedStartIsIdempotent() {
        let reachability = PathMonitorReachability()

        reachability.start()
        reachability.start()
        #expect(reachability.isMonitoring)

        reachability.stop()
        #expect(reachability.isMonitoring == false)
    }
}
