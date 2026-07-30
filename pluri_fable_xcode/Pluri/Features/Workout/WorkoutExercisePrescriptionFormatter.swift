import Foundation

/// Human-readable set/rep prescription for live workout cards.
///
/// Owner rule: show a rep range of `reps … reps + 2`, and treat `sets` as the
/// repeat count — never a terse "4 × 5" string (design.md Workout card patterns).
enum WorkoutExercisePrescriptionFormatter {
    /// e.g. `"5–7 reps, repeat 4 times"`, `"1–3 reps, repeat 1 time"`.
    static func phrase(sets: Int, reps: Int) -> String {
        let low = max(0, reps)
        let high = low + 2
        let repsPart = "\(low)–\(high) reps"
        let timesWord = sets == 1 ? "time" : "times"
        return "\(repsPart), repeat \(max(0, sets)) \(timesWord)"
    }
}
