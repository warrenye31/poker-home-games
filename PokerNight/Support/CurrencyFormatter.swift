import Foundation

enum CurrencyFormatter {
    static func string(from amount: Decimal) -> String {
        formatter().string(from: amount as NSDecimalNumber) ?? "$0"
    }

    /// "+$120" / "−$45"; zero renders unsigned.
    static func signedString(from amount: Decimal) -> String {
        guard amount != 0 else { return string(from: amount) }
        let magnitude = string(from: amount < 0 ? -amount : amount)
        return (amount < 0 ? "\u{2212}" : "+") + magnitude
    }

    private static func formatter() -> NumberFormatter {
        let code = UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 0
        return formatter
    }
}
