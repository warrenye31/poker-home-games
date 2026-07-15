import Foundation

/// Wire types mirroring the Supabase tables in `supabase/migrations/0001_init.sql`.
///
/// Every type spells its column names out in `CodingKeys`. This is deliberate:
/// supabase-swift does *not* convert camelCase <-> snake_case. Its default
/// encoder/decoder (`JSONEncoder.supabase()`) only set a `dateEncodingStrategy`
/// and leave `keyEncodingStrategy` at `.useDefaultKeys`, so a property named
/// `adminId` goes out on the wire as `"adminId"` and PostgREST rejects the
/// request with `PGRST204: Could not find the 'adminId' column`. Column names
/// are the API contract here, so they're written literally rather than derived.

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

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdDate = "created_date"
        case adminId = "admin_id"
        case joinCode = "join_code"
        case adminPlayerId = "admin_player_id"
    }
}

/// Insert/upsert payload for a group.
///
/// Two columns are deliberately absent, for different reasons:
///
/// - `join_code` has a NOT NULL default (`generate_join_code()`). Codable would
///   serialize a `nil` as an explicit JSON `null`, overriding the default and
///   violating the constraint. Omitting the key lets Postgres fill it in on
///   first insert and leaves it untouched on later upserts (PostgREST only
///   updates columns present in the request body).
/// - `admin_player_id` is a foreign key to `players`, but `players.group_id` is
///   a foreign key back to `groups` — the two tables are mutually dependent, so
///   neither can be written complete first. The group row has to exist before
///   its players can, which means the group's *first* write cannot yet name a
///   player. It's set afterwards via `RemoteGroupAdminPlayerUpdate`.
struct RemoteGroupUpsert: Encodable {
    var id: UUID
    var name: String
    var createdDate: Date
    var adminId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdDate = "created_date"
        case adminId = "admin_id"
    }
}

/// Second-pass payload writing `groups.admin_player_id` once the roster exists.
///
/// Split out from `RemoteGroupUpsert` because of the circular FK described
/// above: sending this with the group's own insert fails with
/// `23503 groups_admin_player_id_fkey`, since the player it points at hasn't
/// been pushed yet. An explicit `nil` is meaningful here — it clears the
/// reservation — so unlike `joinCode` this field is always encoded.
struct RemoteGroupAdminPlayerUpdate: Encodable {
    var adminPlayerId: UUID?

    enum CodingKeys: String, CodingKey {
        case adminPlayerId = "admin_player_id"
    }
}

struct RemotePlayer: Codable {
    var id: UUID
    var groupId: UUID
    var name: String

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case name
    }
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

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case date
        case location
        case usesBank = "uses_bank"
        case bankPlayerId = "bank_player_id"
        case smallBlind = "small_blind"
        case bigBlind = "big_blind"
        case standardBuyIn = "standard_buy_in"
        case status
    }
}

struct RemoteSessionEntry: Codable {
    var id: UUID
    var groupId: UUID
    var sessionId: UUID
    var playerId: UUID
    var totalBuyIn: Decimal
    var cashOut: Decimal?

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case sessionId = "session_id"
        case playerId = "player_id"
        case totalBuyIn = "total_buy_in"
        case cashOut = "cash_out"
    }
}

/// Param payload for the `join_group_with_code` RPC. The key must match the SQL
/// function's argument name (`p_code`) exactly — see the note above on why it
/// can't be derived from the property name.
struct JoinGroupParams: Encodable {
    var pCode: String

    enum CodingKeys: String, CodingKey {
        case pCode = "p_code"
    }
}
