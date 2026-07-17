import Foundation

/// The five Main tabs (SPEC §5 tab bar — M2-18 shell; real tabs are M3+).
enum MainTab: Hashable, CaseIterable {
    case home
    case plan
    case insights
    case community
    case recipe
}
