import Foundation

/// Loads the Supabase Project URL + anon key from a bundled, gitignored
/// property list (`SupabaseConfig.plist`). Keeping the values in a plist that
/// is not checked into git means the secrets never enter source control while
/// still being available at runtime. See `Config/SupabaseConfig.example.plist`
/// for the template.
///
/// Only the *anon* (public) key belongs here — never the service_role key.
struct SupabaseConfig {
    let url: URL
    let anonKey: String

    /// The config resolved from the bundle, or `nil` when the plist is missing
    /// or contains placeholder/empty values. Sync features check this and stay
    /// disabled (local-only mode) when it is `nil`, so a fresh checkout without
    /// the secrets file still builds and runs.
    static let shared: SupabaseConfig? = load()

    private static func load() -> SupabaseConfig? {
        guard
            let plistURL = Bundle.main.url(forResource: "SupabaseConfig", withExtension: "plist"),
            let data = try? Data(contentsOf: plistURL),
            let raw = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dict = raw as? [String: Any]
        else {
            return nil
        }

        guard
            let urlString = (dict["SupabaseURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            let anonKey = (dict["SupabaseAnonKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !urlString.isEmpty,
            !anonKey.isEmpty,
            !urlString.contains("YOUR-PROJECT-REF"),
            !anonKey.contains("YOUR-ANON"),
            let url = URL(string: urlString)
        else {
            #if DEBUG
            print("[Supabase] SupabaseConfig.plist missing or not filled in — running local-only. See Config/SupabaseConfig.example.plist.")
            #endif
            return nil
        }

        return SupabaseConfig(url: url, anonKey: anonKey)
    }
}
