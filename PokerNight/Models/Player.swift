import Foundation
import SwiftData

@Model
final class Player {
    var name: String
    var group: GameGroup?

    @Relationship(inverse: \SessionEntry.player)
    var entries: [SessionEntry] = []

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
