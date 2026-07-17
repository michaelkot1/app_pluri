import Foundation

/// The five Main tabs (SPEC §5 tab bar). Home and Insights have real M3
/// content; Plan / Community / Recipe stay placeholders until their milestones.
enum MainTab: Hashable, CaseIterable {
    case home
    case plan
    case insights
    case community
    case recipe
}
