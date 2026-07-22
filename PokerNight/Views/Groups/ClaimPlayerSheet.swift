import SwiftUI

/// "Which player are you?" picker. Anyone (admin or viewer) can pick which
/// roster player represents them on this device — except the group creator's own
/// player, which only the admin device may claim; it's reserved everywhere else.
struct ClaimPlayerSheet: View {
    @Bindable var group: GameGroup
    var onClaimChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: UUID?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(selectablePlayers) { player in
                        Button {
                            claim(player)
                        } label: {
                            HStack(spacing: 14) {
                                Monogram(name: player.name, size: 34)
                                Text(player.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selection == player.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                            // Plain-style buttons only register taps on the label's
                            // rendered content, not the Spacer's empty space — without
                            // this, only the monogram/name/checkmark are tappable and
                            // the rest of the row silently eats taps.
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!group.canChangeClaimedPlayer)
                        .cardBackground()
                    }
                    .cardRowContainer()
                } header: {
                    SectionLabel("Tap your name")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if group.canChangeClaimedPlayer {
                            Text("Your row gets a YOU badge, and your totals are highlighted wherever this group appears.")
                        } else {
                            // The organizer is pinned once viewers have synced
                            // admin_player_id — see GameGroup.canChangeClaimedPlayer.
                            Label(
                                "You've already invited people to this group, so the player you picked is locked in.",
                                systemImage: "lock.fill"
                            )
                        }
                        if group.role == .viewer && group.adminPlayerID != nil {
                            Text("The host's player is reserved and can't be claimed by anyone else.")
                        }
                        // Viewers can't edit the roster, so the only way out is
                        // to ask the person who can — by name, where we know it.
                        if group.role == .viewer {
                            Text("Not here? Ask \(organizerName) to add you.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Clearing is a change like any other, so it's gated the same way:
                // an organizer who has already shared can't un-pick themselves.
                if selection != nil && group.canChangeClaimedPlayer {
                    Section {
                        Button(role: .destructive) {
                            clearClaim()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Clear my claim")
                                Spacer()
                            }
                        }
                    }
                    .listRowBackground(AppTheme.surface)
                }
            }
            .listStyle(.insetGrouped)
            .appScreenBackground()
            .navigationTitle("Which player are you?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                selection = PlayerClaimStore.validClaimedPlayerID(for: group)
            }
        }
    }

    /// Everyone can claim any player except the admin's reserved identity —
    /// unless this device *is* the admin, since they're the one allowed to
    /// designate (or reassign) that identity in the first place.
    private var selectablePlayers: [Player] {
        if group.role == .admin {
            return group.players
        }
        return group.players.filter { $0.id != group.adminPlayerID }
    }

    /// The organizer's name, for the "ask them to add you" hint. Viewers learn
    /// this from the synced `adminPlayerID`; before the organizer has picked
    /// themselves there's no name to give, so fall back to a generic noun.
    private var organizerName: String {
        guard
            let adminPlayerID = group.adminPlayerID,
            let organizer = group.players.first(where: { $0.id == adminPlayerID })
        else { return "the organizer" }
        return organizer.name
    }

    private func claim(_ player: Player) {
        guard group.canChangeClaimedPlayer else { return }
        selection = player.id
        PlayerClaimStore.setClaimedPlayerID(player.id, for: group.id)
        if group.role == .admin {
            group.adminPlayerID = player.id
            GroupSyncService.shared.pushSnapshotIfShared(group)
        }
        onClaimChanged()
        dismiss()
    }

    private func clearClaim() {
        guard group.canChangeClaimedPlayer else { return }
        selection = nil
        PlayerClaimStore.setClaimedPlayerID(nil, for: group.id)
        if group.role == .admin {
            group.adminPlayerID = nil
            GroupSyncService.shared.pushSnapshotIfShared(group)
        }
        onClaimChanged()
        dismiss()
    }
}
