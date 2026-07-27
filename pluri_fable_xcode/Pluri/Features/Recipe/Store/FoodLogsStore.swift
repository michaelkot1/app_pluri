import Foundation
import SwiftData
import os.log

/// Offline-first food log store (M7-11 / SPEC §14 #67f/g).
///
/// Insert / day reads always hit SwiftData first and never block on network.
/// Opportunistic sync to `food_logs` goes through `SyncEngine`.
@MainActor
@Observable
final class FoodLogsStore {
    private let modelContext: ModelContext
    private let userId: UUID
    private let syncEngine: any SyncEngine
    private let calendar: Calendar
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "FoodLogs")

    init(
        modelContext: ModelContext,
        userId: UUID,
        syncEngine: (any SyncEngine)? = nil,
        calendar: Calendar = .current
    ) {
        self.modelContext = modelContext
        self.userId = userId
        self.syncEngine = syncEngine ?? NoopSyncEngine()
        self.calendar = calendar
    }

    /// Inserts a food log locally and enqueues opportunistic sync.
    ///
    /// - Precondition: `calories >= 0`. Callers must refuse nil-kcal Nutrition
    ///   hits before calling (SPEC §14 #68).
    @discardableResult
    func insert(
        foodName: String,
        serving: String,
        calories: Int,
        meal: FoodLogMeal,
        loggedDate: Date,
        macros: FoodLogMacrosJSON? = nil,
        mealdbRecipeId: String? = nil,
        nutritionFoodId: String? = nil
    ) throws -> FoodLogRecord {
        precondition(calories >= 0, "Food log calories must be known and non-negative")

        let day = calendar.startOfDay(for: loggedDate)
        let record = FoodLogRecord(
            userId: userId,
            foodName: foodName,
            serving: serving,
            calories: calories,
            macrosJSON: macros?.encoded(),
            meal: meal,
            loggedDate: day,
            mealdbRecipeId: mealdbRecipeId,
            nutritionFoodId: nutritionFoodId,
            needsSync: true,
            pendingDelete: false
        )
        modelContext.insert(record)
        try modelContext.save()
        syncEngine.enqueueFoodLog(id: record.id)
        logger.info("Logged food \(foodName, privacy: .public) (\(calories, privacy: .public) kcal)")
        return record
    }

    /// Active (non-deleted) logs for a calendar day.
    func logs(on day: Date) throws -> [FoodLogRecord] {
        let userId = self.userId
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return []
        }
        let descriptor = FetchDescriptor<FoodLogRecord>(
            predicate: #Predicate { record in
                record.userId == userId
                    && record.pendingDelete == false
                    && record.loggedDate >= start
                    && record.loggedDate < end
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Sum of known kilocalories for the day (all persisted rows have kcal).
    func dayCalorieTotal(on day: Date) throws -> Int {
        try logs(on: day).reduce(0) { $0 + $1.calories }
    }

    /// Eaten vs profile maintenance for ring UI (SPEC §14 #67h).
    func dayCalorieProgress(
        on day: Date,
        maintenanceCalories: Int?
    ) throws -> DayCalorieProgress {
        DayCalorieProgress(
            eatenCalories: try dayCalorieTotal(on: day),
            maintenanceCalories: maintenanceCalories
        )
    }
}

/// Day calorie ring inputs (eaten vs maintenance).
struct DayCalorieProgress: Equatable, Sendable {
    var eatenCalories: Int
    var maintenanceCalories: Int?

    /// 0…1 fraction of maintenance consumed (capped). Nil maintenance → 0.
    var fraction: Double {
        guard let maintenance = maintenanceCalories, maintenance > 0 else { return 0 }
        return min(1, Double(eatenCalories) / Double(maintenance))
    }

    var hasMaintenanceTarget: Bool {
        (maintenanceCalories ?? 0) > 0
    }
}
