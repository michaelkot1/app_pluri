import Foundation
import os.log

/// `URLSession`-backed `WorkoutXClient`, authenticated per the API spike
/// (M1-01): a custom `X-WorkoutX-Key` header, not a bearer token — see
/// `Core/Networking/WorkoutX/README.md`.
struct LiveWorkoutXClient: WorkoutXClient {
    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "WorkoutXClient")

    init(
        session: URLSession = .shared,
        baseURL: URL = Secrets.workoutXEndpoint,
        apiKey: String = Secrets.workoutXAPIKey
    ) {
        self.session = session
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    func fetchExercises(limit: Int, offset: Int) async throws -> WorkoutXExercisePage {
        guard var components = URLComponents(url: baseURL.appending(path: "exercises"), resolvingAgainstBaseURL: false) else {
            throw WorkoutXClientError.invalidRequest
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        guard let url = components.url else {
            throw WorkoutXClientError.invalidRequest
        }
        let envelope: WorkoutXExerciseListEnvelope = try await perform(url: url)
        return WorkoutXExercisePage(exercises: envelope.data.map(\.asDomainExercise), total: envelope.total)
    }

    func fetchExercise(id: String) async throws -> Exercise {
        let url = baseURL.appending(path: "exercises").appending(path: id)
        let dto: WorkoutXExerciseDTO = try await perform(url: url)
        return dto.asDomainExercise
    }

    private func perform<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-WorkoutX-Key")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("WorkoutX request failed: \(error.localizedDescription)")
            throw WorkoutXClientError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkoutXClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 401:
            throw WorkoutXClientError.unauthorized
        case 404:
            throw WorkoutXClientError.notFound
        case 429:
            throw WorkoutXClientError.rateLimited
        default:
            throw WorkoutXClientError.transport("Unexpected status code \(httpResponse.statusCode)")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.error("WorkoutX decoding failed: \(error.localizedDescription)")
            throw WorkoutXClientError.decodingFailed(error.localizedDescription)
        }
    }
}
