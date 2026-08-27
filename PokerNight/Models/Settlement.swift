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
    /// Biggest table the exact minimiser below will attempt. Its search is
    /// O(2^n · n) in the number of players who finished non-even, so this
    /// ceiling is what stops a pathological session from stalling the
    /// settlement screen — and `DebtInbox`, which re-runs this for *every*
    /// completed session each time the inbox renders. Sixteen is already well
    /// past a real home game (a table seats ten) and costs under a megabyte of
    /// scratch space; anything larger falls back to plain greedy settling,
    /// which is still correct, just not guaranteed minimal.
    private static let exactSolveLimit = 16

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
    /// Buy-ins are listed before cash-outs, mirroring the order they happen in,
    /// and players run in seating order within each half — `seatedEntries` for
    /// the same reason `simplifyDebts` sorts below, since `SettlementView`
    /// matches its paid ticks to rows by payer/payee pair. The bank's own entry
    /// is skipped — it would only ever pay itself.
    private static func bankSettlement(session: Session, bank: Player) -> [Transfer] {
        let others = session.seatedEntries.filter { $0.player?.id != bank.id }

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

    // MARK: - No bank: fewest possible hand-offs

    /// One player's net for the session, as the settle-up math sees them.
    private struct Balance {
        let player: Player
        let amount: Decimal

        /// The one ordering used everywhere below. Biggest swing first, because
        /// that's how people read a payout list; the id is a tiebreak so two
        /// players who lost the same amount can't trade places between renders.
        static func descending(_ lhs: Balance, _ rhs: Balance) -> Bool {
            if lhs.amount != rhs.amount { return lhs.amount > rhs.amount }
            return lhs.player.id.uuidString < rhs.player.id.uuidString
        }
    }

    /// Settles a no-bank session in the fewest hand-offs that exist.
    ///
    /// Two passes. `zeroSumGroups` carves the table into the largest number of
    /// pods that each settle entirely among themselves; then every pod is
    /// drained greedily. A pod of `m` people costs exactly `m - 1` transfers,
    /// so maximising the number of pods *is* minimising the transfers — see
    /// those two functions for why each half holds.
    private static func simplifyDebts(session: Session) -> [Transfer] {
        // The sort isn't cosmetic. `SettlementView` matches its paid-checkmark
        // rows to `SettlementPayment` records by payer/payee pair, so a session
        // that settled two different ways on two renders would strand ticks on
        // rows that no longer exist. `session.entries` is a SwiftData
        // relationship with no guaranteed order, so impose one here and let
        // every later step preserve it.
        let balances = session.entries
            .compactMap { entry -> Balance? in
                guard let player = entry.player, entry.net != 0 else { return nil }
                return Balance(player: player, amount: entry.net)
            }
            .sorted(by: Balance.descending)

        // Pods come back in whatever order the search reconstructed them. Lead
        // with the one holding the biggest single win, so the payout list still
        // reads largest-first the way it always has.
        let pods = zeroSumGroups(in: balances).sorted { lhs, rhs in
            guard let lhsLead = lead(of: lhs), let rhsLead = lead(of: rhs) else { return false }
            return Balance.descending(lhsLead, rhsLead)
        }
        return pods.flatMap(settleWithinGroup)
    }

    /// A pod's biggest winner, which is what the pod is ordered by above.
    /// `Balance.descending` treats "larger amount" as "sorts earlier", so the
    /// element it would put first is the collection's `min` under it.
    private static func lead(of pod: [Balance]) -> Balance? {
        pod.min(by: Balance.descending)
    }

    /// Splits the table into as many self-contained pods as possible — subsets
    /// whose nets cancel out, so nobody in one ever has to pay anybody in
    /// another.
    ///
    /// This is the whole optimisation. The old code went straight to greedy
    /// matching of biggest debtor against biggest creditor, which is *usually*
    /// minimal but not always: with nets of `+6 −5 −1 +2 −2` it pays 5 to the 6
    /// first, and the 1 left over then breaks up the `+2 / −2` pair that could
    /// have settled by itself — four transfers where three suffice.
    ///
    /// The search is a subset DP over orderings. `groupCount[mask]` is the most
    /// pods you can close off using exactly the people in `mask` as the opening
    /// stretch of an ordering: extend by whichever person leaves the best
    /// prefix, and bank a pod every time the running total hits zero. Any
    /// partition into pods can be written as such an ordering (list each pod's
    /// members consecutively) and any such ordering yields a partition, so the
    /// answer for the full set is the largest number of pods there is. Closing
    /// a pod the moment the total reaches zero is never worse than carrying on,
    /// because whatever is left still sums to zero and splits independently.
    private static func zeroSumGroups(in balances: [Balance]) -> [[Balance]] {
        let n = balances.count
        // Under three people there is nothing to split — one pod is already the
        // answer — and past the ceiling we decline to look.
        guard n > 2, n <= exactSolveLimit, let units = wholeUnits(balances.map(\.amount)) else {
            return balances.isEmpty ? [] : [balances]
        }

        let maskCount = 1 << n
        var sums = [Int64](repeating: 0, count: maskCount)
        var groupCount = [Int16](repeating: 0, count: maskCount)
        // Who the best ordering of each subset ends on, so the winning
        // arrangement can be walked back out once the table is filled.
        var lastMember = [Int8](repeating: 0, count: maskCount)

        for mask in 1..<maskCount {
            let lowest = mask & -mask
            sums[mask] = sums[mask ^ lowest] + units[lowest.trailingZeroBitCount]

            var best: Int16 = -1
            var bestMember = 0
            var remaining = mask
            while remaining != 0 {
                let bit = remaining & -remaining
                remaining ^= bit
                let candidate = groupCount[mask ^ bit]
                if candidate > best {
                    best = candidate
                    bestMember = bit.trailingZeroBitCount
                }
            }
            let closesAPod: Int16 = sums[mask] == 0 ? 1 : 0
            groupCount[mask] = best + closesAPod
            lastMember[mask] = Int8(bestMember)
        }

        var order: [Int] = []
        order.reserveCapacity(n)
        var mask = maskCount - 1
        while mask != 0 {
            let member = Int(lastMember[mask])
            order.append(member)
            mask ^= 1 << member
        }
        order.reverse()

        var groups: [[Balance]] = []
        var current: [Balance] = []
        var runningTotal: Int64 = 0
        for member in order {
            current.append(balances[member])
            runningTotal += units[member]
            if runningTotal == 0 {
                groups.append(current)
                current = []
            }
        }
        // Only ever non-empty when the session itself doesn't balance (cash-outs
        // that don't add up to the buy-ins). Those people can't settle cleanly
        // with anyone, so they ride along as one last pod and the greedy pass
        // pairs off as much of them as it can.
        if !current.isEmpty {
            groups.append(current)
        }
        return groups
    }

    /// The payer → payee hand-offs inside one pod, biggest debt first.
    ///
    /// Every step zeroes out at least one person, so a pod of `m` needs at most
    /// `m - 1` transfers. And because `zeroSumGroups` already peeled off every
    /// subset that could have settled on its own, no pod can be done in fewer
    /// than `m - 1` either — which is what makes the total across all pods the
    /// true minimum rather than merely a good showing.
    private static func settleWithinGroup(_ group: [Balance]) -> [Transfer] {
        let creditors = group.filter { $0.amount > 0 }.sorted(by: Balance.descending)
        let debtors = group.filter { $0.amount < 0 }
            .map { Balance(player: $0.player, amount: -$0.amount) }
            .sorted(by: Balance.descending)

        var creditorRemaining = creditors.map(\.amount)
        var debtorRemaining = debtors.map(\.amount)
        var transfers: [Transfer] = []
        var debtorIndex = 0
        var creditorIndex = 0

        while debtorIndex < debtors.count && creditorIndex < creditors.count {
            let amount = min(debtorRemaining[debtorIndex], creditorRemaining[creditorIndex])
            transfers.append(
                Transfer(
                    from: debtors[debtorIndex].player,
                    to: creditors[creditorIndex].player,
                    amount: amount
                )
            )
            debtorRemaining[debtorIndex] -= amount
            creditorRemaining[creditorIndex] -= amount
            if debtorRemaining[debtorIndex] == 0 { debtorIndex += 1 }
            if creditorRemaining[creditorIndex] == 0 { creditorIndex += 1 }
        }
        return transfers
    }

    /// Rescales the nets to whole units so the subset search can add `Int64`s.
    ///
    /// That search runs up to 2^16 · 16 additions at the top of its range, and
    /// `Decimal` arithmetic is an order of magnitude dearer than integer
    /// arithmetic — enough to be felt on the settlement screen. Currency always
    /// survives the trip (it's exact to a couple of decimal places); anything
    /// that wouldn't returns `nil` rather than a rounded balance the search
    /// would then mistake for a clean split, and the caller falls back to
    /// greedy settling.
    private static func wholeUnits(_ amounts: [Decimal]) -> [Int64]? {
        let places = amounts.reduce(0) { max($0, -min(0, $1.exponent)) }
        guard places <= 6 else { return nil }
        var scale = Decimal(1)
        for _ in 0..<places { scale *= 10 }

        var units: [Int64] = []
        units.reserveCapacity(amounts.count)
        for amount in amounts {
            var scaled = amount * scale
            var rounded = Decimal()
            NSDecimalRound(&rounded, &scaled, 0, .plain)
            guard rounded == scaled else { return nil }
            let number = NSDecimalNumber(decimal: rounded)
            // Keeps every subset sum comfortably inside Int64 however the
            // search combines them.
            guard number.doubleValue.magnitude < 1e15 else { return nil }
            units.append(number.int64Value)
        }
        return units
    }
}
