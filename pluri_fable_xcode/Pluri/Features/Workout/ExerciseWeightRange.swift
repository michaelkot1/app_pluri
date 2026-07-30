import Foundation

/// Category + display-unit ladder for the live-workout weight slider.
///
/// Ranges and classification follow `Research/Log Weight Slider Research.md`
/// (R1–R5). kg and lb ladders are independent — never convert one table into
/// the other.
struct ExerciseWeightRange: Equatable, Sendable {
    var min: Double
    var max: Double
    var step: Double
    var defaultValue: Double
    var category: Category
    /// Short caption under the numeric readout (e.g. "per dumbbell").
    var semanticsCaption: String?

    enum Category: String, Equatable, Sendable, CaseIterable {
        case barbellLower
        case barbellPress
        case barbellPull
        case dumbbellHeavy
        case dumbbellLight
        case machineCable
        case legPressHeavy
        case kettlebell
        case addedLoad
        case noLoad
        case fallback
    }

    enum DisplayUnit: Equatable, Sendable {
        case kilogram
        case pound
    }

    /// Resolves category + ladder for the given exercise metadata and display unit.
    static func resolve(
        equipment: String,
        targetMuscle: String,
        name: String = "",
        usesImperial: Bool
    ) -> ExerciseWeightRange {
        let category = classify(
            equipment: equipment,
            targetMuscle: targetMuscle,
            name: name
        )
        let unit: DisplayUnit = usesImperial ? .pound : .kilogram
        return ladder(for: category, unit: unit)
    }

    /// Ordered classification (research R1). Returns on first match.
    static func classify(
        equipment: String,
        targetMuscle: String,
        name: String
    ) -> Category {
        let equipmentKey = normalize(equipment)
        let muscleKey = normalize(targetMuscle)
        let nameKey = normalize(name)

        // 1. No-load (bodyweight / band / mat tools) unless name implies added load.
        if isNoLoadEquipment(equipmentKey),
           !nameContainsAny(nameKey, ["weighted", "vest", "belt"]) {
            return .noLoad
        }

        // 2. Added load (weighted pull-up/dip) — before machine/cable so assisted
        // machines are not misclassified as addedLoad.
        let isPullUpOrDip = nameContainsAny(nameKey, [
            "pullup", "pull up", "chinup", "chin up", "dip", "muscleup", "muscle up",
        ])
        if isPullUpOrDip, !isMachineOrCableLike(equipmentKey) {
            return .addedLoad
        }
        if nameContainsAny(nameKey, ["weighted", "vest"]),
           isBodyweightFamilyEquipment(equipmentKey) {
            return .addedLoad
        }

        // 3. Kettlebell
        if containsAny(equipmentKey, ["kettlebell", "kb"])
            || containsAny(nameKey, ["kettlebell", "kb"]) {
            return .kettlebell
        }

        // 4. Heavy sled / plate-loaded lower
        if nameContainsAny(nameKey, [
            "leg press", "hack squat", "belt squat", "pendulum squat",
        ]) {
            return .legPressHeavy
        }

        // 5. Machine / cable (smith falls through to barbell rules)
        if isMachineOrCableLike(equipmentKey), !containsAny(equipmentKey, ["smith"]) {
            return .machineCable
        }

        // 6. Dumbbell — heavy patterns before light / muscle fallback
        if containsAny(equipmentKey, ["dumbbell", "db"]) {
            if nameContainsAny(nameKey, [
                "press", "row", "squat", "deadlift", "lunge", "thruster",
                "clean", "snatch", "swing", "stepup", "step up", "farmer",
                "goblet", "shrug", "pullover", "carry",
            ]) {
                return .dumbbellHeavy
            }
            if nameContainsAny(nameKey, [
                "raise", "fly", "flye", "curl", "kickback", "extension",
                "wrist", "rotation", "pullapart", "pull apart",
            ]) {
                return .dumbbellLight
            }
            if isLightDumbbellMuscle(muscleKey) {
                return .dumbbellLight
            }
            return .dumbbellHeavy
        }

        // 7. Barbell (incl. smith / trap / ez / landmine)
        if isBarbellEquipment(equipmentKey) {
            if nameContainsAny(nameKey, [
                "squat", "deadlift", "hip thrust", "glute bridge", "lunge",
                "good morning", "rdl", "romanian", "stepup", "step up", "calf raise",
            ]) || isLowerBodyMuscle(muscleKey) {
                return .barbellLower
            }
            if nameContainsAny(nameKey, [
                "row", "clean", "snatch", "shrug", "curl", "high pull",
            ]) || isPullMuscle(muscleKey) {
                return .barbellPull
            }
            return .barbellPress
        }

        // 8. Equipment known, movement unknown
        if isBarbellEquipment(equipmentKey) { return .barbellPress }
        if containsAny(equipmentKey, ["dumbbell", "db"]) { return .dumbbellHeavy }
        if isMachineOrCableLike(equipmentKey) { return .machineCable }
        if containsAny(equipmentKey, ["kettlebell", "kb"]) { return .kettlebell }

        // 9. Fallback
        return .fallback
    }

    /// Whether the live card should use an in-card stopwatch (no weight slider).
    static func usesDurationLogging(
        equipment: String,
        targetMuscle: String,
        name: String
    ) -> Bool {
        classify(equipment: equipment, targetMuscle: targetMuscle, name: name) == .noLoad
    }

    /// Snap `raw` to the nearest step within `[min, max]` (research R3).
    func snapped(_ raw: Double) -> Double {
        guard step > 0, raw.isFinite else {
            return defaultValue
        }
        let lower = self.min
        let upper = self.max
        let clamped = Swift.min(Swift.max(raw, lower), upper)
        let steps = ((clamped - lower) / step).rounded()
        let snapped = lower + steps * step
        return Swift.min(Swift.max(snapped, lower), upper)
    }

    /// Widen bounds so a seed (and history) still fit on the slider (research R4).
    func widening(toContain seed: Double) -> ExerciseWeightRange {
        guard seed.isFinite else { return self }
        let effectiveMax = Swift.max(self.max, ceilToStep(seed * 1.5))
        let effectiveMin = Swift.min(self.min, floorToStep(seed))
        return ExerciseWeightRange(
            min: effectiveMin,
            max: effectiveMax,
            step: step,
            defaultValue: snapped(seed),
            category: category,
            semanticsCaption: semanticsCaption
        )
    }

    /// Prefer last logged display weight; else category default — then snap (R5).
    func seeded(withLastLoggedDisplay lastLogged: Double?) -> Double {
        if let lastLogged, lastLogged.isFinite {
            return widening(toContain: lastLogged).snapped(lastLogged)
        }
        return snapped(defaultValue)
    }

    // MARK: - Ladders

    static func ladder(for category: Category, unit: DisplayUnit) -> ExerciseWeightRange {
        switch (category, unit) {
        case (.barbellLower, .kilogram):
            return make(10, 300, 2.5, 20, category, "including bar")
        case (.barbellLower, .pound):
            return make(25, 700, 5, 45, category, "including bar")
        case (.barbellPress, .kilogram):
            return make(10, 220, 2.5, 20, category, "including bar")
        case (.barbellPress, .pound):
            return make(25, 500, 5, 45, category, "including bar")
        case (.barbellPull, .kilogram):
            return make(10, 200, 2.5, 20, category, "including bar")
        case (.barbellPull, .pound):
            return make(25, 450, 5, 45, category, "including bar")
        case (.dumbbellHeavy, .kilogram):
            return make(2.5, 60, 2.5, 10, category, "per dumbbell")
        case (.dumbbellHeavy, .pound):
            return make(5, 150, 5, 25, category, "per dumbbell")
        case (.dumbbellLight, .kilogram):
            return make(1, 40, 1, 5, category, "per dumbbell")
        case (.dumbbellLight, .pound):
            return make(2.5, 90, 2.5, 10, category, "per dumbbell")
        case (.machineCable, .kilogram):
            return make(2.5, 150, 2.5, 25, category, "as shown on the machine")
        case (.machineCable, .pound):
            return make(5, 350, 5, 50, category, "as shown on the machine")
        case (.legPressHeavy, .kilogram):
            return make(20, 400, 5, 60, category, "as shown on the machine")
        case (.legPressHeavy, .pound):
            return make(45, 900, 5, 135, category, "as shown on the machine")
        case (.kettlebell, .kilogram):
            return make(4, 48, 2, 8, category, nil)
        case (.kettlebell, .pound):
            return make(5, 105, 5, 20, category, nil)
        case (.addedLoad, .kilogram):
            return make(0, 100, 2.5, 0, category, "added weight")
        case (.addedLoad, .pound):
            return make(0, 220, 5, 0, category, "added weight")
        case (.noLoad, .kilogram), (.noLoad, .pound):
            return ExerciseWeightRange(
                min: 0,
                max: 0,
                step: 1,
                defaultValue: 0,
                category: .noLoad,
                semanticsCaption: nil
            )
        case (.fallback, .kilogram):
            return make(0, 200, 2.5, 10, category, nil)
        case (.fallback, .pound):
            return make(0, 450, 5, 25, category, nil)
        }
    }

    // MARK: - Private helpers

    private static func make(
        _ min: Double,
        _ max: Double,
        _ step: Double,
        _ defaultValue: Double,
        _ category: Category,
        _ caption: String?
    ) -> ExerciseWeightRange {
        ExerciseWeightRange(
            min: min,
            max: max,
            step: step,
            defaultValue: defaultValue,
            category: category,
            semanticsCaption: caption
        )
    }

    private func ceilToStep(_ value: Double) -> Double {
        guard step > 0 else { return value }
        let steps = ((value - min) / step).rounded(.up)
        return min + Swift.max(0, steps) * step
    }

    private func floorToStep(_ value: Double) -> Double {
        guard step > 0 else { return value }
        let steps = ((value - min) / step).rounded(.down)
        return min + steps * step
    }

    private static func normalize(_ raw: String) -> String {
        let lowered = raw.lowercased()
        var result = ""
        var lastWasSpace = false
        for character in lowered {
            if character.isLetter || character.isNumber {
                result.append(character)
                lastWasSpace = false
            } else if !lastWasSpace {
                result.append(" ")
                lastWasSpace = true
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }

    private static func nameContainsAny(_ nameKey: String, _ needles: [String]) -> Bool {
        containsAny(nameKey, needles.map { normalize($0) })
    }

    private static func isNoLoadEquipment(_ key: String) -> Bool {
        let tokens = [
            "body weight", "bodyweight", "none", "band", "resistance band",
            "mini band", "loop band", "trx", "suspension", "mat", "foam roller",
            "stability ball", "bosu", "bosu ball", "roller", "wheel roller",
        ]
        return tokens.contains { key == $0 || key.hasPrefix($0 + " ") || key.contains($0) }
            && !key.contains("assisted")
    }

    private static func isBodyweightFamilyEquipment(_ key: String) -> Bool {
        containsAny(key, ["body weight", "bodyweight", "none", "weighted", "belt", "vest"])
    }

    private static func isMachineOrCableLike(_ key: String) -> Bool {
        containsAny(key, [
            "machine", "cable", "selectorized", "selectorised", "pin loaded",
            "pulley", "stack", "sled", "assisted", "leverage",
        ])
    }

    private static func isBarbellEquipment(_ key: String) -> Bool {
        containsAny(key, [
            "barbell", "ez barbell", "ez bar", "trap bar", "hex bar",
            "smith", "landmine", "olympic barbell",
        ])
            // bare "bar" but not "barbell" already covered — avoid "stability ball"
            || (key.contains(" bar") || key.hasPrefix("bar ") || key == "bar")
    }

    private static func isLightDumbbellMuscle(_ key: String) -> Bool {
        containsAny(key, [
            "shoulder", "bicep", "tricep", "forearm", "rear delt", "arm", "deltoid",
        ])
    }

    private static func isLowerBodyMuscle(_ key: String) -> Bool {
        containsAny(key, [
            "leg", "quad", "hamstring", "glute", "calf", "upper leg", "lower leg",
        ])
    }

    private static func isPullMuscle(_ key: String) -> Bool {
        containsAny(key, ["back", "lat", "trap", "bicep"])
    }
}
