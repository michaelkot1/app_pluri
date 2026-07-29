import Foundation
import Testing
@testable import Pluri

@Suite("Health metric goal store")
@MainActor
struct HealthMetricGoalStoreTests {
    @Test("Goals are optional and scoped to each user")
    func userScopedRoundTrip() throws {
        let suite = "pluri.tests.health-goals.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HealthMetricGoalStore(defaults: defaults)

        #expect(store.goal(for: .steps, userID: "user-a") == nil)
        store.setGoal(8_500, for: .steps, userID: "user-a")

        #expect(store.goal(for: .steps, userID: "user-a")?.target == 8_500)
        #expect(store.goal(for: .steps, userID: "user-b") == nil)
        #expect(store.goal(for: .sleep, userID: "user-a") == nil)
    }

    @Test("Invalid targets and missing users are not persisted")
    func rejectsInvalidValues() throws {
        let suite = "pluri.tests.health-goals.invalid.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HealthMetricGoalStore(defaults: defaults)

        store.setGoal(0, for: .sleep, userID: "user")
        store.setGoal(.infinity, for: .activeEnergy, userID: "user")
        store.setGoal(7.5, for: .sleep, userID: nil)

        #expect(store.goal(for: .sleep, userID: "user") == nil)
        #expect(store.goal(for: .activeEnergy, userID: "user") == nil)
        #expect(store.goal(for: .sleep, userID: nil) == nil)
    }

    @Test("A saved goal can be removed")
    func removeGoal() throws {
        let suite = "pluri.tests.health-goals.remove.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HealthMetricGoalStore(defaults: defaults)

        store.setGoal(500, for: .activeEnergy, userID: "user")
        store.removeGoal(for: .activeEnergy, userID: "user")

        #expect(store.goal(for: .activeEnergy, userID: "user") == nil)
    }
}
