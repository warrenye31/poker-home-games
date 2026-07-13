import Foundation

enum CurrencyFormatter {
    static func string(from amount: Decimal) -> String {
        let code = UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}
