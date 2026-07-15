import Foundation

/// Drives the onboarding `NavigationStack` (M1-04). Owns the navigation
/// path so progress (M1-07) can be derived from a single source of truth —
/// pushing advances it, and both a "Back" tap and an edge swipe-back pop it
/// the same way, since both mutate this same `path`.
@MainActor
@Observable
final class OnboardingRouter {
    var path: [OnboardingDestination] = []

    var current: OnboardingDestination? { path.last }

    func start() {
        path = [.name]
    }

    func advance(to destination: OnboardingDestination) {
        path.append(destination)
    }

    /// Advances to whatever comes after `destination` in flow order.
    func advance(from destination: OnboardingDestination) {
        guard let next = destination.next else { return }
        path.append(next)
    }
}
