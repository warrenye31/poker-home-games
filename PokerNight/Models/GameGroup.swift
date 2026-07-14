import Foundation
import SwiftData

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

    @Relationship(deleteRule: .cascade, inverse: \Player.group)
    var players: [Player] = []

    @Relationship(deleteRule: .cascade, inverse: \Session.group)
    var sessions: [Session] = []

    init(name: String, createdDate: Date = .now, id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
    }
}
