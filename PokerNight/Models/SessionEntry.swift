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
}
