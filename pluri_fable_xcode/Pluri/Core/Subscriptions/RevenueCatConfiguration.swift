import Foundation

/// Pure resolution of "should this build talk to RevenueCat?" from the injected
/// public SDK key (M2-07).
///
/// Three intentional states, per `.env.example`:
/// - `appl_…` → `.enabled`, the shipping configuration.
/// - empty / absent / placeholder → `.disabled(.keyMissing)`, subscriptions are
///   deliberately off for this build (TestFlight before monetization is wired).
/// - `test_…` in a non-DEBUG build → `.disabled(.testStoreKeyInReleaseBuild)`.
///   RevenueCat traps at `configure` time for Test Store keys outside DEBUG, so
///   the key is ignored rather than crashing the app on launch.
enum RevenueCatConfiguration: Equatable, Sendable {
    case enabled(apiKey: String)
    case disabled(DisabledReason)

    enum DisabledReason: Equatable, Sendable {
        case keyMissing
        case testStoreKeyInReleaseBuild
    }

    /// Values that mean "not filled in yet" rather than a real key.
    private static let placeholders: Set<String> = [
        "none",
        "disabled",
        "todo",
        "changeme",
        "replace_me",
        "your_key_here",
    ]

    static let testStoreKeyPrefix = "test_"

    static func resolve(apiKey: String?, isDebugBuild: Bool) -> Self {
        guard let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty,
              // An unsubstituted `$(PLURI_REVENUECAT_API_KEY)` is not a key either.
              !key.hasPrefix("$("),
              !placeholders.contains(key.lowercased()) else {
            return .disabled(.keyMissing)
        }

        if !isDebugBuild, key.hasPrefix(testStoreKeyPrefix) {
            return .disabled(.testStoreKeyInReleaseBuild)
        }

        return .enabled(apiKey: key)
    }

    var isEnabled: Bool {
        switch self {
        case .enabled: true
        case .disabled: false
        }
    }

    /// Log-safe explanation — never includes the key itself.
    var disabledLogMessage: String? {
        switch self {
        case .enabled:
            nil
        case .disabled(.keyMissing):
            "Subscriptions disabled for this build: REVENUECAT_API_KEY is empty or a placeholder. Paywalls show an unavailable state and entitlement gating is not enforced."
        case .disabled(.testStoreKeyInReleaseBuild):
            "Subscriptions disabled for this build: a RevenueCat Test Store key (test_…) cannot be used outside DEBUG. Set an App Store key (appl_…) in .env, run Scripts/generate_secrets.sh, and rebuild to enable purchases."
        }
    }
}
