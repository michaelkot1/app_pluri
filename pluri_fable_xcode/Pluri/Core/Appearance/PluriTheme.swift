import SwiftUI

/// User-selectable appearance per SPEC §5.2 ("Theme: light / dark").
/// `system` is the default before the user picks, so a fresh install follows
/// the device appearance instead of forcing one (SPEC §14 #35).
enum PluriTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Value for `.preferredColorScheme` — `nil` follows the device setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
