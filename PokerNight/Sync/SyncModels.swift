import Foundation

/// Wire types mirroring the Supabase tables in `supabase/migrations/0001_init.sql`.
/// Field names are camelCase and rely on supabase-swift's default
/// snake_case <-> camelCase key conversion (e.g. `groupId` <-> `group_id`) —
/// no explicit `CodingKeys` needed as long as every property name maps
/// unambiguously to its column name.

/// Full row shape, used when *reading back* a group (e.g. after upsert with
/// `.select()`, or a viewer's pull) — includes the server-assigned `joinCode`.
struct RemoteGroup: Codable {
    var id: UUID
    var name: String
    var createdDate: Date
    var adminId: UUID
    var joinCode: String
    /// The player the group creator has designated as themselves — the one
    /// identity every device must treat as reserved and unclaimable by anyone
    /// else. `nil` until the admin picks one.
    var adminPlayerId: UUID?
}

/// Insert/upsert payload for a group. `joinCode` is deliberately omitted: the
/// column has a NOT NULL default (`generate_join_code()`), and Codable would
/// otherwise serialize a `nil` as an explicit JSON `null`, which overrides the
/// default and violates the constraint. Omitting the key entirely lets
/// Postgres fill it in on first insert and leaves it untouched on later
/// upserts (PostgREST only updates columns present in the request body).
struct RemoteGroupUpsert: Encodable {
    var id: UUID
    var name: String
    var createdDate: Date
    var adminId: UUID
    /// Unlike `joinCode`, `admin_player_id` has no NOT NULL default, so it's
    /// safe to send an explicit `nil` here — it just clears the reservation.
    var adminPlayerId: UUID?
}

struct RemotePlayer: Codable {
    var id: UUID
    var groupId: UUID
    var name: String
}

struct RemoteSession: Codable {
    var id: UUID
    var groupId: UUID
    var date: Date
    var location: String?
    var usesBank: Bool
    var bankPlayerId: UUID?
    var smallBlind: Decimal?
    var bigBlind: Decimal?
    var standardBuyIn: Decimal
    var status: String
}

struct RemoteSessionEntry: Codable {
    var id: UUID
    var groupId: UUID
    var sessionId: UUID
    var playerId: UUID
    var totalBuyIn: Decimal
    var cashOut: Decimal?
}

/// Param payload for the `join_group_with_code` RPC. supabase-swift's default
/// key-encoding converts `pCode` -> `p_code`, matching the SQL function's
/// argument name.
struct JoinGroupParams: Encodable {
    var pCode: String
}
