import Foundation
import SwiftData

enum SessionStatus: String, Codable {
    case active, completed
}

@Model
final class Session {
    var date: Date
    var location: String?
    var group: GameGroup?
    var usesBank: Bool
    var bankPlayer: Player?
    private var statusRaw: String

    @Relationship(deleteRule: .cascade, inverse: \SessionEntry.session)
    var entries: [SessionEntry] = []

    init(date: Date = .now, location: String? = nil, usesBank: Bool = false, bankPlayer: Player? = nil) {
        self.date = date
        self.location = location
        self.usesBank = usesBank
        self.bankPlayer = bankPlayer
        self.statusRaw = SessionStatus.active.rawValue
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var totalBuyIns: Decimal {
        entries.reduce(Decimal(0)) { $0 + $1.totalBuyIn }
    }

    var totalCashOuts: Decimal {
        entries.reduce(Decimal(0)) { $0 + ($1.cashOut ?? 0) }
    }

    var isBalanced: Bool {
        entries.allSatisfy { $0.cashOut != nil } && totalBuyIns == totalCashOuts
    }
}
