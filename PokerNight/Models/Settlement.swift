import Foundation

struct Transfer: Identifiable {
    let id = UUID()
    let from: Player
    let to: Player
    let amount: Decimal
}

enum SettlementCalculator {
    static func calculate(session: Session) -> [Transfer] {
        if session.usesBank, let bank = session.bankPlayer {
            return bankSettlement(session: session, bank: bank)
        }
        return simplifyDebts(session: session)
    }

    private static func bankSettlement(session: Session, bank: Player) -> [Transfer] {
        session.entries.compactMap { entry in
            guard let player = entry.player, player !== bank, entry.net != 0 else { return nil }
            return entry.net > 0
                ? Transfer(from: bank, to: player, amount: entry.net)
                : Transfer(from: player, to: bank, amount: -entry.net)
        }
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
