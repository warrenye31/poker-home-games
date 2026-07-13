import Foundation
import SwiftData

@Model
final class BuyIn {
    var entry: SessionEntry?
    var amount: Decimal = 0
    var timestamp: Date = Date.now

    init(amount: Decimal, timestamp: Date = .now) {
        self.amount = amount
        self.timestamp = timestamp
    }
}
