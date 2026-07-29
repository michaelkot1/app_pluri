import Foundation
import Testing
@testable import Pluri

@Suite("AppleHealthConnectionViewModel")
@MainActor
struct AppleHealthConnectionViewModelTests {

    @Test("Not determined shows Connect and Not connected")
    func notDeterminedLabels() {
        let healthKit = MockHealthKitReading(authorizationStatus: .notDetermined)
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)

        #expect(viewModel.statusLabel == "Not connected")
        #expect(viewModel.showsConnectButton)
        #expect(viewModel.footerText.contains("Connect"))
    }

    @Test("Authorized shows Connected without Connect CTA")
    func authorizedLabels() {
        let healthKit = MockHealthKitReading(authorizationStatus: .authorized)
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)

        #expect(viewModel.statusLabel == "Connected")
        #expect(!viewModel.showsConnectButton)
    }

    @Test("Denied shows Settings guidance without Connect CTA")
    func deniedFooter() {
        let healthKit = MockHealthKitReading(authorizationStatus: .denied)
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)

        #expect(viewModel.statusLabel == "Not connected")
        #expect(!viewModel.showsConnectButton)
        #expect(viewModel.footerText.contains("Settings"))
    }

    @Test("Unavailable shows Not available")
    func unavailableLabel() {
        let healthKit = MockHealthKitReading(authorizationStatus: .unavailable)
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)

        #expect(viewModel.statusLabel == "Not available")
        #expect(!viewModel.showsConnectButton)
    }

    @Test("connect requests authorization then refreshes")
    func connectRequestsAuth() async {
        let healthKit = MockHealthKitReading(authorizationStatus: .notDetermined)
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)

        await viewModel.connect()

        #expect(healthKit.authorizationRequestCount == 1)
        #expect(healthKit.refreshCount == 1)
        #expect(viewModel.authorizationStatus == .authorized)
        #expect(viewModel.statusLabel == "Connected")
        #expect(!viewModel.isConnecting)
    }

    @Test("connect is a no-op when already denied")
    func connectIgnoredWhenDenied() async {
        let healthKit = MockHealthKitReading(authorizationStatus: .denied)
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)

        await viewModel.connect()

        #expect(healthKit.authorizationRequestCount == 0)
    }

    @Test("refresh pulls latest status from the reader")
    func refreshUpdatesStatus() async {
        let healthKit = MockHealthKitReading(authorizationStatus: .notDetermined)
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)
        healthKit.setAuthorizationStatus(.authorized)

        await viewModel.refresh()

        #expect(healthKit.refreshCount == 1)
        #expect(viewModel.authorizationStatus == .authorized)
    }
}

@Suite("PlanHealthKitNudgeController")
@MainActor
struct PlanHealthKitNudgeControllerTests {

    @Test("Shows for notDetermined until dismissed")
    func showsUntilDismissed() {
        let suite = "pluri.tests.planHealthNudge.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let controller = PlanHealthKitNudgeController(defaults: defaults)
        #expect(controller.shouldShow(for: .notDetermined))
        #expect(controller.shouldShow(for: .denied))
        #expect(!controller.shouldShow(for: .authorized))
        #expect(!controller.shouldShow(for: .unavailable))

        controller.dismissForSession()
        #expect(!controller.shouldShow(for: .notDetermined))
    }

    @Test("Don't ask again persists across controller instances")
    func dontAskAgainPersists() {
        let suite = "pluri.tests.planHealthNudge.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = PlanHealthKitNudgeController(defaults: defaults)
        first.setDontAskAgain()
        #expect(first.dontAskAgain)
        #expect(!first.shouldShow(for: .notDetermined))

        let second = PlanHealthKitNudgeController(defaults: defaults)
        #expect(second.dontAskAgain)
        #expect(!second.shouldShow(for: .denied))
    }
}
