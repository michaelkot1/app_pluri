import Foundation

/// One bubble in the Ask Pluri chat list (M6-06).
struct AskPluriChatMessage: Identifiable, Equatable, Sendable {
    enum Role: String, Sendable {
        case user
        case assistant
        case system
    }

    let id: String
    let role: Role
    let content: String
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        role: Role,
        content: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

/// Latest remote conversation snapshot for chat reopen (SPEC §14 #66b).
struct AskPluriConversationSnapshot: Equatable, Sendable {
    var conversationId: String?
    var messages: [AskPluriChatMessage]

    static let empty = AskPluriConversationSnapshot(conversationId: nil, messages: [])
}
