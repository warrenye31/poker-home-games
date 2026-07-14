import Foundation
import SwiftData

@Model
final class Player {
    /// Stable, cross-device identity. See `GameGroup.id` for why this isn't
    /// marked `.unique`. The claim feature stores this UUID locally.
    var id: UUID = UUID()
    var name: String = ""
    var group: GameGroup?

    @Relationship(inverse: \SessionEntry.player)
    var entries: [SessionEntry] = []

    @Relationship(inverse: \Session.bankPlayer)
    var sessionsAsBank: [Session] = []

    @Relationship(inverse: \SettlementPayment.fromPlayer)
    var paymentsOwed: [SettlementPayment] = []

    @Relationship(inverse: \SettlementPayment.toPlayer)
    var paymentsReceivable: [SettlementPayment] = []

    init(name: String, id: UUID = UUID()) {
        self.id = id
        self.name = name
    }

    var lifetimeNet: Decimal {
        entries
            .filter { $0.session?.status == .completed }
            .reduce(Decimal(0)) { $0 + $1.net }
    }

    var gamesPlayed: Int {
        entries.filter { $0.session?.status == .completed }.count
    }
}

extension Player: Hashable {
    static func == (lhs: Player, rhs: Player) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
