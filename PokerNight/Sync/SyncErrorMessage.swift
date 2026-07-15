import Foundation
import Supabase

/// Maps a sync failure to a user-facing message.
///
/// The important distinction here is **"couldn't reach the server"** vs **"the
/// server answered, and said no"**. Both sharing sheets used to collapse every
/// failure into the former, so a schema mismatch (`PGRST204`) and an RLS
/// rejection (`42501`) each spent their entire lifetime disguised as "check
/// your connection" — advice that could never have worked, on a request that
/// never had a connection problem. A reachable server that rejects a request is
/// a bug, and saying so is more useful than suggesting the user try again.
enum SyncErrorMessage {
    enum Action {
        case share
        case join
    }

    /// SQLSTATE raised by `join_group_with_code` when no group matches the code
    /// (`raise exception ... using errcode = 'no_data_found'`). This is a normal
    /// user typo, not a fault — it's the one PostgREST error worth phrasing as
    /// an ordinary outcome.
    private static let noGroupForCode = "P0002"

    static func text(for error: Error, action: Action) -> String {
        #if DEBUG
        return "\(message(for: error, action: action))\n\n[debug] \(diagnostic(for: error))"
        #else
        return message(for: error, action: action)
        #endif
    }

    private static func message(for error: Error, action: Action) -> String {
        if error is SupabaseError {
            return "Sharing isn't configured on this build."
        }

        // The server replied. Whatever went wrong, it isn't the network.
        if let postgrest = error as? PostgrestError {
            if postgrest.code == noGroupForCode {
                return "No group found for that code. Double-check the code and try again."
            }
            switch action {
            case .share:
                return "The server turned down this group. Retrying won't help — this is a bug worth reporting."
            case .join:
                return "The server turned down that code. Retrying won't help — this is a bug worth reporting."
            }
        }

        if isConnectivity(error) {
            return "Couldn't reach the server. Check your connection and try again — a group that hasn't been opened in a while can take a few extra seconds to wake up."
        }

        return "Something went wrong. Try again in a moment."
    }

    private static func isConnectivity(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut,
             .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
             .internationalRoamingOff, .dataNotAllowed:
            return true
        default:
            return false
        }
    }

    #if DEBUG
    /// The detail that actually identifies the bug, surfaced in-app so a failure
    /// doesn't require attaching a console to diagnose.
    private static func diagnostic(for error: Error) -> String {
        if let postgrest = error as? PostgrestError {
            let code = postgrest.code ?? "—"
            let detail = postgrest.detail.map { " | \($0)" } ?? ""
            let hint = postgrest.hint.map { " | hint: \($0)" } ?? ""
            return "PostgrestError \(code): \(postgrest.message)\(detail)\(hint)"
        }
        if let urlError = error as? URLError {
            return "URLError \(urlError.code.rawValue): \(urlError.localizedDescription)"
        }
        return String(describing: error)
    }
    #endif
}
