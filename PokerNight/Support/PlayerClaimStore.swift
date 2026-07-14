import Foundation

/// Local "this is me" mapping: which player a device considers itself to be,
/// per group. Deliberately not server state — a claim is just a per-device
/// preference for how to highlight the leaderboard, so there's normally
/// nothing to reserve or reconcile across devices. Stored in the App Group's
/// shared UserDefaults (not SwiftData) so it survives independently of any
/// group/player row and is available to the widget if it ever wants it.
///
/// The one exception is the group creator's own claim: `GameGroup.adminPlayerID`
/// is synced server-side specifically so no *other* device can claim that same
/// player. `validClaimedPlayerID` enforces that, plus clears any claim that has
/// gone stale (the claimed player was renamed is fine — deleted is not).
enum PlayerClaimStore {
    private static let keyPrefix = "playerClaim."

    static func claimedPlayerID(for groupID: UUID) -> UUID? {
        guard let raw = SharedModelContainer.sharedDefaults?.string(forKey: key(groupID)) else { return nil }
        return UUID(uuidString: raw)
    }

    static func setClaimedPlayerID(_ playerID: UUID?, for groupID: UUID) {
        guard let defaults = SharedModelContainer.sharedDefaults else { return }
        if let playerID {
            defaults.set(playerID.uuidString, forKey: key(groupID))
        } else {
            defaults.removeObject(forKey: key(groupID))
        }
    }

    /// The claim to actually use for `group` right now — `nil` if there
    /// isn't one, if the claimed player no longer exists in the group, or
    /// (for a viewer) if the claimed player has since become the admin's
    /// reserved identity. Self-heals by clearing the stale claim so the UI's
    /// "This is me" entry point naturally invites picking again.
    static func validClaimedPlayerID(for group: GameGroup) -> UUID? {
        guard let claimed = claimedPlayerID(for: group.id) else { return nil }

        guard group.players.contains(where: { $0.id == claimed }) else {
            setClaimedPlayerID(nil, for: group.id)
            return nil
        }

        if group.role == .viewer, let adminPlayerID = group.adminPlayerID, adminPlayerID == claimed {
            setClaimedPlayerID(nil, for: group.id)
            return nil
        }

        return claimed
    }

    private static func key(_ groupID: UUID) -> String {
        keyPrefix + groupID.uuidString
    }
}
