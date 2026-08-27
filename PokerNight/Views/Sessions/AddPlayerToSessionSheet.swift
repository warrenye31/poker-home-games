import SwiftUI
import SwiftData

/// Seats a latecomer at a session that's already running.
///
/// Home games almost never start with everyone at the table, and until this
/// existed the only way to add the person who turned up at ten was to delete the
/// session and rebuild it. Anyone added here starts with one buy-in, exactly as
/// they would have at setup — the amount is editable because a latecomer is
/// precisely who buys in short or deep.
///
/// Multi-select rather than tap-to-add: people arrive in pairs, and a car full
/// of players shouldn't mean reopening this sheet four times.
struct AddPlayerToSessionSheet: View {
    @Bindable var session: Session

    @Environment(\.dismiss) private var dismiss
    /// Keyed by `Player.id`, not `persistentModelID`: SwiftData reassigns the
    /// latter when a newly-inserted model is first saved, and a player added on
    /// this very screen is exactly that case. See `GameGroup.id`.
    @State private var selectedPlayerIDs = Set<UUID>()
    @State private var newPlayerName = ""
    @State private var buyInText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MoneyFieldRow(label: "Buy-in", placeholder: "Amount", text: $buyInText)
                        .listRowBackground(AppTheme.surface)
                } header: {
                    SectionLabel("Starting with")
                }

                Section {
                    if availablePlayers.isEmpty {
                        Text("Everyone on the roster is already seated.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .listRowBackground(AppTheme.surface)
                    } else {
                        ForEach(availablePlayers) { player in
                            let isSelected = selectedPlayerIDs.contains(player.id)
                            Button {
                                toggle(player)
                            } label: {
                                HStack(spacing: 14) {
                                    Monogram(name: player.name, size: 34)
                                    Text(player.name)
                                        .font(.body.weight(.medium))
                                    Spacer()
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(isSelected ? AppTheme.accent : Color.secondary.opacity(0.5))
                                }
                                .padding(.vertical, 2)
                                .fullRowTapTarget()
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(AppTheme.surface)
                    }

                    HStack {
                        CursorEndTextField(placeholder: "Add new player", text: $newPlayerName)
                            .inputFieldStyle()
                        Button("Add", action: addNewPlayer)
                            .fontWeight(.semibold)
                            .disabled(trimmedNewName.isEmpty)
                    }
                    .listRowBackground(AppTheme.surface)
                } header: {
                    SectionLabel("Who just arrived")
                }
            }
            .appScreenBackground()
            .navigationTitle("Add players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selectedPlayerIDs.isEmpty ? "Seat" : "Seat \(selectedPlayerIDs.count)") { seatSelected() }
                        .fontWeight(.semibold)
                        .disabled(selectedPlayerIDs.isEmpty || buyInAmount == nil)
                }
            }
            .onAppear {
                if buyInText.isEmpty {
                    buyInText = CurrencyFormatter.plainString(from: session.standardBuyIn)
                }
            }
        }
    }

    // MARK: - Data

    /// Roster players who aren't already at this table.
    private var availablePlayers: [Player] {
        guard let group = session.group else { return [] }
        let seated = Set(session.entries.compactMap { $0.player?.id })
        return group.players.filter { !seated.contains($0.id) }
    }

    private var trimmedNewName: String {
        newPlayerName.trimmingCharacters(in: .whitespaces)
    }

    private var buyInAmount: Decimal? {
        guard let parsed = Decimal(string: buyInText), parsed > 0 else { return nil }
        return parsed
    }

    // MARK: - Actions

    private func toggle(_ player: Player) {
        if selectedPlayerIDs.contains(player.id) {
            selectedPlayerIDs.remove(player.id)
        } else {
            selectedPlayerIDs.insert(player.id)
        }
    }

    /// Adds someone who isn't on the roster yet — a friend-of-a-friend showing
    /// up is a normal way for a home game to gain a player. They join the group
    /// permanently and are pre-selected, since typing their name *is* the intent
    /// to seat them.
    private func addNewPlayer() {
        guard let group = session.group, !trimmedNewName.isEmpty else { return }
        let player = Player(name: trimmedNewName)
        group.players.append(player)
        selectedPlayerIDs.insert(player.id)
        newPlayerName = ""
        GroupSyncService.shared.pushSnapshotIfShared(group)
    }

    private func seatSelected() {
        guard let amount = buyInAmount, let group = session.group else { return }
        for player in group.players where selectedPlayerIDs.contains(player.id) {
            let entry = SessionEntry(player: player)
            entry.buyIns.append(BuyIn(amount: amount))
            session.entries.append(entry)
        }
        GroupSyncService.shared.pushSnapshotIfShared(group)
        dismiss()
    }
}
