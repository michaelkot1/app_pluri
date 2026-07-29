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

    @Test("Fully readable access is a clean status row with no action")
    func authorizedLabels() {
        let healthKit = MockHealthKitReading(authorizationStatus: .authorized)
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)

        #expect(viewModel.statusLabel == "Connected")
        #expect(viewModel.hasCompleteAccess)
        #expect(!viewModel.showsConnectButton)
        #expect(viewModel.footerText.contains("stay on this device"))
    }

    @Test("Denied keeps Connect so the sheet can be asked for again")
    func deniedOffersConnect() {
        let healthKit = MockHealthKitReading(authorizationStatus: .denied)
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)

        #expect(viewModel.statusLabel == "Not connected")
        #expect(viewModel.showsConnectButton)
        #expect(viewModel.footerText.contains("Tap Connect"))
    }

    @Test("Unavailable shows Not available and no actions")
    func unavailableLabel() {
        let healthKit = MockHealthKitReading(authorizationStatus: .unavailable)
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)

        #expect(viewModel.statusLabel == "Not available")
        #expect(!viewModel.showsConnectButton)
        #expect(viewModel.footerText.contains("isn't available"))
    }

    /// The point of the whole section: an incomplete grant is never a dead end that
    /// hands the user off to Settings — there is always a Connect button to tap.
    @Test("Every incomplete state on a HealthKit device offers Connect")
    func incompleteAccessAlwaysOffersConnect() async {
        for status in [
            HealthKitReadAuthorizationStatus.notDetermined,
            .denied,
        ] {
            let healthKit = MockHealthKitReading(authorizationStatus: status)
            let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)
            await viewModel.refresh()

            #expect(!viewModel.hasCompleteAccess)
            #expect(viewModel.showsConnectButton)
        }
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

    @Test("connect re-reads health data so Home and Insights refresh immediately")
    func connectProbesDataAfterGrant() async {
        let healthKit = MockHealthKitReading(authorizationStatus: .notDetermined)
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)

        await viewModel.connect()

        #expect(healthKit.historyRequestCount == 1)
        #expect(viewModel.unreadableMetrics.isEmpty)
    }

    @Test("A failed request keeps Connect and invites another try")
    func connectFailureInvitesRetry() async {
        let healthKit = MockHealthKitReading(authorizationStatus: .notDetermined)
        healthKit.statusAfterAuthorizationRequest = .denied
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)

        await viewModel.connect()

        #expect(viewModel.authorizationStatus == .denied)
        #expect(viewModel.showsConnectButton)
        #expect(viewModel.footerText.contains("Tap Connect"))
        #expect(viewModel.unreadableMetrics.isEmpty)
    }

    @Test("connect asks HealthKit again when access was refused before")
    func connectRetriesWhenDenied() async {
        let healthKit = MockHealthKitReading(authorizationStatus: .denied)
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)

        await viewModel.connect()

        #expect(healthKit.authorizationRequestCount == 1)
        #expect(viewModel.authorizationStatus == .authorized)
    }

    @Test("connect is a no-op when HealthKit is unavailable")
    func connectIgnoredWhenUnavailable() async {
        let healthKit = MockHealthKitReading(authorizationStatus: .unavailable)
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)

        await viewModel.connect()

        #expect(healthKit.authorizationRequestCount == 0)
        #expect(viewModel.statusLabel == "Not available")
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

    @Test("Connected but unreadable categories are named, not silently empty")
    func partialGrantNamesMissingCategories() async {
        let calendar = Calendar.current
        let healthKit = MockHealthKitReading(
            authorizationStatus: .authorized,
            todayFixture: HealthDaySnapshot(
                dayStart: calendar.startOfDay(for: .now),
                stepCount: 9_446,
                sleepHours: nil,
                averageHeartRateBPM: nil,
                activeEnergyKilocalories: 420
            ),
            calendar: calendar
        )
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit, calendar: calendar)

        await viewModel.refresh()

        #expect(viewModel.statusLabel == "Partly connected")
        #expect(!viewModel.hasCompleteAccess)
        #expect(viewModel.showsConnectButton)
        #expect(viewModel.unreadableMetrics == [.sleep, .heartRate])
        #expect(viewModel.unreadableMetricList.contains("Sleep"))
        #expect(viewModel.unreadableMetricList.contains("Heart Rate"))
        #expect(viewModel.footerText.contains("Tap Connect"))
    }

    @Test("A connect that changed nothing explains where access lives, without a link")
    func connectThatOpensNothingExplainsWhereAccessLives() async {
        let calendar = Calendar.current
        let healthKit = MockHealthKitReading(
            authorizationStatus: .notDetermined,
            todayFixture: HealthDaySnapshot(
                dayStart: calendar.startOfDay(for: .now),
                stepCount: 9_446,
                sleepHours: nil,
                averageHeartRateBPM: nil,
                activeEnergyKilocalories: 420
            ),
            calendar: calendar
        )
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit, calendar: calendar)

        await viewModel.connect()

        #expect(viewModel.connectLeftCategoriesClosed)
        #expect(viewModel.showsConnectButton)
        #expect(viewModel.footerText.contains("only asks once per category"))
        #expect(viewModel.footerText.contains("Privacy & Security › Health › Pluri"))
        #expect(viewModel.footerText.contains("Pluri works fine without them"))
        #expect(!viewModel.footerText.contains("Open Settings"))
    }

    @Test("Access granted later clears the already-asked guidance")
    func completeAccessClearsGuidance() async {
        let calendar = Calendar.current
        let healthKit = MockHealthKitReading(
            authorizationStatus: .notDetermined,
            todayFixture: HealthDaySnapshot(
                dayStart: calendar.startOfDay(for: .now),
                stepCount: 9_446,
                sleepHours: nil,
                averageHeartRateBPM: nil,
                activeEnergyKilocalories: 420
            ),
            calendar: calendar
        )
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit, calendar: calendar)
        await viewModel.connect()
        #expect(viewModel.connectLeftCategoriesClosed)

        healthKit.todayFixture = HealthDaySnapshot(
            dayStart: calendar.startOfDay(for: .now),
            stepCount: 9_446,
            sleepHours: 7.25,
            averageHeartRateBPM: 68,
            activeEnergyKilocalories: 420
        )
        await viewModel.refresh()

        #expect(!viewModel.connectLeftCategoriesClosed)
        #expect(viewModel.hasCompleteAccess)
        #expect(viewModel.statusLabel == "Connected")
        #expect(!viewModel.showsConnectButton)
    }

    @Test("Not-connected status never claims a category is unreadable")
    func notDeterminedSkipsProbe() async {
        let healthKit = MockHealthKitReading(authorizationStatus: .notDetermined)
        let viewModel = AppleHealthConnectionViewModel(healthKit: healthKit)

        await viewModel.refresh()

        #expect(healthKit.historyRequestCount == 0)
        #expect(viewModel.unreadableMetrics.isEmpty)
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
