import Foundation

/// Q9 — scheduled (pinned to chosen weekdays) vs flexible (N times/week,
/// any day) per SPEC §3.2.
enum ScheduleType: String, CaseIterable, Identifiable, Sendable {
    case scheduled = "Scheduled"
    case flexible = "Flexible"

    var id: Self { self }
    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .scheduled: "Workouts are pinned to your chosen days."
        case .flexible: "Do your workouts any day that works for you."
        }
    }
}
