import Foundation
import SwiftData
import os.log

/// SwiftData cache for day suggestions + candidate pool (M7-08 / #67g).
@MainActor
final class RecipeSuggestionsCache {
    private let modelContext: ModelContext
    private let userId: UUID
    private let calendar: Calendar
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "RecipeCache")

    /// Candidate pool older than this is refreshed when online.
    static let candidatePoolMaxAge: TimeInterval = 7 * 24 * 60 * 60

    init(
        modelContext: ModelContext,
        userId: UUID,
        calendar: Calendar = .current
    ) {
        self.modelContext = modelContext
        self.userId = userId
        self.calendar = calendar
    }

    // MARK: - Day suggestions

    func dayKey(for day: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let dayValue = parts.day ?? 0
        return "\(year)-\(pad2(month))-\(pad2(dayValue))"
    }

    func loadDaySuggestions(for day: Date) throws -> RecipeSuggestionEngine.DaySuggestions? {
        let key = dayKey(for: day)
        let userId = self.userId
        var descriptor = FetchDescriptor<RecipeDaySuggestionsRecord>(
            predicate: #Predicate { record in
                record.userId == userId && record.dayKey == key
            }
        )
        descriptor.fetchLimit = 1
        guard let record = try modelContext.fetch(descriptor).first else { return nil }
        let payload = try decoder.decode(RecipeDaySuggestionsPayload.self, from: record.payloadJSON)
        return payload.asDaySuggestions
    }

    func saveDaySuggestions(
        _ suggestions: RecipeSuggestionEngine.DaySuggestions,
        for day: Date
    ) throws {
        let key = dayKey(for: day)
        let payload = RecipeDaySuggestionsPayload(from: suggestions)
        let data = try encoder.encode(payload)
        let userId = self.userId

        var descriptor = FetchDescriptor<RecipeDaySuggestionsRecord>(
            predicate: #Predicate { record in
                record.userId == userId && record.dayKey == key
            }
        )
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            existing.payloadJSON = data
            existing.updatedAt = .now
        } else {
            modelContext.insert(
                RecipeDaySuggestionsRecord(
                    userId: userId,
                    dayKey: key,
                    payloadJSON: data
                )
            )
        }
        try modelContext.save()
    }

    // MARK: - Candidate pool

    func loadCandidatePool() throws -> (recipes: [MealDBRecipe], updatedAt: Date)? {
        let userId = self.userId
        var descriptor = FetchDescriptor<RecipeCandidatePoolRecord>(
            predicate: #Predicate { record in
                record.userId == userId
            }
        )
        descriptor.fetchLimit = 1
        guard let record = try modelContext.fetch(descriptor).first else { return nil }
        let recipes = try decoder.decode([MealDBRecipe].self, from: record.payloadJSON)
        return (recipes, record.updatedAt)
    }

    func saveCandidatePool(_ recipes: [MealDBRecipe]) throws {
        let data = try encoder.encode(recipes)
        let userId = self.userId
        var descriptor = FetchDescriptor<RecipeCandidatePoolRecord>(
            predicate: #Predicate { record in
                record.userId == userId
            }
        )
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            existing.payloadJSON = data
            existing.updatedAt = .now
        } else {
            modelContext.insert(
                RecipeCandidatePoolRecord(userId: userId, payloadJSON: data)
            )
        }
        try modelContext.save()
        logger.info("Saved candidate pool (\(recipes.count, privacy: .public) recipes)")
    }

    func isCandidatePoolFresh(_ updatedAt: Date, now: Date = .now) -> Bool {
        now.timeIntervalSince(updatedAt) < Self.candidatePoolMaxAge
    }

    private func pad2(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
