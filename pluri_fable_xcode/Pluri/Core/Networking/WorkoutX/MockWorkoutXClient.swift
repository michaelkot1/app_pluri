import Foundation

/// Deterministic in-memory `WorkoutXClient` for previews and tests — no
/// network access, no quota usage.
struct MockWorkoutXClient: WorkoutXClient {
    let fixtures: [Exercise]

    init(fixtures: [Exercise] = .workoutXPreviewFixtures) {
        self.fixtures = fixtures
    }

    func fetchExercises(limit: Int, offset: Int) async throws -> WorkoutXExercisePage {
        let page = fixtures.dropFirst(offset).prefix(limit)
        return WorkoutXExercisePage(exercises: Array(page), total: fixtures.count)
    }

    func fetchExercise(id: String) async throws -> Exercise {
        guard let exercise = fixtures.first(where: { $0.id == id }) else {
            throw WorkoutXClientError.notFound
        }
        return exercise
    }
}

extension [Exercise] {
    /// A small, deterministic fixture set spanning a few body parts and
    /// equipment types — enough for previews and for `PlanEngine` tests
    /// (M1-16/17) to exercise equipment/injury filtering without hitting
    /// the network.
    static var workoutXPreviewFixtures: [Exercise] {
        [
            Exercise(
                id: "0001",
                name: "3/4 Sit-up",
                bodyPart: "Waist",
                equipment: "Body Weight",
                targetMuscle: "Abs",
                secondaryMuscles: ["Hip Flexors", "Lower Back"],
                instructions: [
                    "Lie flat on your back with your knees bent and feet flat on the ground.",
                    "Place your hands behind your head with your elbows pointing outwards.",
                    "Engaging your abs, slowly lift your upper body off the ground.",
                ],
                imageURL: URL(string: "https://api.workoutxapp.com/v1/gifs/0001.gif"),
                videoURL: nil
            ),
            Exercise(
                id: "0033",
                name: "Barbell Bench Press",
                bodyPart: "Chest",
                equipment: "Barbell",
                targetMuscle: "Pectorals",
                secondaryMuscles: ["Triceps", "Delts"],
                instructions: [
                    "Lie on a flat bench with the barbell racked above your chest.",
                    "Lower the bar to your mid-chest with control.",
                    "Press the bar back up to full arm extension.",
                ],
                imageURL: URL(string: "https://api.workoutxapp.com/v1/gifs/0033.gif"),
                videoURL: nil
            ),
            Exercise(
                id: "0210",
                name: "Dumbbell Goblet Squat",
                bodyPart: "Upper Legs",
                equipment: "Dumbbell",
                targetMuscle: "Quads",
                secondaryMuscles: ["Glutes", "Hamstrings"],
                instructions: [
                    "Hold a dumbbell vertically against your chest.",
                    "Squat down until your thighs are parallel to the floor.",
                    "Drive through your heels to stand back up.",
                ],
                imageURL: URL(string: "https://api.workoutxapp.com/v1/gifs/0210.gif"),
                videoURL: nil
            ),
            Exercise(
                id: "0415",
                name: "Lat Pulldown",
                bodyPart: "Back",
                equipment: "Cable",
                targetMuscle: "Lats",
                secondaryMuscles: ["Biceps", "Upper Back"],
                instructions: [
                    "Grip the bar wider than shoulder-width and sit with thighs secured.",
                    "Pull the bar down to your upper chest, squeezing your shoulder blades.",
                    "Slowly extend your arms back to the start.",
                ],
                imageURL: URL(string: "https://api.workoutxapp.com/v1/gifs/0415.gif"),
                videoURL: nil
            ),
            Exercise(
                id: "0512",
                name: "Kettlebell Shoulder Press",
                bodyPart: "Shoulders",
                equipment: "Kettlebell",
                targetMuscle: "Delts",
                secondaryMuscles: ["Triceps"],
                instructions: [
                    "Hold a kettlebell at shoulder height, elbow bent.",
                    "Press the kettlebell overhead until your arm is straight.",
                    "Lower with control back to shoulder height.",
                ],
                imageURL: URL(string: "https://api.workoutxapp.com/v1/gifs/0512.gif"),
                videoURL: nil
            ),
            Exercise(
                id: "0620",
                name: "Resistance Band Row",
                bodyPart: "Back",
                equipment: "Resistance Band",
                targetMuscle: "Upper Back",
                secondaryMuscles: ["Biceps"],
                instructions: [
                    "Anchor the band and hold an end in each hand, arms extended.",
                    "Pull both handles toward your torso, squeezing your shoulder blades.",
                    "Slowly return to the starting position.",
                ],
                imageURL: URL(string: "https://api.workoutxapp.com/v1/gifs/0620.gif"),
                videoURL: nil
            ),
        ]
    }
}
