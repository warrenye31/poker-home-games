import Foundation

/// One unsettled transfer involving the player this device has claimed.
struct OutstandingDebt: Identifiable {
    let group: GameGroup
    let session: Session
    let counterparty: Player
    let amount: Decimal
    /// `true` when you pay `counterparty`; `false` when they pay you.
    let youOwe: Bool
    /// Carried through from `Transfer.note` — in a bank game you appear opposite
    /// the bank twice, and "Buy-in" vs "Cash-out" is the only thing telling the
    /// two rows apart.
    let note: String?

    /// Stable across renders: a session has at most one transfer per direction
    /// per pair. Built from the models' `id`s rather than `persistentModelID`,
    /// which is reassigned on first save — see `GameGroup.id`.
    var id: String { "\(session.id)-\(counterparty.id)-\(youOwe)" }

    /// Signed for `MoneyText(role: .net)`: money leaving you reads as negative
    /// and renders red, money coming to you reads positive.
    var signedAmount: Decimal { youOwe ? -amount : amount }
}

/// Collects who still owes whom, across every group, for the player you've
/// claimed on this device.
enum DebtInbox {
    /// Every unsettled transfer involving you, newest session first.
    ///
    /// Recomputes settlements rather than reading the `SettlementPayment` table,
    /// because those rows are created lazily — `SettlementView` only inserts them
    /// when someone actually opens that screen. A session that was finished but
    /// whose settlement was never opened therefore has *no* payment rows at all,
    /// and querying the table directly would silently omit exactly the debts
    /// nobody has looked at yet — the ones most worth reminding about.
    ///
    /// Deliberately read-only: unlike `SettlementView.payment(for:)` this never
    /// inserts a `SettlementPayment`. A list that quietly writes to the store
    /// every time it renders would be a nasty surprise, and rows created here
    /// would race the ones that screen makes.
    static func outstanding(in groups: [GameGroup]) -> [OutstandingDebt] {
        var debts: [OutstandingDebt] = []

        for group in groups {
            // No claim means there's no way to know which player is you, so the
            // group simply can't contribute — same rule as the Me tab.
            guard
                let claimedID = PlayerClaimStore.validClaimedPlayerID(for: group),
                let you = group.players.first(where: { $0.id == claimedID })
            else { continue }

            for session in group.sessions where session.status == .completed {
                for transfer in SettlementCalculator.calculate(session: session) {
                    let youPay = transfer.from.id == you.id
                    let youReceive = transfer.to.id == you.id
                    guard youPay || youReceive else { continue }
                    guard !isPaid(transfer, in: session) else { continue }

                    debts.append(
                        OutstandingDebt(
                            group: group,
                            session: session,
                            counterparty: youPay ? transfer.to : transfer.from,
                            amount: transfer.amount,
                            youOwe: youPay,
                            note: transfer.note
                        )
                    )
                }
            }
        }

        return debts.sorted { $0.session.date > $1.session.date }
    }

    /// A transfer with no `SettlementPayment` row counts as unpaid — the row's
    /// absence means nobody has opened the settlement, not that it's settled.
    private static func isPaid(_ transfer: Transfer, in session: Session) -> Bool {
        session.settlementPayments.first {
            $0.fromPlayer?.id == transfer.from.id && $0.toPlayer?.id == transfer.to.id
        }?.isPaid ?? false
    }
}
