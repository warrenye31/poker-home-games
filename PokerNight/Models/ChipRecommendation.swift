import Foundation

/// The four colors a standard home-game chip set uses, lowest value to highest.
///
/// The names are the convention, not a requirement — what matters is that a
/// table agrees on an order. The guide labels each row with its position too, so
/// a set with blue instead of green still reads correctly.
enum ChipColor: String, CaseIterable, Identifiable {
    case white, red, green, black

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    /// Fallback wording for sets that don't use these exact colors.
    var positionLabel: String {
        switch self {
        case .white: "Lowest"
        case .red: "2nd"
        case .green: "3rd"
        case .black: "Highest"
        }
    }
}

/// One color in a recommended chip set: what it's worth and how many of it go
/// into each player's starting stack.
struct ChipDenomination: Identifiable, Hashable {
    let color: ChipColor
    let value: Decimal
    /// Chips of this color in each starting stack. Zero for the top chip, which
    /// is held back for rebuys and bigger buy-ins.
    let startingCount: Int

    var id: String { color.rawValue }

    var label: String { CurrencyFormatter.blindString(from: value) }

    var startingValue: Decimal { value * Decimal(startingCount) }
}

/// A complete chip plan for a set of stakes: four denominations, the starting
/// stack that adds up to the buy-in, and how many physical chips the table needs
/// to pull it off.
///
/// Everything here is derived from small blind + buy-in, so nothing is stored on
/// `Session` — the guide recomputes whenever the stakes change.
struct ChipRecommendation {
    let denominations: [ChipDenomination]
    let smallBlind: Decimal
    let bigBlind: Decimal
    let buyIn: Decimal

    /// What one starting stack is actually worth. Equals `buyIn` unless the
    /// buy-in isn't a whole number of the smallest chip, which `notes` calls out.
    var stackValue: Decimal {
        denominations.reduce(Decimal(0)) { $0 + $1.startingValue }
    }

    var chipsPerStack: Int {
        denominations.reduce(0) { $0 + $1.startingCount }
    }

    /// The rebuy chip — the one players don't start with.
    var topChip: ChipDenomination { denominations[denominations.count - 1] }

    /// "$0.25 · $1 · $5 · $25" — the one-line version for a summary row.
    var summaryLine: String {
        denominations.map(\.label).joined(separator: " · ")
    }

    /// Whole top chips in one rebuy, rounded down — what a player can actually
    /// be handed in top chips alone.
    var wholeTopChipsInRebuy: Int {
        Self.units(buyIn, per: topChip.value)
    }

    /// Whether a rebuy comes out to a whole number of top chips at all. False
    /// whenever the buy-in isn't a multiple of the top chip — a $25 buy-in
    /// against a $10 black — which is why the copy can't just name a count.
    var rebuyIsWholeTopChips: Bool {
        Decimal(wholeTopChipsInRebuy) * topChip.value == buyIn
    }

    /// A single rebuy in top chips, rounded **up**. This is a stocking figure,
    /// not a payout: it feeds `topChipReserve`, and a host who set aside two
    /// chips for a two-and-a-half-chip rebuy would be breaking into a stack to
    /// make up the difference. `rebuyDescription` is the honest payout.
    var rebuyInTopChips: Int {
        max(1, Self.unitsRoundingUp(buyIn, per: topChip.value))
    }

    /// How a rebuy is really paid out, in words. Names a chip count only when
    /// the buy-in divides evenly; otherwise it says the count *and* that change
    /// is needed, because "2 chips buys back in" is off by $5 at a $25 buy-in.
    /// The color is left to the caller, which has already named it.
    var rebuyDescription: String {
        let amount = CurrencyFormatter.string(from: buyIn)
        guard wholeTopChipsInRebuy > 0 else {
            return "a \(amount) rebuy comes out of the smaller chips"
        }
        let chips = countLabel(wholeTopChipsInRebuy, "chip")
        return rebuyIsWholeTopChips
            ? "a \(amount) rebuy is \(chips)"
            : "a \(amount) rebuy is \(chips) plus change"
    }

    /// Top chips to keep aside per player: two rebuys' worth, so the host isn't
    /// breaking into someone's starting stack halfway through the night.
    var topChipReserve: Int {
        max(3, rebuyInTopChips * 2)
    }

    /// Physical chips of one color the table needs for `playerCount` players.
    func tableCount(for chip: ChipDenomination, playerCount: Int) -> Int {
        let per = chip.startingCount > 0 ? chip.startingCount : topChipReserve
        return per * max(playerCount, 1)
    }

    func totalChips(playerCount: Int) -> Int {
        denominations.reduce(0) { $0 + tableCount(for: $1, playerCount: playerCount) }
    }

    // MARK: - Advice

    /// Plain-language caveats worth showing under the table. Only the ones that
    /// actually apply to this plan are returned.
    var notes: [String] {
        var notes: [String] = []
        let lowest = denominations[0]
        let lowestName = lowest.color.name.lowercased()
        let topName = topChip.color.name.lowercased()

        if smallBlind > 0 {
            if lowest.value == smallBlind {
                notes.append("Your \(lowestName) chip equals the small blind, so blinds always post exactly.")
            } else if lowest.value > smallBlind {
                // Only reachable when the buy-in outran the ladder and the lowest
                // chip had to be walked up — worth saying plainly, because the
                // small blind can no longer be posted with a single chip.
                notes.append("Heads up: at \(CurrencyFormatter.string(from: buyIn)) a buy-in, chips small enough for a \(CurrencyFormatter.blindString(from: smallBlind)) blind would mean hundreds per stack. Raise the blinds or lower the buy-in to keep them in step.")
            } else {
                let blindsInChips = Self.units(smallBlind, per: lowest.value)
                if blindsInChips > 1 {
                    notes.append("The small blind is \(blindsInChips) \(lowestName) chips — workable, but expect more counting at the blinds.")
                }
            }
        }

        notes.append("Every chip is a whole multiple of the one below it, so change is always makeable.")

        if bigBlind > 0 {
            let stackInBigBlinds = Self.units(buyIn, per: bigBlind)
            if stackInBigBlinds > 0 {
                notes.append("A buy-in is \(stackInBigBlinds) big blinds — \(Self.stackDepthAdvice(stackInBigBlinds)).")
            }
        }

        notes.append("Keep the \(topName)s with the host rather than in the stacks — \(rebuyDescription).")

        if stackValue != buyIn {
            let short = buyIn - stackValue
            let direction = short > 0 ? "under" : "over"
            notes.append("This stack comes to \(CurrencyFormatter.string(from: stackValue)), \(CurrencyFormatter.string(from: abs(short))) \(direction) the buy-in. Round the buy-in to a multiple of \(lowest.label) and it comes out even.")
        }

        return notes
    }

    private static func stackDepthAdvice(_ bigBlinds: Int) -> String {
        switch bigBlinds {
        case ..<40: "short, so expect a fast, shove-heavy game"
        case 40..<80: "on the short side but perfectly playable"
        case 80..<150: "the standard home-game depth"
        default: "very deep — plan for a long night"
        }
    }

    // MARK: - Recommendation

    /// The denominations real chip sets are actually sold in. Anything off this
    /// ladder (a $1.25 chip, a $30 chip) is rejected no matter how well the math
    /// works out, because nobody owns one. Stored in cents so the values are
    /// exact — `Decimal` built from a float literal is not.
    private static let ladder: [Decimal] = [
        5, 10, 25, 50, 100, 200, 500, 1_000, 2_000, 2_500,
        5_000, 10_000, 20_000, 50_000, 100_000, 500_000
    ].map { Decimal($0) / 100 }

    /// Step-up factors between consecutive chips. Whole numbers only: each chip
    /// has to be an exact multiple of the one under it or you can't make change.
    /// Capped at 5 — jump further and the chip in between stops getting used.
    private static let ratios = [2, 3, 4, 5]

    /// Builds the best four-chip plan for these stakes, or `nil` if there isn't
    /// enough to go on (no buy-in, or a buy-in smaller than one chip).
    ///
    /// The search pins the lowest chip to the small blind, then scores every
    /// ladder-legal combination of three step-ups on two things: how close the
    /// top chip lands to half a buy-in (so a rebuy is a couple of chips), and how
    /// conventional the step-ups are. Distance from the target dominates, so an
    /// unusual-but-workable set beats a pretty one that is off by 4×.
    static func recommend(smallBlind: Decimal?, bigBlind: Decimal?, buyIn: Decimal) -> ChipRecommendation? {
        let small = smallBlind ?? 0
        let big = bigBlind ?? 0
        guard buyIn > 0,
              let start = baseChip(smallBlind: small, bigBlind: big, buyIn: buyIn),
              start < buyIn else { return nil }

        // Pinning the lowest chip to the small blind is right until the buy-in
        // outruns what four chips can span: nickel chips with a $2,000 buy-in
        // works out to a 3,000-chip stack. When that happens, walk the lowest
        // chip up the ladder until a stack is something a person can physically
        // stack, and let `notes` explain why the blind no longer matches.
        let candidates = ladder.filter { $0 >= start && $0 < buyIn }
        var fallback: ChipRecommendation?

        for base in candidates.isEmpty ? [start] : candidates {
            guard let values = bestSet(base: base, buyIn: buyIn) else { continue }
            let counts = startingStack(buyIn: buyIn, denominations: values)
            let plan = ChipRecommendation(
                denominations: values.enumerated().map { index, value in
                    ChipDenomination(color: ChipColor.allCases[index], value: value, startingCount: counts[index])
                },
                smallBlind: small,
                bigBlind: big,
                buyIn: buyIn
            )
            if plan.chipsPerStack <= maxChipsPerStack { return plan }
            fallback = fallback ?? plan
        }

        return fallback
    }

    /// A stack taller than this stops being a stack and starts being a problem,
    /// so it's the signal to try a bigger lowest chip.
    private static let maxChipsPerStack = 60

    /// Best-scoring four-chip ladder for a fixed lowest chip.
    private static func bestSet(base: Decimal, buyIn: Decimal) -> [Decimal]? {
        // The top chip wants to sit at half a buy-in: big enough to keep rebuys
        // to a couple of chips, small enough that it isn't dead weight.
        let target = dbl(buyIn) / 2
        var best: (score: Double, values: [Decimal])?

        for r1 in ratios {
            let second = base * Decimal(r1)
            guard isStocked(second) else { continue }
            for r2 in ratios {
                let third = second * Decimal(r2)
                guard isStocked(third) else { continue }
                for r3 in ratios {
                    let top = third * Decimal(r3)
                    guard isStocked(top) else { continue }
                    let score = -40 * abs(log(dbl(top) / target)) + conventionScore(r1, r2, r3)
                    if best == nil || score > best!.score {
                        best = (score, [base, second, third, top])
                    }
                }
            }
        }
        return best?.values
    }

    /// Prefers the step-ups real sets use, weighted toward the bottom of the
    /// ladder where a wrong jump hurts most. ×5 is the classic 1/5/25/100
    /// progression and ×4 is the 0.25/1/5/25 one; ×3 scores zero because a chip
    /// three times the last one isn't a denomination anyone stocks.
    private static func conventionScore(_ r1: Int, _ r2: Int, _ r3: Int) -> Double {
        func quality(_ ratio: Int) -> Double {
            switch ratio {
            case 5: 3
            case 4: 2
            case 2: 1
            default: 0
            }
        }
        return quality(r1) * 3 + quality(r2) * 2 + quality(r3)
    }

    /// The lowest chip: the small blind, snapped to a denomination that both
    /// exists and divides the blind evenly. Falls back to half the big blind,
    /// then to a 100-big-blind read of the buy-in when no stakes are set at all.
    private static func baseChip(smallBlind: Decimal, bigBlind: Decimal, buyIn: Decimal) -> Decimal? {
        let raw: Decimal
        if smallBlind > 0 {
            raw = smallBlind
        } else if bigBlind > 0 {
            raw = bigBlind / 2
        } else {
            raw = buyIn / 100
        }
        guard raw > 0 else { return nil }
        if let exact = ladder.last(where: { $0 <= raw && divides($0, raw) }) { return exact }
        if let below = ladder.last(where: { $0 <= raw }) { return below }
        return ladder.first
    }

    private static func isStocked(_ value: Decimal) -> Bool {
        ladder.contains(value)
    }

    private static func divides(_ divisor: Decimal, _ value: Decimal) -> Bool {
        guard divisor > 0 else { return false }
        return Decimal(units(value, per: divisor)) * divisor == value
    }

    // MARK: - Starting stack

    /// Splits one buy-in into chips: roughly 10% in the lowest color, 20% in the
    /// second, the rest in the third, then sweeps any remainder back down so the
    /// stack lands exactly on the buy-in.
    ///
    /// The lowest color is clamped to 8–12 chips: fewer and you can't cover a
    /// couple of orbits of blinds, more and everyone is stacking pennies. The top
    /// color is deliberately left at zero — it's the rebuy chip.
    private static func startingStack(buyIn: Decimal, denominations: [Decimal]) -> [Int] {
        let chip = denominations
        var counts = [0, 0, 0, 0]

        counts[0] = min(max(units(buyIn / 10, per: chip[0]), 8), 12)
        counts[1] = max(units(buyIn / 5, per: chip[1]), 4)

        // Leave room for at least one third-color chip. Without this, a shallow
        // buy-in gets swallowed by the two floors above and the whole stack comes
        // out in small chips with the third color unused.
        if chip[2] <= buyIn {
            while counts[1] > 1,
                  Decimal(counts[0]) * chip[0] + Decimal(counts[1]) * chip[1] > buyIn - chip[2] {
                counts[1] -= 1
            }
        }

        var remaining = buyIn - Decimal(counts[0]) * chip[0] - Decimal(counts[1]) * chip[1]
        // A small buy-in can't afford the floors above; hand the minimums back
        // one chip at a time rather than emitting a stack worth more than a buy-in.
        while remaining < 0 && counts[1] > 0 {
            counts[1] -= 1
            remaining += chip[1]
        }
        while remaining < 0 && counts[0] > 0 {
            counts[0] -= 1
            remaining += chip[0]
        }
        guard remaining >= 0 else { return counts }

        counts[2] = units(remaining, per: chip[2])
        remaining -= Decimal(counts[2]) * chip[2]

        // Whatever the third color couldn't absorb goes back down the ladder.
        // With whole-number step-ups this always clears, so the stack is exact.
        let extraSecond = units(remaining, per: chip[1])
        counts[1] += extraSecond
        remaining -= Decimal(extraSecond) * chip[1]

        counts[0] += units(remaining, per: chip[0])

        return counts
    }

    // MARK: - Decimal helpers

    /// Whole chips of `denom` that fit in `amount`, rounding down. The round to
    /// six places first keeps a division like 30 / 0.25 from landing on 119.999…
    /// and quietly losing a chip.
    private static func units(_ amount: Decimal, per denom: Decimal) -> Int {
        guard denom > 0, amount > 0 else { return 0 }
        var quotient = amount / denom
        var settled = Decimal()
        NSDecimalRound(&settled, &quotient, 6, .plain)
        var floored = Decimal()
        NSDecimalRound(&floored, &settled, 0, .down)
        return NSDecimalNumber(decimal: floored).intValue
    }

    /// `units`, rounded up instead of down — for figures where being short is
    /// the expensive direction, such as how many chips to stock.
    private static func unitsRoundingUp(_ amount: Decimal, per denom: Decimal) -> Int {
        guard denom > 0, amount > 0 else { return 0 }
        var quotient = amount / denom
        var settled = Decimal()
        NSDecimalRound(&settled, &quotient, 6, .plain)
        var raised = Decimal()
        NSDecimalRound(&raised, &settled, 0, .up)
        return NSDecimalNumber(decimal: raised).intValue
    }

    private static func dbl(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
