import Foundation

/// Q8 — training-day picker. Raw values match `Calendar`'s `weekday`
/// component (1 = Sunday ... 7 = Saturday) so answers can later drive actual
/// scheduling without a lookup table.
enum Weekday: Int, CaseIterable, Identifiable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    /// Displayed Monday-first, which reads more naturally for a weekly
    /// training-day picker regardless of the user's locale first-weekday.
    static let displayOrder: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var id: Self { self }

    /// Locale-correct short day name (e.g. "Mon", "Tue"), via `Calendar`
    /// rather than a hardcoded string table.
    var shortTitle: String {
        let symbols = Calendar.current.shortStandaloneWeekdaySymbols
        return symbols[rawValue - 1]
    }
}
