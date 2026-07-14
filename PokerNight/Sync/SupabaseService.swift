import Foundation
import Supabase

/// Owns the single `SupabaseClient` for the app and the invisible anonymous
/// auth session. There is no sign-up UI: every device silently gets a stable
/// `auth.uid()` via `signInAnonymously()`, which is what group `admin_id`
/// checks and RLS policies key on.
///
/// The service is a no-op when `SupabaseConfig` is absent (e.g. a checkout
/// without the secrets plist), so the app keeps working fully local-only.
@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    /// The configured client, or `nil` when Supabase isn't set up. Callers must
    /// treat `nil` as "sync disabled, local-only".
    let client: SupabaseClient?

    /// Whether Supabase is configured at all (secrets present).
    var isConfigured: Bool { client != nil }

    /// Guards against kicking off several concurrent anonymous sign-ins.
    private var signInTask: Task<UUID, Error>?

    private init() {
        if let config = SupabaseConfig.shared {
            client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
        } else {
            client = nil
        }
    }

    /// The current device's stable auth user id, if a session already exists.
    var currentUserID: UUID? {
        client?.auth.currentUser?.id
    }

    /// Ensures there is an anonymous session and returns this device's stable
    /// `auth.uid()`. Safe to call repeatedly; reuses the existing session and
    /// coalesces concurrent callers. Throws `SupabaseError.notConfigured` when
    /// Supabase isn't set up, and rethrows network/auth errors (including the
    /// free-tier cold-start failure) so callers can show a retry state.
    @discardableResult
    func ensureSignedIn() async throws -> UUID {
        guard let client else { throw SupabaseError.notConfigured }

        // Fast path: a valid session already exists.
        if let existing = try? await client.auth.session {
            return existing.user.id
        }

        if let signInTask {
            return try await signInTask.value
        }

        let task = Task<UUID, Error> {
            let session = try await client.auth.signInAnonymously()
            return session.user.id
        }
        signInTask = task
        defer { signInTask = nil }
        return try await task.value
    }
}

enum SupabaseError: LocalizedError {
    /// Supabase secrets are missing — the app is running local-only.
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Sharing isn't configured on this build."
        }
    }
}
