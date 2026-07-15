import Foundation
import Observation
import StoreKit

/// Single source of truth for the user's selected currency.
///
/// `CurrencyFormatter` reads `code` from here instead of `UserDefaults`
/// directly. Because this is `@Observable` and money-rendering views read
/// `CurrencyFormatter` synchronously inside `body` (e.g. `MoneyText`),
/// SwiftUI's Observation tracking picks up the dependency several calls deep
/// and re-renders every currency display the moment `code` changes — not
/// just whichever view happens to own an `@AppStorage` for it.
@Observable
final class CurrencySettings {
    static let shared = CurrencySettings()

    static let supportedCodes = ["USD", "CAD", "GBP", "EUR"]

    private(set) var code: String

    private static let storageKey = "currencyCode"

    private init() {
        if let saved = SharedModelContainer.sharedDefaults?.string(forKey: Self.storageKey),
           Self.supportedCodes.contains(saved) {
            code = saved
        } else {
            code = Self.currencyCode(forRegion: Locale.current.region?.identifier)
            Task { await CurrencySettings.shared.refineFromStorefront() }
        }
    }

    func setCode(_ newCode: String) {
        guard Self.supportedCodes.contains(newCode), newCode != code else { return }
        code = newCode
        SharedModelContainer.sharedDefaults?.set(newCode, forKey: Self.storageKey)
    }

    /// Runs once, only before the user has ever picked a currency in
    /// Settings: refines the device-locale guess using the App Store
    /// storefront the app was actually downloaded from — a better signal
    /// for "where the app was downloaded" than device locale (e.g. a US
    /// device with a Canadian App Store account, or a traveler abroad).
    /// Silently keeps the locale-based guess if the storefront is
    /// unavailable (simulator without a signed-in Apple ID, offline, etc.).
    private func refineFromStorefront() async {
        guard SharedModelContainer.sharedDefaults?.string(forKey: Self.storageKey) == nil else { return }
        guard let storefront = await Storefront.current else { return }
        let detected = Self.currencyCode(forAlpha3Region: storefront.countryCode)
        code = detected
        SharedModelContainer.sharedDefaults?.set(detected, forKey: Self.storageKey)
    }

    private static let euroZoneAlpha2: Set<String> = [
        "AT", "BE", "CY", "EE", "FI", "FR", "DE", "GR", "IE", "IT",
        "LV", "LT", "LU", "MT", "NL", "PT", "SK", "SI", "ES", "HR"
    ]

    private static let euroZoneAlpha3: Set<String> = [
        "AUT", "BEL", "CYP", "EST", "FIN", "FRA", "DEU", "GRC", "IRL", "ITA",
        "LVA", "LTU", "LUX", "MLT", "NLD", "PRT", "SVK", "SVN", "ESP", "HRV"
    ]

    /// CAD is the base/fallback currency: it's what a US, undetected, or
    /// unsupported-region download lands on. GB and the eurozone still get
    /// their own currency when detected.
    private static func currencyCode(forRegion region: String?) -> String {
        switch region {
        case "US": return "USD"
        case "GB": return "GBP"
        case let r? where euroZoneAlpha2.contains(r): return "EUR"
        default: return "CAD"
        }
    }

    private static func currencyCode(forAlpha3Region region: String) -> String {
        switch region {
        case "USA": return "USD"
        case "GBR": return "GBP"
        case let r where euroZoneAlpha3.contains(r): return "EUR"
        default: return "CAD"
        }
    }
}
