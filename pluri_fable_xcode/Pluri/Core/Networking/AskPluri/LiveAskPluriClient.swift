import Foundation
import Supabase
import os.log

/// Live `AskPluriClient` that invokes the `ask-pluri` Edge Function with the
/// signed-in user's JWT + publishable/anon key. Never embeds the Gemini API
/// key (PLAN §1.1, SPEC §14 #6 / #66i).
struct LiveAskPluriClient: AskPluriClient {
    private let client: SupabaseClient
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "AskPluriClient")

    init(client: SupabaseClient) {
        self.client = client
    }

    @MainActor
    init(supabaseService: SupabaseService) {
        self.init(client: supabaseService.client)
    }

    func ask(_ request: AskPluriRequest) async throws -> AskPluriResponse {
        let trimmed = request.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AskPluriClientError.invalidResponse
        }

        let body = AskPluriRequest(
            message: trimmed,
            conversationId: request.conversationId,
            currentPlanWorkoutId: request.currentPlanWorkoutId
        )

        do {
            let response: AskPluriResponse = try await client.functions.invoke(
                "ask-pluri",
                options: FunctionInvokeOptions(body: body)
            )
            return response
        } catch let error as FunctionsError {
            throw Self.mapFunctionsError(error)
        } catch let error as DecodingError {
            logger.error("ask-pluri decoding failed: \(String(describing: error))")
            throw AskPluriClientError.invalidResponse
        } catch {
            logger.error("ask-pluri transport failed: \(error.localizedDescription)")
            throw AskPluriClientError.transport(error.localizedDescription)
        }
    }

    /// Maps Supabase Functions HTTP failures to typed coach errors.
    static func mapFunctionsError(_ error: FunctionsError) -> AskPluriClientError {
        switch error {
        case .relayError:
            return .transport("We couldn't reach your coach. Please try again.")
        case let .httpError(code, data):
            return mapHTTPError(statusCode: code, data: data)
        }
    }

    /// Maps non-2xx `ask-pluri` bodies (`busy` / `throttled`) without leaking
    /// raw upstream Gemini payloads.
    static func mapHTTPError(statusCode: Int, data: Data) -> AskPluriClientError {
        if statusCode == 401 {
            return .unauthorized
        }

        if let body = try? JSONDecoder().decode(AskPluriErrorBody.self, from: data) {
            switch body.error {
            case .busy:
                return .busy(body.message)
            case .throttled:
                return .throttled(body.message)
            }
        }

        switch statusCode {
        case 429:
            return .throttled(AskPluriClientError.defaultThrottledMessage)
        case 502, 503:
            return .busy(AskPluriClientError.defaultBusyMessage)
        default:
            return .invalidResponse
        }
    }
}
