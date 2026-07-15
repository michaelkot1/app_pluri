import Foundation

/// Q10 — "How much time do you want to devote each workout?" (SPEC §3.2).
enum SessionDuration: Int, CaseIterable, Identifiable, Sendable {
    case thirtyMinutes = 30
    case fortyFiveMinutes = 45
    case oneHour = 60
    case oneHourFifteen = 75
    case oneHourThirty = 90

    var id: Self { self }

    var title: String {
        let duration = Duration.seconds(rawValue * 60)
        return duration.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
