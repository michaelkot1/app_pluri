import Foundation

/// Request body for the `ask-pluri` Edge Function (M6-03 / M6-05).
struct AskPluriRequest: Encodable, Sendable, Equatable {
    let message: String
    let conversationId: String?
    let currentPlanWorkoutId: String?

    init(
        message: String,
        conversationId: String? = nil,
        currentPlanWorkoutId: String? = nil
    ) {
        self.message = message
        self.conversationId = conversationId
        self.currentPlanWorkoutId = currentPlanWorkoutId
    }
}

/// Persisted chat row ids returned by a successful ask (optional).
struct AskPluriMessageIds: Codable, Sendable, Equatable {
    let user: String
    let assistant: String
}

/// Structured coach tool actions returned by `ask-pluri` (SPEC §14 #66g).
/// Returned to the client only — never applied here (M6-09/10 owns PlanStore).
enum AskPluriAction: Codable, Sendable, Equatable {
    case addWorkout(sourceWorkoutId: String, date: String)
    case removeWorkout(planWorkoutId: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case sourceWorkoutId
        case date
        case planWorkoutId
    }

    private enum ActionType: String, Codable {
        case addWorkout = "add_workout"
        case removeWorkout = "remove_workout"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ActionType.self, forKey: .type)
        switch type {
        case .addWorkout:
            self = .addWorkout(
                sourceWorkoutId: try container.decode(String.self, forKey: .sourceWorkoutId),
                date: try container.decode(String.self, forKey: .date)
            )
        case .removeWorkout:
            self = .removeWorkout(
                planWorkoutId: try container.decode(String.self, forKey: .planWorkoutId)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .addWorkout(sourceWorkoutId, date):
            try container.encode(ActionType.addWorkout, forKey: .type)
            try container.encode(sourceWorkoutId, forKey: .sourceWorkoutId)
            try container.encode(date, forKey: .date)
        case let .removeWorkout(planWorkoutId):
            try container.encode(ActionType.removeWorkout, forKey: .type)
            try container.encode(planWorkoutId, forKey: .planWorkoutId)
        }
    }
}

/// Success payload from `ask-pluri`.
struct AskPluriResponse: Decodable, Sendable, Equatable {
    let reply: String
    let conversationId: String
    let actions: [AskPluriAction]
    let messageIds: AskPluriMessageIds?

    init(
        reply: String,
        conversationId: String,
        actions: [AskPluriAction] = [],
        messageIds: AskPluriMessageIds? = nil
    ) {
        self.reply = reply
        self.conversationId = conversationId
        self.actions = actions
        self.messageIds = messageIds
    }

    private enum CodingKeys: String, CodingKey {
        case reply
        case conversationId
        case actions
        case messageIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reply = try container.decode(String.self, forKey: .reply)
        conversationId = try container.decode(String.self, forKey: .conversationId)
        actions = try container.decodeIfPresent([AskPluriAction].self, forKey: .actions) ?? []
        messageIds = try container.decodeIfPresent(AskPluriMessageIds.self, forKey: .messageIds)
    }
}

/// Busy / throttled error body from `ask-pluri` (HTTP 429 / 503).
struct AskPluriErrorBody: Decodable, Sendable, Equatable {
    enum Code: String, Decodable, Sendable {
        case busy
        case throttled
    }

    let error: Code
    let message: String
}

/// Calls the `ask-pluri` Edge Function. Abstracted behind a protocol so a live
/// Supabase-backed implementation and a deterministic mock (for previews/tests)
/// can share call sites — see PLAN §1.1 / §3. Gemini stays server-side only.
protocol AskPluriClient: Sendable {
    func ask(_ request: AskPluriRequest) async throws -> AskPluriResponse
}
