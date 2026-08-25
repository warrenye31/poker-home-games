import Foundation
import SwiftData

enum SessionStatus: String, Codable {
    case active, completed
}

@Model
final class Session {
    /// Stable, cross-device identity. See `GameGroup.id` for why this isn't
    /// marked `.unique`.
    var id: UUID = UUID()
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
        date: Date = .now,
        location: String? = nil,
        usesBank: Bool = false,
        bankPlayer: Player? = nil,
        smallBlind: Decimal? = nil,
        bigBlind: Decimal? = nil,
        standardBuyIn: Decimal = 20,
        id: UUID = UUID()
    ) {
        self.id = id
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
        date.formatted(date: .abbreviated, time: .omitted)
    }

    /// `entries` in the order players sat down — the order every list of them
    /// should render in.
    ///
    /// `entries` is a SwiftData to-many relationship, and those carry no order
    /// guarantee: rendering one straight into a `ForEach` lets rows swap places
    /// between renders. That isn't only cosmetic. The live session's buy-in
    /// button and the end-session cash-out fields are positional, so a row that
    /// moves out from under a finger books a rebuy or a final stack against the
    /// wrong player. `SettlementCalculator` sorts before it emits transfers for
    /// the same reason.
    ///
    /// An entry with no buy-ins yet sorts last; the stable `id` breaks exact
    /// ties, so two players seated in the same instant can't trade places.
    var seatedEntries: [SessionEntry] {
        entries.sorted { lhs, rhs in
            switch (lhs.seatedAt, rhs.seatedAt) {
            case let (left?, right?) where left != right:
                return left < right
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            default:
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }
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
