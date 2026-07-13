import Foundation

/// Build-time injected secrets.
///
/// Values flow: `.env` → `Scripts/generate_secrets.sh` → `Config/Secrets.xcconfig`
/// → Info.plist (`Config/Info.plist` merged into the generated plist) → here.
///
/// Only client-safe keys ever reach the bundle (Supabase URL + publishable key,
/// WorkoutX, Nutrition). Gemini and Supabase service-role keys are server-side
/// only — see AGENTS.md §2.
enum Secrets {
    static var supabaseURL: URL {
        url(for: "SUPABASE_URL")
    }

    static var supabasePublishableKey: String {
        value(for: "SUPABASE_PUBLISHABLE_KEY")
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
