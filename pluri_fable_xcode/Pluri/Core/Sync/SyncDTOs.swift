import Foundation

/// One injury entry stored in `profiles.injuries` jsonb (M2-13 / SPEC §14).
nonisolated struct InjuryJSON: Codable, Hashable, Sendable, Equatable {
    let area: String
    let pain: Int
}

/// Upsert payload for `public.profiles` (`id = auth.uid()`).
nonisolated struct ProfileUpsertRow: Codable, Hashable, Sendable, Equatable {
    var id: UUID
    var displayName: String
    var goal: String
    var trainingExperience: String
    var trainingRegularity: String
    var workoutLocation: String
    var injuries: [InjuryJSON]
    var daysPerWeek: Int
    var workoutDays: [String]
    var scheduleType: String
    var programWeeks: Int
    var sessionMinutes: Int
    var age: Int?
    var gender: String?
    var heightCm: Double?
    var weightKg: Double?
    var startDate: String
    var onboardingCompleted: Bool
    var units: String
    var maintenanceCalories: Int?
    var allergies: [String]
    var equipment: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case goal
        case trainingExperience = "training_experience"
        case trainingRegularity = "training_regularity"
        case workoutLocation = "workout_location"
        case injuries
        case daysPerWeek = "days_per_week"
        case workoutDays = "workout_days"
        case scheduleType = "schedule_type"
        case programWeeks = "program_weeks"
        case sessionMinutes = "session_minutes"
        case age
        case gender
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case startDate = "start_date"
        case onboardingCompleted = "onboarding_completed"
        case units
        case maintenanceCalories = "maintenance_calories"
        case allergies
        case equipment
    }
}

/// Insert payload for `public.plans`.
nonisolated struct PlanInsertRow: Codable, Hashable, Sendable, Equatable {
    var id: UUID
    var userId: UUID
    var goal: String
    var name: String?
    var startDate: String
    var endDate: String
    var weeks: Int
    var scheduleType: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case goal
        case name
        case startDate = "start_date"
        case endDate = "end_date"
        case weeks
        case scheduleType = "schedule_type"
        case status
    }
}

/// Insert payload for `public.plan_workouts`.
nonisolated struct PlanWorkoutInsertRow: Codable, Hashable, Sendable, Equatable {
    var id: UUID
    var planId: UUID
    var weekNumber: Int
    var scheduledDate: String?
    var scheduledDay: String?
    var name: String
    var workoutType: String
    var color: String?
    /// Session focus code (`SessionFocusCode.rawValue`); `nil` for legacy rows.
    var focus: String?
    var durationMinutes: Int
    var status: String
    var orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case weekNumber = "week_number"
        case scheduledDate = "scheduled_date"
        case scheduledDay = "scheduled_day"
        case name
        case workoutType = "workout_type"
        case color
        case focus
        case durationMinutes = "duration_minutes"
        case status
        case orderIndex = "order_index"
    }
}

/// Cached exercise fields inside `workout_exercises.cached_metadata`.
nonisolated struct ExerciseCachedMetadata: Codable, Hashable, Sendable, Equatable {
    var name: String
    var bodyPart: String
    var equipment: String
    var targetMuscle: String
    var secondaryMuscles: [String]
    var imageURL: String?

    /// Mirrored MP4 CDN URL (SPEC §14 #79). Absent on rows written before the
    /// mirror shipped, which decode to `nil` and fall back to the catalog.
    var videoURL: String? = nil

    enum CodingKeys: String, CodingKey {
        case name
        case bodyPart = "body_part"
        case equipment
        case targetMuscle = "target_muscle"
        case secondaryMuscles = "secondary_muscles"
        case imageURL = "image_url"
        case videoURL = "video_url"
    }
}

/// Insert payload for `public.workout_exercises`.
nonisolated struct WorkoutExerciseInsertRow: Codable, Hashable, Sendable, Equatable {
    var id: UUID
    var planWorkoutId: UUID
    var workoutxExerciseId: String
    var cachedMetadata: ExerciseCachedMetadata
    var targetSets: Int?
    var targetReps: String?
    var targetDurationSeconds: Int?
    var orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case id
        case planWorkoutId = "plan_workout_id"
        case workoutxExerciseId = "workoutx_exercise_id"
        case cachedMetadata = "cached_metadata"
        case targetSets = "target_sets"
        case targetReps = "target_reps"
        case targetDurationSeconds = "target_duration_seconds"
        case orderIndex = "order_index"
    }
}

/// Full plan tree ready for a transactional-ish flush (insert plan → workouts → exercises).
nonisolated struct PlanTreeInsert: Sendable, Equatable {
    var plan: PlanInsertRow
    var workouts: [PlanWorkoutInsertRow]
    var exercises: [WorkoutExerciseInsertRow]
}

/// Partial update payload for `public.plans` (M3-05, Manage Plan §6.2).
/// Optionals encode with `encodeIfPresent`, so `nil` fields are simply
/// omitted from the PATCH body rather than nulling columns.
nonisolated struct PlanSettingsUpdateRow: Codable, Hashable, Sendable, Equatable {
    var goal: String?
    var name: String?
    var startDate: String?
    var endDate: String?
    var weeks: Int?
    var scheduleType: String?
    var status: String?

    enum CodingKeys: String, CodingKey {
        case goal
        case name
        case startDate = "start_date"
        case endDate = "end_date"
        case weeks
        case scheduleType = "schedule_type"
        case status
    }
}

/// The single `payload jsonb` argument of the `replace_remaining_plan`
/// Postgres function (M3-14): plan settings + profile settings + the
/// insert / update / delete workout row sets, applied in **one database
/// transaction** so a mid-sequence failure can never leave a partially
/// replaced remote plan. Ownership is enforced inside the function via
/// `auth.uid()` (SECURITY INVOKER, RLS applies).
nonisolated struct ManagePlanRPCPayload: Codable, Hashable, Sendable, Equatable {
    var planId: UUID
    var planUpdate: PlanSettingsUpdateRow
    var profileUpdate: ProfileSettingsUpdateRow
    var insertWorkouts: [PlanWorkoutInsertRow]
    var insertExercises: [WorkoutExerciseInsertRow]
    var updateWorkouts: [PlanWorkoutInsertRow]
    var deleteWorkoutIds: [UUID]

    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case planUpdate = "plan_update"
        case profileUpdate = "profile_update"
        case insertWorkouts = "insert_workouts"
        case insertExercises = "insert_exercises"
        case updateWorkouts = "update_workouts"
        case deleteWorkoutIds = "delete_workout_ids"
    }
}

/// Partial update payload for `public.profiles` (M3-05, Manage Plan §6.2:
/// goal, dates/length, training days, session duration, units).
nonisolated struct ProfileSettingsUpdateRow: Codable, Hashable, Sendable, Equatable {
    var goal: String?
    var daysPerWeek: Int?
    var workoutDays: [String]?
    var scheduleType: String?
    var programWeeks: Int?
    var sessionMinutes: Int?
    var startDate: String?
    var units: String?

    enum CodingKeys: String, CodingKey {
        case goal
        case daysPerWeek = "days_per_week"
        case workoutDays = "workout_days"
        case scheduleType = "schedule_type"
        case programWeeks = "program_weeks"
        case sessionMinutes = "session_minutes"
        case startDate = "start_date"
        case units
    }
}

/// Upsert payload for `public.workout_sessions` (M4-03).
/// Local-only pause / per-exercise note fields (SPEC §14 #51) are excluded.
nonisolated struct WorkoutSessionUpsertRow: Codable, Hashable, Sendable, Equatable {
    var id: UUID
    var userId: UUID
    var planWorkoutId: UUID?
    var activityType: String
    var startedAt: String
    var endedAt: String?
    var durationSeconds: Int?
    var distanceMeters: Double?
    var notes: String?
    var syncedToHealth: Bool
    var isManualLog: Bool
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case planWorkoutId = "plan_workout_id"
        case activityType = "activity_type"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case distanceMeters = "distance_meters"
        case notes
        case syncedToHealth = "synced_to_health"
        case isManualLog = "is_manual_log"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Upsert payload for `public.set_logs` (M4-03).
nonisolated struct SetLogUpsertRow: Codable, Hashable, Sendable, Equatable {
    var id: UUID
    var sessionId: UUID
    var workoutExerciseId: UUID?
    var exerciseName: String
    var setNumber: Int
    var reps: Int?
    var weightKg: Double?
    var durationSeconds: Int?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case workoutExerciseId = "workout_exercise_id"
        case exerciseName = "exercise_name"
        case setNumber = "set_number"
        case reps
        case weightKg = "weight_kg"
        case durationSeconds = "duration_seconds"
        case createdAt = "created_at"
    }
}

/// Thin `plan_workouts` status update used by SyncEngine when a session is saved
/// as completed (M4-03 / SPEC §14 #52). Session link lives on
/// `workout_sessions.plan_workout_id` — there is no `plan_workouts.session_id`.
nonisolated struct PlanWorkoutStatusUpdateRow: Codable, Hashable, Sendable, Equatable {
    var status: String
}

/// Upsert payload for `public.recipe_favorites` (M7-07 / SPEC §14 #67f).
/// LWW via `onConflict: id`. Unique `(user_id, mealdb_recipe_id)` is also
/// enforced remotely for toggle safety.
nonisolated struct RecipeFavoriteUpsertRow: Codable, Hashable, Sendable, Equatable {
    var id: UUID
    var userId: UUID
    var mealdbRecipeId: String
    var cachedTitle: String?
    var cachedThumbURL: String?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case mealdbRecipeId = "mealdb_recipe_id"
        case cachedTitle = "cached_title"
        case cachedThumbURL = "cached_thumb_url"
        case createdAt = "created_at"
    }
}

/// Upsert payload for `public.food_logs` (M7-11 / SPEC §14 #67f).
/// LWW via `onConflict: id`. Calories are always present — nil-kcal Nutrition
/// hits are never persisted (SPEC §14 #68).
nonisolated struct FoodLogUpsertRow: Codable, Hashable, Sendable, Equatable {
    var id: UUID
    var userId: UUID
    var foodName: String
    var serving: String
    var calories: Int
    var macros: FoodLogMacrosJSON?
    var meal: String
    var loggedDate: String
    var mealdbRecipeId: String?
    var nutritionFoodId: String?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case foodName = "food_name"
        case serving
        case calories
        case macros
        case meal
        case loggedDate = "logged_date"
        case mealdbRecipeId = "mealdb_recipe_id"
        case nutritionFoodId = "nutrition_food_id"
        case createdAt = "created_at"
    }
}
