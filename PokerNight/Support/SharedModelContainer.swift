import Foundation
import SwiftData

/// Single source of truth for the SwiftData schema/container, shared between
/// the app and the widget extension via an App Group container so both
/// processes read and write the same store.
enum SharedModelContainer {
    static let appGroupID = "group.com.pokernight.app"
    static let selectedGroupNameKey = "selectedGroupName"
    static let widgetKind = "LeaderboardWidget"

    static func make() -> ModelContainer {
        let schema = Schema([
            GameGroup.self,
            Player.self,
            Session.self,
            SessionEntry.self,
            BuyIn.self,
            SettlementPayment.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(appGroupID),
            cloudKitDatabase: .private("iCloud.com.pokernight.app")
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
}
