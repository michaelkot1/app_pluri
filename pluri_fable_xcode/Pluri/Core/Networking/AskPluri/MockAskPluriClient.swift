import Foundation

/// Deterministic in-memory `AskPluriClient` for previews and tests — no
/// network access, no Gemini key, no Edge Function quota.
struct MockAskPluriClient: AskPluriClient, Sendable {
    /// Fixed success response when `errorToThrow` is nil.
    var response: AskPluriResponse

    /// When set, `ask` throws this instead of returning `response`.
    var errorToThrow: AskPluriClientError?

    /// Optional delay for preview loading states.
    var delay: Duration?

    /// Records the most recent request (tests / previews).
    private let recorder: RequestRecorder

    var lastRequest: AskPluriRequest? { recorder.lastRequest }

    init(
        response: AskPluriResponse = .previewFixture,
        errorToThrow: AskPluriClientError? = nil,
        delay: Duration? = nil
    ) {
        self.response = response
        self.errorToThrow = errorToThrow
        self.delay = delay
        self.recorder = RequestRecorder()
    }

    func ask(_ request: AskPluriRequest) async throws -> AskPluriResponse {
        recorder.lastRequest = request
        if let delay {
            try await Task.sleep(for: delay)
        }
        if let errorToThrow {
            throw errorToThrow
        }
        if let conversationId = request.conversationId {
            return AskPluriResponse(
                reply: response.reply,
                conversationId: conversationId,
                actions: response.actions,
                messageIds: response.messageIds
            )
        }
        return response
    }
}

extension AskPluriResponse {
    /// Small deterministic coach reply for previews and unit tests.
    static var previewFixture: AskPluriResponse {
        AskPluriResponse(
            reply: "You've got this — keep the next set controlled and stop one rep before form breaks.",
            conversationId: "00000000-0000-4000-8000-000000000001",
            actions: [],
            messageIds: AskPluriMessageIds(
                user: "00000000-0000-4000-8000-000000000010",
                assistant: "00000000-0000-4000-8000-000000000011"
            )
        )
    }
}

extension MockAskPluriClient {
    /// Reference-typed box so the Sendable struct can record requests.
    final class RequestRecorder: @unchecked Sendable {
        var lastRequest: AskPluriRequest?
    }
}
