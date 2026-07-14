import SwiftUI

/// "This is me" picker. Anyone (admin or viewer) can pick which roster player
/// represents them on this device — except the group creator's own player,
/// which only the admin device may claim; it's reserved everywhere else.
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
                        }
                        .buttonStyle(.plain)
                        .cardBackground()
                    }
                    .cardRowContainer()
                } footer: {
                    if group.role == .viewer && group.adminPlayerID != nil {
                        Text("The host's player is reserved and can't be claimed by anyone else.")
                    }
                }

                if selection != nil {
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
            .navigationTitle("This is me")
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

    private func claim(_ player: Player) {
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
