import SwiftData
import SwiftUI

@main
struct PluriApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema([
            CachedExercise.self,
            ExerciseCatalogSyncState.self,
            WorkoutSessionRecord.self,
            SetLogRecord.self,
            RecipeFavoriteRecord.self,
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            // Unrecoverable: the app has no useful offline-first behavior
            // without its local store.
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView(modelContainer: modelContainer)
        }
        .modelContainer(modelContainer)
    }
}
