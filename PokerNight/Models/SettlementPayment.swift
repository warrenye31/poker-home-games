import Foundation
import SwiftData

@Model
final class SettlementPayment {
    /// Stable, cross-device identity — payments sync to viewers so their Inbox
    /// can see what's been paid. See `GameGroup.id` for why this isn't marked
    /// `.unique`, and `SharedModelContainer` for the one-time backfill.
    var id: UUID = UUID()
    var session: Session?
    var fromPlayer: Player?
    var toPlayer: Player?
    var amount: Decimal = 0
    var isPaid: Bool = false

    init(session: Session, fromPlayer: Player, toPlayer: Player, amount: Decimal, id: UUID = UUID()) {
        self.id = id
        self.session = session
        self.fromPlayer = fromPlayer
        self.toPlayer = toPlayer
        self.amount = amount
    }

    /// Whether this record is the paid-checkmark for `transfer`. Matched on the
    /// players' stable ids, never object identity: a viewer's copies come from
    /// a pull and are different instances every time.
    func matches(_ transfer: Transfer) -> Bool {
        fromPlayer?.id == transfer.from.id && toPlayer?.id == transfer.to.id
    }

    /// Brings a session's payment records in line with its current settlement:
    /// one record per transfer, carrying that transfer's amount.
    ///
    /// Settlements move when a finished session is edited — a cash-out fixed,
    /// the bank switched on — and records from the old settlement would
    /// otherwise linger. A record whose pair no longer settles is deleted. A
    /// record whose amount changed is un-ticked: "paid $40" says nothing about
    /// whether the new $55 has been paid. Missing records are created, so the
    /// settlement screen never has to insert while it's being drawn.
    ///
    /// Returns whether anything changed, so the caller knows to sync.
    @discardableResult
    static func reconcile(session: Session, transfers: [Transfer], context: ModelContext) -> Bool {
        var changed = false
        var kept: Set<UUID> = []

        for transfer in transfers {
            if let existing = session.settlementPayments.first(where: { $0.matches(transfer) && !kept.contains($0.id) }) {
                kept.insert(existing.id)
                if existing.amount != transfer.amount {
                    existing.amount = transfer.amount
                    existing.isPaid = false
                    changed = true
                }
            } else {
                let created = SettlementPayment(
                    session: session,
                    fromPlayer: transfer.from,
                    toPlayer: transfer.to,
                    amount: transfer.amount
                )
                context.insert(created)
                kept.insert(created.id)
                changed = true
            }
        }

        for stale in session.settlementPayments where !kept.contains(stale.id) {
            context.delete(stale)
            changed = true
        }
        return changed
    }
}
