import Foundation
import Supabase
import os.log

/// Thin wrapper around the Supabase client (PLAN §1.1 services).
/// Owns client construction from `Secrets` and exposes a health check used by
/// the M0 gallery to confirm connectivity.
@MainActor
@Observable
final class SupabaseService {
    enum HealthStatus: Equatable {
        case unknown
        case checking
        case reachable
        case unreachable(String)
    }

    private(set) var healthStatus: HealthStatus = .unknown

    let client: SupabaseClient

    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "SupabaseService")

    init() {
        client = SupabaseClient(
            supabaseURL: Secrets.supabaseURL,
            supabaseKey: Secrets.supabaseAnonKey
        )
    }

    /// Confirms the Supabase project is reachable by querying the `profiles`
    /// table anonymously. RLS returns zero rows without error when reachable;
    /// network/config failures surface as errors.
    func checkHealth() async {
        healthStatus = .checking
        do {
            _ = try await client.from("profiles").select("id").limit(1).execute()
            healthStatus = .reachable
            logger.info("Supabase health check passed")
        } catch {
            healthStatus = .unreachable(error.localizedDescription)
            logger.error("Supabase health check failed: \(error.localizedDescription)")
        }
    }
}
