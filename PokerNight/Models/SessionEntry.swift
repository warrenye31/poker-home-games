import Foundation
import SwiftData

@Model
final class SessionEntry {
    /// Stable, cross-device identity. See `GameGroup.id` for why this isn't
    /// marked `.unique`.
    var id: UUID = UUID()
    var session: Session?
    var player: Player?
    var cashOut: Decimal?

    @Relationship(deleteRule: .cascade, inverse: \BuyIn.entry)
    var buyIns: [BuyIn] = []

    init(player: Player, id: UUID = UUID()) {
        self.id = id
        self.player = player
    }

    var totalBuyIn: Decimal {
        buyIns.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var net: Decimal {
        (cashOut ?? 0) - totalBuyIn
    }

    /// When this player sat down, taken as the first buy-in they were handed.
    /// Everyone gets one as the session is created and a latecomer gets theirs
    /// when they're seated, so this reads as arrival order. `nil` only for an
    /// entry with no buy-ins at all. See `Session.seatedEntries`.
    var seatedAt: Date? {
        buyIns.map(\.timestamp).min()
    }
}
