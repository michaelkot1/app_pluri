import Foundation

/// Wire-format row of the Supabase `public.exercises` table — the seeded 1:1
/// snapshot of the WorkoutX catalog (1,327 rows, see the WorkoutX README's
/// "Legacy Supabase `exercises` table" section). Only the columns Pluri uses
/// are selected/decoded; the table also carries `category`, `difficulty`,
/// `met`, `movement_tags`, etc.
struct SupabaseExerciseRow: Decodable, Sendable {
    let id: String
    let name: String
    let bodyPart: String
    let equipment: String
    let target: String
    let secondaryMuscles: [String]
    let instructions: [String]

    /// Original WorkoutX GIF URL. Needs an `X-WorkoutX-Key` header, so the app
    /// can never fetch it — kept only as provenance (SPEC §14 #79).
    let gifUrl: String?

    /// Public CDN URL of Pluri's mirrored MP4, `nil` until the mirror job has
    /// run for this exercise (SPEC §14 #79).
    let videoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case bodyPart = "body_part"
        case equipment
        case target
        case secondaryMuscles = "secondary_muscles"
        case instructions
        case gifUrl = "gif_url"
        case videoUrl = "video_url"
    }

    /// Columns to request from PostgREST, matching the decoded fields above.
    static let selectedColumns = "id, name, body_part, equipment, target, secondary_muscles, instructions, gif_url, video_url"

    var asDomainExercise: Exercise {
        Exercise(
            id: id,
            name: name,
            bodyPart: bodyPart,
            equipment: equipment,
            targetMuscle: target,
            secondaryMuscles: secondaryMuscles,
            instructions: instructions,
            imageURL: gifUrl.flatMap(URL.init(string:)),
            videoURL: videoUrl.flatMap(URL.init(string:))
        )
    }
}
