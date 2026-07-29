import Foundation
import UIKit

/// Deep links into iOS Settings for permission guidance. iOS never re-presents a
/// permission prompt once the user has answered it, so screens that depend on a
/// grant (Apple Health, notifications) point here instead of pretending to re-ask.
@MainActor
enum SystemSettingsLink {
    /// Pluri's own page in iOS Settings, where the Health data-access row lives.
    static var pluriSettings: URL? {
        URL(string: UIApplication.openSettingsURLString)
    }
}
