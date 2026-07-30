import Testing
@testable import Pluri

/// Covers the three intentional subscription states (production / disabled / dev).
@Suite("RevenueCatConfiguration")
struct RevenueCatConfigurationTests {
    @Test("Production key enables subscriptions in both build types")
    func productionKeyEnabled() {
        #expect(
            RevenueCatConfiguration.resolve(apiKey: "appl_abc123", isDebugBuild: false)
                == .enabled(apiKey: "appl_abc123")
        )
        #expect(
            RevenueCatConfiguration.resolve(apiKey: "appl_abc123", isDebugBuild: true)
                == .enabled(apiKey: "appl_abc123")
        )
    }

    @Test("Missing, empty, placeholder, and unsubstituted keys disable subscriptions")
    func missingKeyDisabled() {
        let values: [String?] = [
            nil,
            "",
            "   ",
            "none",
            "REPLACE_ME",
            "$(PLURI_REVENUECAT_API_KEY)",
        ]
        for value in values {
            #expect(
                RevenueCatConfiguration.resolve(apiKey: value, isDebugBuild: false)
                    == .disabled(.keyMissing)
            )
        }
    }

    @Test("Test Store key works in Debug but is ignored outside Debug")
    func testStoreKeyDebugOnly() {
        #expect(
            RevenueCatConfiguration.resolve(apiKey: "test_abc123", isDebugBuild: true)
                == .enabled(apiKey: "test_abc123")
        )
        #expect(
            RevenueCatConfiguration.resolve(apiKey: "test_abc123", isDebugBuild: false)
                == .disabled(.testStoreKeyInReleaseBuild)
        )
    }

    @Test("Disabled log message never contains the key")
    func disabledMessageRedacted() {
        let configuration = RevenueCatConfiguration.resolve(apiKey: "test_abc123", isDebugBuild: false)
        let message = configuration.disabledLogMessage
        #expect(message != nil)
        #expect(message?.contains("abc123") == false)
        #expect(configuration.isEnabled == false)
    }
}
