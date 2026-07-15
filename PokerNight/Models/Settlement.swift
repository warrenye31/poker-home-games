import Foundation
import SwiftData

struct Transfer: Identifiable {
    let from: Player
    let to: Player
    let amount: Decimal
    /// Why this movement exists, when the two names don't say it on their own.
    /// Bank sessions emit two transfers per player in opposite directions
    /// ("Buy-in", then "Cash-out"), which is unreadable without it. `nil` for
    /// ordinary player-to-player settle-ups, where "A pays B" is the whole story.
    var note: String?

    /// Built from the players' stable `id`s rather than `persistentModelID`,
    /// which SwiftData reassigns when a newly-inserted model is first saved —
    /// that would silently change a Transfer's identity mid-list. See `GameGroup.id`.
    ///
    /// Direction is part of the identity, which is what keeps a bank session's
    /// buy-in (`player->bank`) and cash-out (`bank->player`) distinct.
    var id: String {
        "\(from.id)->\(to.id)"
    }
}

enum SettlementCalculator {
    static func calculate(session: Session) -> [Transfer] {
        if session.usesBank, let bank = session.bankPlayer {
            return bankSettlement(session: session, bank: bank)
        }
        return simplifyDebts(session: session)
    }

    /// Bank ("house") settlement, gross rather than netted.
    ///
    /// The bank physically holds the money: every player buys chips from it and
    /// cashes chips back to it, so the real flow is two movements per player —
    /// buy-in in, cash-out back — regardless of who won.
    ///
    /// This used to net each player to a single transfer (`entry.net`), which
    /// misrepresented the bank in two ways. A player who cashed out exactly what
    /// they bought in netted zero and produced **no transaction at all**, even
    /// though they'd handed real cash to the bank at the start and were still
    /// owed it back. And the bank's actual exposure vanished: a bank holding
    /// $800 of buy-ins appeared to be settling $120 of swings.
    ///
    /// Buy-ins are listed before cash-outs, mirroring the order they happen in.
    /// The bank's own entry is skipped — it would only ever pay itself.
    private static func bankSettlement(session: Session, bank: Player) -> [Transfer] {
        let others = session.entries.filter { $0.player?.id != bank.id }

        let buyIns = others.compactMap { entry -> Transfer? in
            guard let player = entry.player, entry.totalBuyIn > 0 else { return nil }
            return Transfer(from: player, to: bank, amount: entry.totalBuyIn, note: "Buy-in")
        }

        let cashOuts = others.compactMap { entry -> Transfer? in
            guard let player = entry.player, let cashOut = entry.cashOut, cashOut > 0 else { return nil }
            return Transfer(from: bank, to: player, amount: cashOut, note: "Cash-out")
        }

        return buyIns + cashOuts
    }

    private static func simplifyDebts(session: Session) -> [Transfer] {
        var creditors: [(player: Player, amount: Decimal)] = []
        var debtors: [(player: Player, amount: Decimal)] = []

        for entry in session.entries {
            guard let player = entry.player, entry.net != 0 else { continue }
            if entry.net > 0 {
                creditors.append((player, entry.net))
            } else {
                debtors.append((player, -entry.net))
            }
        }

        creditors.sort { $0.amount > $1.amount }
        debtors.sort { $0.amount > $1.amount }

        var transfers: [Transfer] = []
        var i = 0
        var j = 0
        while i < debtors.count && j < creditors.count {
            let amount = min(debtors[i].amount, creditors[j].amount)
            transfers.append(Transfer(from: debtors[i].player, to: creditors[j].player, amount: amount))
            debtors[i].amount -= amount
            creditors[j].amount -= amount
            if debtors[i].amount == 0 { i += 1 }
            if creditors[j].amount == 0 { j += 1 }
        }
        return transfers
    }
}
