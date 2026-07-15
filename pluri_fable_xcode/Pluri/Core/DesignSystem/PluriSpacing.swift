import Foundation

/// Spacing scale per design.md §5 — base unit 4pt, primary rhythm 8pt.
enum PluriSpacing {
    /// Icon-to-label gaps, value/unit spacing.
    static let xs: CGFloat = 4
    /// Chip padding, tight stacks.
    static let sm: CGFloat = 8
    /// Default card padding, element gaps.
    static let md: CGFloat = 16
    /// Section separation, screen side gutters.
    static let lg: CGFloat = 24
    /// Major section breaks, above hero.
    static let xl: CGFloat = 32
    /// Around hero numerals and headers.
    static let xxl: CGFloat = 48
}
