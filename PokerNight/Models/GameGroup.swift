import Foundation
import SwiftData

/// Whether *this device* is the owner of a group (can edit) or just a viewer
/// who joined via a share code (read-only). This is never synced itself — each
/// device decides its own role for its local copy of the group.
enum GroupRole: String, Codable {
    case admin
    case viewer
}

@Model
final class GameGroup {
    /// Stable, cross-device identity used for all server sync and the claim
    /// feature. Never use `persistentModelID` for those — it is local-only.
    /// Not marked `.unique` at the SwiftData layer so the lightweight migration
    /// that adds this column to existing stores can't crash on a duplicate
    /// default; uniqueness is guaranteed by `UUID()` in the initializer, the
    /// one-time backfill in `SharedModelContainer`, and the Postgres primary key.
    var id: UUID = UUID()
    var name: String = ""
    var createdDate: Date = Date.now

    // Sharing/sync state (Phase 2). All local-only flags describing this
    // device's relationship to the group — never written to Supabase.
    private var roleRaw: String = GroupRole.admin.rawValue
    var isShared: Bool = false
    var joinCode: String?
    var lastSyncedAt: Date?

    /// The player who is the actual group creator, as designated by the
    /// admin device. Unlike the fields above, this IS synced (`admin_player_id`
    /// on the server) so every viewer sees the same value — it's the one
    /// identity that must never be claimable by anyone else. Only the admin
    /// device can change it; that's enforced the same way as any other write
    /// to this row (RLS: `admin_id = auth.uid()`).
    var adminPlayerID: UUID?

    @Relationship(deleteRule: .cascade, inverse: \Player.group)
    var players: [Player] = []

    @Relationship(deleteRule: .cascade, inverse: \Session.group)
    var sessions: [Session] = []

    init(name: String, createdDate: Date = .now, id: UUID = UUID(), role: GroupRole = .admin) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.roleRaw = role.rawValue
    }

    var role: GroupRole {
        get { GroupRole(rawValue: roleRaw) ?? .admin }
        set { roleRaw = newValue.rawValue }
    }

    /// Only the admin device may create/edit players, sessions, and entries.
    /// Viewer devices render everything read-only.
    var canEdit: Bool { role == .admin }

    /// Whether this device may hand out the join code.
    ///
    /// The organizer has to say which player they are first. `adminPlayerID` is
    /// what every viewer reads to know which seat is reserved, so a group shared
    /// before it's set publishes a roster where the host's own identity is up
    /// for grabs — the first viewer to open it could claim to be the host.
    var canShare: Bool { role == .admin && adminPlayerID != nil }

    /// Whether this device may still change which player it claims.
    ///
    /// Viewers can always re-pick — their claim is local and affects nobody.
    /// The organizer is pinned the moment the group is shared: viewers have
    /// already synced `admin_player_id` and may have claimed seats around it,
    /// so moving it afterwards would silently reassign who the host is on every
    /// other device and could free up a seat someone else already took.
    var canChangeClaimedPlayer: Bool { role == .viewer || !isShared }
}
