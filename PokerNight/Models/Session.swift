import Foundation
import SwiftData

enum SessionStatus: String, Codable {
    case active, completed
}

@Model
final class Session {
    var name: String = ""
    var date: Date = Date.now
    var location: String?
    var group: GameGroup?
    var usesBank: Bool = false
    var bankPlayer: Player?
    var smallBlind: Decimal?
    var bigBlind: Decimal?
    var standardBuyIn: Decimal = 20
    private var statusRaw: String = SessionStatus.active.rawValue

    @Relationship(deleteRule: .cascade, inverse: \SessionEntry.session)
    var entries: [SessionEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \SettlementPayment.session)
    var settlementPayments: [SettlementPayment] = []

    init(
        name: String = "",
        date: Date = .now,
        location: String? = nil,
        usesBank: Bool = false,
        bankPlayer: Player? = nil,
        smallBlind: Decimal? = nil,
        bigBlind: Decimal? = nil,
        standardBuyIn: Decimal = 20
    ) {
        self.name = name
        self.date = date
        self.location = location
        self.usesBank = usesBank
        self.bankPlayer = bankPlayer
        self.smallBlind = smallBlind
        self.bigBlind = bigBlind
        self.standardBuyIn = standardBuyIn
        self.statusRaw = SessionStatus.active.rawValue
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var displayName: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty
            ? date.formatted(date: .abbreviated, time: .omitted)
            : name
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
