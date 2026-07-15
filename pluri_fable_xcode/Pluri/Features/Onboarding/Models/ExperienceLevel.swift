import Foundation

/// Q3 — "How long have you been weight training?" (SPEC §3.2).
enum ExperienceLevel: String, CaseIterable, Identifiable, Sendable {
    case notYet = "Not yet"
    case oneToSixMonths = "1–6 months"
    case sixToTwelveMonths = "6–12 months"
    case oneToTwoYears = "1–2 years"
    case twoPlusYears = "2+ years"

    var id: Self { self }
    var title: String { rawValue }
}
