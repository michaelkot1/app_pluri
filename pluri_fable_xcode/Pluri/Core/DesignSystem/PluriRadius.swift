import Foundation

/// Border-radius scale per design.md §5.
enum PluriRadius {
    /// Small chips, inset elements.
    static let sm: CGFloat = 8
    /// Inputs, small tiles.
    static let md: CGFloat = 16
    /// Cards, sheets.
    static let lg: CGFloat = 20
    /// Pill buttons, tab bar.
    static let xl: CGFloat = 28
    /// Radios, thumbs, circular icons, capsule gauges.
    static let full: CGFloat = 999
}
