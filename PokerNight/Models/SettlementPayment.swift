import Foundation
import SwiftData

@Model
final class SettlementPayment {
    var session: Session?
    var fromPlayer: Player?
    var toPlayer: Player?
    var amount: Decimal = 0
    var isPaid: Bool = false

    init(session: Session, fromPlayer: Player, toPlayer: Player, amount: Decimal) {
        self.session = session
        self.fromPlayer = fromPlayer
        self.toPlayer = toPlayer
        self.amount = amount
    }
}
