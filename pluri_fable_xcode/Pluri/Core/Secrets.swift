import Foundation

/// Build-time injected secrets.
///
/// Values flow: `.env` → `Scripts/generate_secrets.sh` → `Config/Secrets.xcconfig`
/// → Info.plist (`Config/Info.plist` merged into the generated plist) → here.
///
/// Only client-safe keys ever reach the bundle (Supabase URL + anon JWT key,
/// WorkoutX, Nutrition, RevenueCat public Apple SDK key). Gemini and Supabase
/// service-role / secret keys are server-side only — see AGENTS.md §2.
///
/// Prefer `SUPABASE_ANON_KEY` (legacy JWT) for supabase-swift until the SDK
/// fully supports `sb_publishable_…` without placing it in `Authorization: Bearer`.
enum Secrets {
    static var supabaseURL: URL {
        url(for: "SUPABASE_URL")
    }

    /// Legacy JWT anon key (`eyJ…`). Safe to ship; RLS-protected. Used as
    /// `SupabaseClient`'s `supabaseKey`.
    static var supabaseAnonKey: String {
        value(for: "SUPABASE_ANON_KEY")
    }

    static var workoutXAPIKey: String {
        value(for: "WORKOUTX_API_KEY")
    }

    static var workoutXEndpoint: URL {
        url(for: "WORKOUTX_ENDPOINT")
    }

    static var nutritionAPIKey: String {
        value(for: "NUTRITION_API_KEY")
    }

    /// RevenueCat public Apple SDK key (`appl_…`). Safe to ship in the client.
    static var revenueCatAPIKey: String {
        value(for: "REVENUECAT_API_KEY")
    }

    private static func value(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else {
            // Unrecoverable misconfiguration: the app cannot function without its keys,
            // and the build phase should have caught this. Fail loudly.
            fatalError("Missing secret '\(key)'. Run Scripts/generate_secrets.sh and rebuild.")
        }
        return value
    }

    private static func url(for key: String) -> URL {
        guard let url = URL(string: value(for: key)) else {
            fatalError("Secret '\(key)' is not a valid URL.")
        }
        return url
    }
}
