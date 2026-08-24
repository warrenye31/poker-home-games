import Foundation

/// Time window for the leaderboard.
///
/// "Last 10" counts the *group's* last ten completed sessions rather than each
/// player's own last ten — a leaderboard has to compare people over the same
/// stretch of games, or someone who shows up once a month is ranked on a
/// different year than the regulars.
enum LeaderboardRange: String, CaseIterable, Identifiable {
    case allTime
    case thisYear
    case lastTen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .allTime: "All time"
        case .thisYear: "This year"
        case .lastTen: "Last 10"
        }
    }

    /// All-time is the roster view — it lists everyone in the group, including
    /// players who haven't played yet, because that's also the group's member
    /// list. A narrowed window is a record of what actually happened in it, so
    /// someone who sat the window out doesn't belong on it.
    var includesPlayersWithNoGames: Bool {
        self == .allTime
    }

    /// Empty-state wording. Never says "no players" for a narrowed window — the
    /// group may be full of people who simply didn't play in it.
    var emptyDescription: String {
        switch self {
        case .allTime: "Add players to this group to see stats."
        case .thisYear: "No completed sessions this year yet."
        case .lastTen: "No completed sessions yet."
        }
    }
}

/// One player's results inside a single time window.
struct ScopedPlayerStats: Identifiable {
    let player: Player
    let net: Decimal
    let gamesPlayed: Int
    /// `player.id`, not `persistentModelID`: the latter is reassigned when a
    /// newly-inserted model is first saved, which would churn ForEach/Chart
    /// identity mid-render. See `GameGroup.id`.
    var id: UUID { player.id }

    var netValue: Double { NSDecimalNumber(decimal: net).doubleValue }
}

/// Ranks a group's players over a time window.
enum LeaderboardCalculator {
    /// Completed sessions inside the window, newest first.
    ///
    /// Active sessions are excluded everywhere: their entries have no cash-out
    /// yet, so counting one would show every seated player down a full buy-in
    /// until the night ends. This matches `Player.lifetimeNet`.
    static func sessions(in group: GameGroup, range: LeaderboardRange, now: Date = .now) -> [Session] {
        let completed = group.sessions
            .filter { $0.status == .completed }
            .sorted { $0.date > $1.date }

        switch range {
        case .allTime:
            return completed
        case .thisYear:
            return completed.filter {
                Calendar.current.isDate($0.date, equalTo: now, toGranularity: .year)
            }
        case .lastTen:
            return Array(completed.prefix(10))
        }
    }

    /// Players ranked by net over the window, best first.
    static func standings(in group: GameGroup, range: LeaderboardRange, now: Date = .now) -> [ScopedPlayerStats] {
        // All-time reads straight off the player, which keeps the group roster
        // and the leaderboard in agreement and skips building a session set for
        // the overwhelmingly common case.
        if range == .allTime {
            return group.players
                .map { ScopedPlayerStats(player: $0, net: $0.lifetimeNet, gamesPlayed: $0.gamesPlayed) }
                .sorted { $0.net > $1.net }
        }

        let scopedIDs = Set(sessions(in: group, range: range, now: now).map(\.id))
        return group.players
            .map { player in
                let entries = player.entries.filter { entry in
                    guard let id = entry.session?.id else { return false }
                    return scopedIDs.contains(id)
                }
                return ScopedPlayerStats(
                    player: player,
                    net: entries.reduce(Decimal(0)) { $0 + $1.net },
                    gamesPlayed: entries.count
                )
            }
            .filter { range.includesPlayersWithNoGames || $0.gamesPlayed > 0 }
            .sorted { $0.net > $1.net }
    }
}
