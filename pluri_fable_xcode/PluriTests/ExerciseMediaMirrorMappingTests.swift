import Foundation
import Testing
@testable import Pluri

/// Mirrored exercise media mapping (SPEC §14 #79): the Supabase `video_url`
/// column has to reach the domain model, survive a plan's `cached_metadata`
/// round-trip, and stay absent (not crash / not invent a URL) for exercises the
/// mirror job hasn't covered yet.
@Suite("Exercise media mirror mapping")
struct ExerciseMediaMirrorMappingTests {

    private static func decodeRow(_ json: String) throws -> SupabaseExerciseRow {
        try JSONDecoder().decode(SupabaseExerciseRow.self, from: Data(json.utf8))
    }

    @Test("Catalog row maps video_url into Exercise.videoURL")
    func rowMapsVideoURL() throws {
        let row = try Self.decodeRow(
            """
            {
              "id": "0031",
              "name": "Barbell Curl",
              "body_part": "Upper Arms",
              "equipment": "Barbell",
              "target": "Biceps",
              "secondary_muscles": ["Forearms"],
              "instructions": ["Stand tall."],
              "gif_url": "https://api.workoutxapp.com/v1/gifs/0031.gif",
              "video_url": "https://cdn.example/storage/v1/object/public/exercise-media/exercises/0031.mp4"
            }
            """
        )

        let exercise = row.asDomainExercise
        #expect(
            exercise.videoURL?.absoluteString
                == "https://cdn.example/storage/v1/object/public/exercise-media/exercises/0031.mp4"
        )
        // The WorkoutX original is retained as provenance but is never loaded.
        #expect(exercise.imageURL?.absoluteString == "https://api.workoutxapp.com/v1/gifs/0031.gif")
    }

    @Test("Unmirrored catalog row leaves videoURL nil")
    func unmirroredRowHasNoVideo() throws {
        let row = try Self.decodeRow(
            """
            {
              "id": "0002",
              "name": "45° Side Bend",
              "body_part": "Waist",
              "equipment": "Body Weight",
              "target": "Abs",
              "secondary_muscles": [],
              "instructions": [],
              "gif_url": "https://api.workoutxapp.com/v1/gifs/0002.gif",
              "video_url": null
            }
            """
        )
        #expect(row.asDomainExercise.videoURL == nil)
    }

    @Test("Selected columns request video_url")
    func selectedColumnsIncludeVideoURL() {
        #expect(SupabaseExerciseRow.selectedColumns.contains("video_url"))
    }

    @Test("cached_metadata carries video_url through a plan round-trip")
    func cachedMetadataRoundTrip() throws {
        let videoURL = URL(string: "https://cdn.example/exercise-media/exercises/0031.mp4")!
        let session = PlannedSession(
            title: "Pull",
            indexInWeek: 1,
            weekday: .monday,
            date: .now,
            exercises: [
                PlannedExercise(
                    exerciseID: "0031",
                    name: "Barbell Curl",
                    bodyPart: "Upper Arms",
                    equipment: "Barbell",
                    targetMuscle: "Biceps",
                    secondaryMuscles: [],
                    imageURL: nil,
                    videoURL: videoURL,
                    order: 0,
                    sets: 3,
                    reps: 10
                )
            ]
        )

        let rows = OnboardingSyncMapper.exerciseRows(for: session)
        #expect(rows.first?.cachedMetadata.videoURL == videoURL.absoluteString)

        // The row must survive JSON, since that's how it reaches Postgres.
        let encoded = try JSONEncoder().encode(rows)
        #expect(String(decoding: encoded, as: UTF8.self).contains("video_url"))
        let decoded = try JSONDecoder().decode([WorkoutExerciseInsertRow].self, from: encoded)
        #expect(decoded.first?.cachedMetadata.videoURL == videoURL.absoluteString)
    }

    @Test("Legacy cached_metadata without video_url still decodes")
    func legacyCachedMetadataDecodes() throws {
        let metadata = try JSONDecoder().decode(
            ExerciseCachedMetadata.self,
            from: Data(
                """
                {
                  "name": "Barbell Curl",
                  "body_part": "Upper Arms",
                  "equipment": "Barbell",
                  "target_muscle": "Biceps",
                  "secondary_muscles": [],
                  "image_url": "https://api.workoutxapp.com/v1/gifs/0031.gif"
                }
                """.utf8
            )
        )
        #expect(metadata.videoURL == nil)
        #expect(metadata.name == "Barbell Curl")
    }
}
