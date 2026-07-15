import Foundation

/// Q11 — used both for the "about you" form and as a `CalorieCalculator`
/// input (Mifflin-St Jeor uses a sex-specific offset).
enum Gender: String, CaseIterable, Identifiable, Sendable {
    case male = "Male"
    case female = "Female"
    case other = "Other"

    var id: Self { self }
    var title: String { rawValue }
}
