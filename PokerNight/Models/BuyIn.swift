import Foundation
import SwiftData

@Model
final class BuyIn {
    var entry: SessionEntry?
    var amount: Decimal
    var timestamp: Date

    init(amount: Decimal, timestamp: Date = .now) {
        self.amount = amount
        self.timestamp = timestamp
    }
}
