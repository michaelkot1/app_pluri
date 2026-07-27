import Foundation
import Testing
@testable import Pluri

@Suite("Ask Pluri client")
struct AskPluriClientTests {

    // MARK: - JSON decoding (M6-03 contract)

    @Test("Decodes success reply, actions, and messageIds")
    func decodesSuccessWithActionsAndMessageIds() throws {
        let json = """
        {
          "reply": "Swap tomorrow's pull for an extra rest day.",
          "conversationId": "11111111-1111-4111-8111-111111111111",
          "actions": [
            {
              "type": "add_workout",
              "sourceWorkoutId": "22222222-2222-4222-8222-222222222222",
              "date": "2026-07-28"
            },
            {
              "type": "remove_workout",
              "planWorkoutId": "33333333-3333-4333-8333-333333333333"
            }
          ],
          "messageIds": {
            "user": "44444444-4444-4444-8444-444444444444",
            "assistant": "55555555-5555-4555-8555-555555555555"
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AskPluriResponse.self, from: json)

        #expect(response.reply == "Swap tomorrow's pull for an extra rest day.")
        #expect(response.conversationId == "11111111-1111-4111-8111-111111111111")
        #expect(response.actions.count == 2)
        #expect(
            response.actions[0] == .addWorkout(
                sourceWorkoutId: "22222222-2222-4222-8222-222222222222",
                date: "2026-07-28"
            )
        )
        #expect(
            response.actions[1] == .removeWorkout(
                planWorkoutId: "33333333-3333-4333-8333-333333333333"
            )
        )
        #expect(response.messageIds?.user == "44444444-4444-4444-8444-444444444444")
        #expect(response.messageIds?.assistant == "55555555-5555-4555-8555-555555555555")
    }

    @Test("Decodes success when actions and messageIds are omitted")
    func decodesSuccessWithDefaults() throws {
        let json = """
        {
          "reply": "Keep breathing steady.",
          "conversationId": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AskPluriResponse.self, from: json)
        #expect(response.actions.isEmpty)
        #expect(response.messageIds == nil)
    }

    @Test("Maps busy and throttled HTTP error bodies")
    func mapsBusyAndThrottledErrors() throws {
        let busyJSON = """
        {"error":"busy","message":"Your coach is busy — try again shortly."}
        """.data(using: .utf8)!
        let throttledJSON = """
        {"error":"throttled","message":"Your coach is busy — try again shortly."}
        """.data(using: .utf8)!

        let busy = LiveAskPluriClient.mapHTTPError(statusCode: 503, data: busyJSON)
        let throttled = LiveAskPluriClient.mapHTTPError(statusCode: 429, data: throttledJSON)
        let unauthorized = LiveAskPluriClient.mapHTTPError(statusCode: 401, data: Data())

        #expect(busy == .busy("Your coach is busy — try again shortly."))
        #expect(throttled == .throttled("Your coach is busy — try again shortly."))
        #expect(unauthorized == .unauthorized)

        let busyBody = try JSONDecoder().decode(AskPluriErrorBody.self, from: busyJSON)
        #expect(busyBody.error == .busy)
        let throttledBody = try JSONDecoder().decode(AskPluriErrorBody.self, from: throttledJSON)
        #expect(throttledBody.error == .throttled)
    }

    // MARK: - Mock path

    @Test("MockAskPluriClient returns fixture reply and records request")
    func mockReturnsFixture() async throws {
        let client = MockAskPluriClient()
        let request = AskPluriRequest(
            message: "How many reps?",
            conversationId: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
            currentPlanWorkoutId: "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
        )

        let response = try await client.ask(request)

        #expect(client.lastRequest == request)
        #expect(response.reply == AskPluriResponse.previewFixture.reply)
        #expect(response.conversationId == "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        #expect(response.actions.isEmpty)
    }

    @Test("MockAskPluriClient surfaces typed busy error")
    func mockThrowsBusy() async {
        let client = MockAskPluriClient(
            errorToThrow: .busy(AskPluriClientError.defaultBusyMessage)
        )

        do {
            _ = try await client.ask(AskPluriRequest(message: "hi"))
            Issue.record("Expected busy error")
        } catch let error as AskPluriClientError {
            #expect(error == .busy(AskPluriClientError.defaultBusyMessage))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - No Gemini key in client

    @Test("Secrets and Ask Pluri client sources never embed GEMINI_API_KEY")
    func noGeminiKeyInClientOrSecrets() throws {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let projectRoot = testsDir.deletingLastPathComponent()

        let paths = [
            projectRoot.appending(path: "Pluri/Core/Secrets.swift"),
            projectRoot.appending(path: "Pluri/Core/Networking/AskPluri/AskPluriClient.swift"),
            projectRoot.appending(path: "Pluri/Core/Networking/AskPluri/AskPluriClientError.swift"),
            projectRoot.appending(path: "Pluri/Core/Networking/AskPluri/LiveAskPluriClient.swift"),
            projectRoot.appending(path: "Pluri/Core/Networking/AskPluri/MockAskPluriClient.swift"),
            projectRoot.appending(path: "Config/Info.plist"),
        ]

        for path in paths {
            let source = try String(contentsOf: path, encoding: .utf8)
            #expect(
                !source.contains("GEMINI_API_KEY"),
                "\(path.lastPathComponent) must not embed GEMINI_API_KEY"
            )
            #expect(
                !source.contains("GEMINI_MODEL"),
                "\(path.lastPathComponent) must not embed GEMINI_MODEL"
            )
        }

        // Runtime Info.plist should only carry client-safe keys.
        #expect(Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") == nil)
        #expect(Bundle.main.object(forInfoDictionaryKey: "GEMINI_MODEL") == nil)
    }
}
