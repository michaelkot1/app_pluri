import Foundation
import Supabase
import os.log

/// Loads prior Ask Pluri turns from `chat_messages` (RLS owner-only).
protocol AskPluriHistoryLoading: Sendable {
    func loadLatestConversation() async throws -> AskPluriConversationSnapshot
}

/// Row shape for `public.chat_messages` select (M6-02 / #66b).
nonisolated struct ChatMessageRow: Decodable, Sendable, Equatable {
    let id: UUID
    let conversationId: UUID
    let role: String
    let content: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role
        case content
        case createdAt = "created_at"
    }
}

/// Live history loader via Supabase PostgREST + RLS.
struct LiveAskPluriHistoryLoader: AskPluriHistoryLoading {
    private let client: SupabaseClient
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "AskPluriHistory")

    /// Caps reopen payload; EF also loads a recent window for grounding.
    private let fetchLimit = 80

    init(client: SupabaseClient) {
        self.client = client
    }

    @MainActor
    init(supabaseService: SupabaseService) {
        self.init(client: supabaseService.client)
    }

    func loadLatestConversation() async throws -> AskPluriConversationSnapshot {
        do {
            let rows: [ChatMessageRow] = try await client
                .from("chat_messages")
                .select("id, conversation_id, role, content, created_at")
                .order("created_at", ascending: false)
                .limit(fetchLimit)
                .execute()
                .value

            guard let latestConversationId = rows.first?.conversationId else {
                return .empty
            }

            let chronological = rows
                .filter { $0.conversationId == latestConversationId }
                .reversed()
                .compactMap(Self.mapRow)

            return AskPluriConversationSnapshot(
                conversationId: latestConversationId.uuidString,
                messages: chronological
            )
        } catch {
            logger.error("chat_messages history load failed: \(error.localizedDescription)")
            throw AskPluriClientError.transport(
                "We couldn't load your chat history. Check your connection and try again."
            )
        }
    }

    private static func mapRow(_ row: ChatMessageRow) -> AskPluriChatMessage? {
        guard let role = AskPluriChatMessage.Role(rawValue: row.role) else { return nil }
        // System rows stay out of the bubble list for v1 coach UI.
        guard role != .system else { return nil }
        return AskPluriChatMessage(
            id: row.id.uuidString,
            role: role,
            content: row.content,
            createdAt: parseTimestamp(row.createdAt)
        )
    }

    private static func parseTimestamp(_ value: String) -> Date {
        if let date = try? Date(value, strategy: .iso8601) {
            return date
        }
        // Fallback keeps list order from the query when fractional-second
        // timestamptz strings don't match the default ISO strategy.
        return .now
    }
}

/// Deterministic history for previews and unit tests.
struct MockAskPluriHistoryLoader: AskPluriHistoryLoading, Sendable {
    var snapshot: AskPluriConversationSnapshot
    var errorToThrow: AskPluriClientError?

    init(
        snapshot: AskPluriConversationSnapshot = .empty,
        errorToThrow: AskPluriClientError? = nil
    ) {
        self.snapshot = snapshot
        self.errorToThrow = errorToThrow
    }

    func loadLatestConversation() async throws -> AskPluriConversationSnapshot {
        if let errorToThrow {
            throw errorToThrow
        }
        return snapshot
    }
}
