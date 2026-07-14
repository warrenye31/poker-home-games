import Foundation

enum CurrencyFormatter {
    static func string(from amount: Decimal) -> String {
        formatter().string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    /// "+$120" / "−$45"; zero renders unsigned.
    static func signedString(from amount: Decimal) -> String {
        guard amount != 0 else { return string(from: amount) }
        let magnitude = string(from: amount < 0 ? -amount : amount)
        return (amount < 0 ? "\u{2212}" : "+") + magnitude
    }

    /// Blinds keep cents but drop trailing zeros, so "$1/$2" doesn't read as
    /// "$1.00/$2.00" while sub-dollar stakes (e.g. $0.05 / $0.10) still show.
    static func blindString(from amount: Decimal) -> String {
        formatter(minFractionDigits: 0, maxFractionDigits: 2).string(from: amount as NSDecimalNumber) ?? string(from: amount)
    }

    /// Unsymboled, ungrouped numeric text suitable for feeding back into an
    /// editable amount field (e.g. auto-filling buy-in from blinds) — "10"
    /// rather than "10.00" or "$10.00".
    static func plainString(from amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    /// Plain symbols only — no "CA$"/"US$" region prefixes, which is what
    /// `NumberFormatter` inserts automatically once `currencyCode` disagrees
    /// with the device locale's default currency.
    private static let symbols: [String: String] = [
        "USD": "$", "CAD": "$", "GBP": "\u{00A3}", "EUR": "\u{20AC}"
    ]

    private static func formatter(minFractionDigits: Int = 2, maxFractionDigits: Int = 2) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = symbols[CurrencySettings.shared.code] ?? "$"
        formatter.minimumFractionDigits = minFractionDigits
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter
    }
}
