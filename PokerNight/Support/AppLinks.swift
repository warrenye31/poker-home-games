import Foundation

/// Outward-facing name and links — the strings that end up in someone else's
/// group chat, where the target name ("PokerNight") isn't what they'll find in
/// the App Store.
enum AppLinks {
    /// What the app is called on the store listing.
    static let appName = "Poker Home Games Tracker"

    /// Public listing, handed out with every invite. Without it an invite is a
    /// bare code and the person receiving it has to guess which of the dozens
    /// of poker apps to install first.
    static let appStoreURL = URL(string: "https://apps.apple.com/ca/app/poker-home-games-tracker/id6790630335")!
}
