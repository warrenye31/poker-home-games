import Foundation
import SwiftData

@Model
final class Player {
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

    init(name: String) {
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
        lhs.persistentModelID == rhs.persistentModelID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(persistentModelID)
    }
}
