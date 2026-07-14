import Foundation

/// A common small/big blind structure offered as a one-tap preset.
///
/// Blinds are stored as strings so they feed straight into the stakes text
/// fields without floating-point rounding, and expose `Decimal` values for
/// display and comparison.
struct BlindPreset: Identifiable, Hashable {
    let small: String
    let big: String

    var id: String { "\(small)/\(big)" }

    var smallBlind: Decimal { Decimal(string: small) ?? 0 }
    var bigBlind: Decimal { Decimal(string: big) ?? 0 }

    var label: String {
        "\(CurrencyFormatter.blindString(from: smallBlind)) / \(CurrencyFormatter.blindString(from: bigBlind))"
    }

    /// The small/big blind combinations most home games actually use, ordered
    /// from micro to mid stakes. $0.25/$0.50 and $1/$2 are the most typical.
    static let common: [BlindPreset] = [
        BlindPreset(small: "0.05", big: "0.10"),
        BlindPreset(small: "0.10", big: "0.25"),
        BlindPreset(small: "0.25", big: "0.50"),
        BlindPreset(small: "0.50", big: "1"),
        BlindPreset(small: "1", big: "2"),
        BlindPreset(small: "1", big: "3"),
        BlindPreset(small: "2", big: "5"),
        BlindPreset(small: "5", big: "10"),
    ]
}
