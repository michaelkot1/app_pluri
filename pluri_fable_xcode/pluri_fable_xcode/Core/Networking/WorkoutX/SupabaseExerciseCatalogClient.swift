import Foundation
import Supabase
import os.log

/// `WorkoutXClient` backed by the Supabase `public.exercises` table — the
/// seeded 1:1 snapshot of the WorkoutX catalog.
///
/// This is the app's **primary catalog source** (SPEC §14 decision #25): the
/// live WorkoutX API's free tier caps every `/exercises` response at 10 rows
/// regardless of `limit`, so a full catalog fetch needs ~133 requests and
/// slams into the 30-requests/window burst limit (429) before finishing —
/// besides burning a quarter of the 500/month quota per attempt. The Supabase
/// snapshot serves all 1,327 rows in a handful of free reads instead. Reads
/// use the anon key under an anon SELECT RLS policy (catalog data is public,
/// non-sensitive reference data, and onboarding runs before auth — SPEC §2).
struct SupabaseExerciseCatalogClient: WorkoutXClient {
    /// One shared client for catalog reads, so repeated generation attempts
    /// don't each spin up a fresh Supabase stack.
    private static let sharedClient = SupabaseClient(
        supabaseURL: Secrets.supabaseURL,
        supabaseKey: Secrets.supabasePublishableKey
    )

    private let client: SupabaseClient
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "SupabaseExerciseCatalogClient")

    init(client: SupabaseClient = SupabaseExerciseCatalogClient.sharedClient) {
        self.client = client
    }

    func fetchExercises(limit: Int, offset: Int) async throws -> WorkoutXExercisePage {
        let response: PostgrestResponse<[SupabaseExerciseRow]> = try await client
            .from("exercises")
            .select(SupabaseExerciseRow.selectedColumns, count: .exact)
            .order("id")
            .range(from: offset, to: offset + limit - 1)
            .execute()

        let exercises = response.value.map(\.asDomainExercise)
        // `count: .exact` always populates the total for a range query; the
        // page length is a safe floor if PostgREST ever omits it.
        let total = response.count ?? exercises.count
        return WorkoutXExercisePage(exercises: exercises, total: total)
    }

    func fetchExercise(id: String) async throws -> Exercise {
        let rows: [SupabaseExerciseRow] = try await client
            .from("exercises")
            .select(SupabaseExerciseRow.selectedColumns)
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else {
            throw WorkoutXClientError.notFound
        }
        return row.asDomainExercise
    }
}
