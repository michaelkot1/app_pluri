import Foundation

/// Typed destinations pushable from the Community tab's `NavigationStack`
/// (M8-05 / SPEC §14 #44 — calendar stays on Community stack).
enum CommunityRoute: Hashable, Sendable {
    case search
    case calendar
}
