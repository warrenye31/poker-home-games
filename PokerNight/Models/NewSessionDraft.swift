import Foundation

struct NewSessionDraft: Hashable {
    var date: Date
    var location: String
    var smallBlind: Decimal?
    var bigBlind: Decimal?
    var standardBuyIn: Decimal
    var usesBank: Bool
    var bankPlayer: Player?
    var players: [Player]
}
