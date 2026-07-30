import Foundation

/// One already-logged set surfaced to the live exercise card (session-local).
struct LoggedSetSummary: Identifiable, Equatable, Sendable {
    var id: UUID
    var setNumber: Int
    var reps: Int?
    var weightKg: Double?
    var durationSeconds: Int?

    init(from record: SetLogRecord) {
        id = record.id
        setNumber = record.setNumber
        reps = record.reps
        weightKg = record.weightKg
        durationSeconds = record.durationSeconds
    }

    init(
        id: UUID = UUID(),
        setNumber: Int,
        reps: Int? = nil,
        weightKg: Double? = nil,
        durationSeconds: Int? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.durationSeconds = durationSeconds
    }

    /// Compact row copy for the card history list.
    func displayLine(usesImperial: Bool) -> String {
        if let durationSeconds {
            return "Set \(setNumber) · \(WorkoutScreenViewModel.formatElapsed(durationSeconds))"
        }

        var parts: [String] = ["Set \(setNumber)"]
        if let weightKg {
            let display = Self.displayWeight(kg: weightKg, usesImperial: usesImperial)
            let unit = usesImperial ? "lb" : "kg"
            parts.append("\(display) \(unit)")
        }
        if let reps {
            parts.append("\(reps) reps")
        }
        return parts.joined(separator: " · ")
    }

    private static func displayWeight(kg: Double, usesImperial: Bool) -> String {
        let value: Double
        if usesImperial {
            value = Measurement(value: kg, unit: UnitMass.kilograms)
                .converted(to: .pounds)
                .value
        } else {
            value = kg
        }
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
