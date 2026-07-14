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

    private static func formatter(minFractionDigits: Int = 2, maxFractionDigits: Int = 2) -> NumberFormatter {
        // Shared App Group suite so the widget extension sees the same
        // currency the user picked in Settings, not just the main app.
        let code = SharedModelContainer.sharedDefaults?.string(forKey: "currencyCode") ?? "USD"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.minimumFractionDigits = minFractionDigits
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter
    }
}
