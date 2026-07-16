import Foundation
import Observation

/// Persisted light/dark theme selection (M2-16). Owned by `AppRootView` so the
/// choice applies app-wide via `.preferredColorScheme`; device-level, not
/// account-level, so it intentionally survives sign-out.
@MainActor
@Observable
final class ThemeStore {
    static let defaultsKey = "pluri.appearance.theme"

    var selection: PluriTheme {
        didSet {
            defaults.set(selection.rawValue, forKey: Self.defaultsKey)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selection = defaults.string(forKey: Self.defaultsKey)
            .flatMap(PluriTheme.init(rawValue:)) ?? .system
    }
}
