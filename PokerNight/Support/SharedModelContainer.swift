import Foundation
import SwiftData

/// Single source of truth for the SwiftData schema/container.
enum SharedModelContainer {
    static let appGroupID = "group.com.waylabsinc.pokernight"
    static let selectedGroupNameKey = "selectedGroupName"

    /// Flag (in the App Group defaults) marking that existing rows have had
    /// fresh stable UUIDs assigned after the `id` column was introduced.
    private static let didBackfillStableIDsKey = "didBackfillStableIDs.v1"

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
            groupContainer: .identifier(appGroupID)
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            backfillStableIDsIfNeeded(container: container)
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// Adding a non-optional `id: UUID` is a SwiftData lightweight migration:
    /// existing rows are populated with the property's *single* default value,
    /// so every pre-existing row can end up sharing one UUID. This one-time
    /// pass reassigns a fresh `UUID()` to each existing row so identities are
    /// actually unique before any server sync or player claim references them.
    /// It runs at most once per store (guarded by an App Group defaults flag)
    /// and only touches the four synced models. Relationships are keyed on
    /// SwiftData's internal `persistentModelID`, so rewriting `id` is safe.
    private static func backfillStableIDsIfNeeded(container: ModelContainer) {
        let defaults = sharedDefaults ?? .standard
        guard !defaults.bool(forKey: didBackfillStableIDsKey) else { return }

        let context = ModelContext(container)
        do {
            for group in try context.fetch(FetchDescriptor<GameGroup>()) { group.id = UUID() }
            for player in try context.fetch(FetchDescriptor<Player>()) { player.id = UUID() }
            for session in try context.fetch(FetchDescriptor<Session>()) { session.id = UUID() }
            for entry in try context.fetch(FetchDescriptor<SessionEntry>()) { entry.id = UUID() }
            if context.hasChanges { try context.save() }
            defaults.set(true, forKey: didBackfillStableIDsKey)
        } catch {
            // Leave the flag unset so we retry on the next launch rather than
            // proceed with potentially colliding IDs.
            assertionFailure("Stable-ID backfill failed: \(error)")
        }
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
}
