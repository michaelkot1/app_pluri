import SwiftUI

/// Typography hierarchy per design.md §3 — SF Pro Rounded throughout.
/// Every style is built on a Dynamic Type text style so it scales with the
/// user's type size setting.
enum PluriFont {
    /// The one focal metric (steps, kcal, "Zone 0") is ~60pt — bigger than any
    /// built-in text style, so it lives in the `PluriHeroNumeral` view, which
    /// scales it with Dynamic Type via `@ScaledMetric`.

    /// Secondary big stats (147 kcal, 0.55 mi). ~34–40pt bold.
    static let displayNumeral = Font.system(.largeTitle, design: .rounded, weight: .bold)

    /// Section headers ("Go Gentler"). ~26–28pt bold.
    static let title = Font.system(.title, design: .rounded, weight: .bold)

    /// Card group titles ("Wellness", "Past Activities"). ~20–22pt semibold.
    static let sectionHeader = Font.system(.title3, design: .rounded, weight: .semibold)

    /// Descriptive paragraphs, guidance copy. ~16–17pt regular.
    static let body = Font.system(.body, design: .rounded)

    /// In-card numbers with a lighter unit suffix. ~20pt bold.
    static let metricValue = Font.system(.title3, design: .rounded, weight: .bold)

    /// Field labels, dates, "Total Distance". ~13–15pt medium.
    static let label = Font.system(.subheadline, design: .rounded, weight: .medium)

    /// Eyebrow labels ("ENERGY", "DISTANCE") — pair with `.textCase(.uppercase)`
    /// and `.kerning(1)`. ~12pt semibold caps, tracked.
    static let overline = Font.system(.caption, design: .rounded, weight: .semibold)
}
