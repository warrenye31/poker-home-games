import SwiftUI
import SwiftData

struct SessionSetupView: View {
    let group: GameGroup
    var onCreate: (Session) -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultBuyIn") private var defaultBuyIn: Double = 20
    @State private var date = Date.now
    @State private var location = ""
    @State private var smallBlindText = ""
    @State private var bigBlindText = ""
    @State private var standardBuyInText = ""
    @State private var buyInEditedManually = false
    @State private var usesBank = false
    @State private var bankPlayer: Player?
    /// Keyed by `Player.id` (stable UUID), not `persistentModelID`: SwiftData
    /// reassigns the latter when a newly-inserted model is first saved, and a
    /// player added moments earlier on this very screen is exactly that case —
    /// the selection would silently empty. See `GameGroup.id`.
    @State private var selectedPlayerIDs = Set<UUID>()
    @State private var newPlayerName = ""
    @State private var showChipGuide = false

    var body: some View {
        Form {
            // A weekly game is the same stakes and mostly the same people every
            // time, so re-entering all of it is the biggest recurring tax in the
            // app. Deliberately a tap rather than a silent prefill: it fills the
            // roster too, and quietly seating six people would be a surprise.
            if let lastSession {
                Section {
                    Button {
                        applySettings(from: lastSession)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Same as last time")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(repeatSummary(for: lastSession))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .fullRowTapTarget()
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(AppTheme.surface)
                }
            }

            Section {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .listRowBackground(AppTheme.surface)
                CursorEndTextField(placeholder: "Location (optional)", text: $location)
                    .inputFieldStyle()
                    .listRowBackground(AppTheme.surface)
                Toggle("Use a bank", isOn: $usesBank)
                    .listRowBackground(AppTheme.surface)
                if usesBank {
                    Picker("Bank", selection: $bankPlayer) {
                        Text("Select a player").tag(Player?.none)
                        ForEach(selectedPlayers) { player in
                            Text(player.name).tag(Optional(player))
                        }
                    }
                    .listRowBackground(AppTheme.surface)
                }
            } header: {
                SectionLabel("Details")
            }

            Section {
                BlindPresetRow(smallBlindText: $smallBlindText, bigBlindText: $bigBlindText)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(AppTheme.surface)
                MoneyFieldRow(label: "Small blind", text: $smallBlindText)
                    .listRowBackground(AppTheme.surface)
                MoneyFieldRow(label: "Big blind", text: $bigBlindText)
                    .listRowBackground(AppTheme.surface)
                MoneyFieldRow(label: "Standard buy-in", placeholder: "Amount", text: standardBuyInBinding)
                    .listRowBackground(AppTheme.surface)
                ChipGuideRow(recommendation: chipRecommendation) { showChipGuide = true }
                    .listRowBackground(AppTheme.surface)
            } header: {
                SectionLabel("Stakes")
            }

            Section {
                ForEach(group.players) { player in
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

                HStack {
                    CursorEndTextField(placeholder: "Add new player", text: $newPlayerName)
                        .inputFieldStyle()
                    Button("Add") {
                        let trimmed = newPlayerName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let player = Player(name: trimmed)
                        group.players.append(player)
                        selectedPlayerIDs.insert(player.id)
                        newPlayerName = ""
                        GroupSyncService.shared.pushSnapshotIfShared(group)
                    }
                    .fontWeight(.semibold)
                    .disabled(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .listRowBackground(AppTheme.surface)
            } header: {
                SectionLabel("Players")
            }
        }
        .appScreenBackground()
        .navigationTitle("New session")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create session") { create() }
                    .fontWeight(.semibold)
                    .disabled(selectedPlayerIDs.count < 2 || (usesBank && bankPlayer == nil))
            }
        }
        .sheet(isPresented: $showChipGuide) {
            if let chipRecommendation {
                ChipGuideView(recommendation: chipRecommendation, initialPlayerCount: selectedPlayerIDs.count)
            }
        }
        .onAppear {
            if standardBuyInText.isEmpty {
                standardBuyInText = defaultBuyIn.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(defaultBuyIn))
                    : String(defaultBuyIn)
            }
        }
        .onChange(of: bigBlindText) { _, newValue in
            guard !buyInEditedManually, let bigBlind = Decimal(string: newValue), bigBlind > 0 else { return }
            // Standard home-game convention: buy in for 100 big blinds.
            standardBuyInText = CurrencyFormatter.plainString(from: bigBlind * 100)
        }
    }

    private var selectedPlayers: [Player] {
        group.players.filter { selectedPlayerIDs.contains($0.id) }
    }

    /// Recomputed from whatever is currently typed into the stakes fields, so
    /// the summary row tracks the blinds live instead of only updating on save.
    private var chipRecommendation: ChipRecommendation? {
        guard let buyIn = Decimal(string: standardBuyInText), buyIn > 0 else { return nil }
        return ChipRecommendation.recommend(
            smallBlind: Decimal(string: smallBlindText),
            bigBlind: Decimal(string: bigBlindText),
            buyIn: buyIn
        )
    }

    /// Tracks manual edits separately from the 100BB auto-fill: once someone
    /// types their own buy-in, further blind changes stop overwriting it.
    private var standardBuyInBinding: Binding<String> {
        Binding(
            get: { standardBuyInText },
            set: { standardBuyInText = $0; buyInEditedManually = true }
        )
    }

    // MARK: - Repeat last game

    private var lastSession: Session? {
        group.sessions.max { $0.date < $1.date }
    }

    /// Players from a past session who are still on the roster. Someone removed
    /// from the group since then can't be re-seated, so they're dropped here
    /// rather than counted in the summary and then silently missing.
    private func repeatablePlayerIDs(from previous: Session) -> Set<UUID> {
        let roster = Set(group.players.map(\.id))
        return Set(previous.entries.compactMap(\.player?.id).filter(roster.contains))
    }

    private func repeatSummary(for previous: Session) -> String {
        var parts = [countLabel(repeatablePlayerIDs(from: previous).count, "player")]
        if let small = previous.smallBlind, let big = previous.bigBlind, small > 0, big > 0 {
            parts.append("\(CurrencyFormatter.blindString(from: small))/\(CurrencyFormatter.blindString(from: big))")
        }
        parts.append("\(CurrencyFormatter.string(from: previous.standardBuyIn)) buy-in")
        return parts.joined(separator: " \u{00B7} ")
    }

    /// Copies everything except the date — tonight's game is tonight's date.
    private func applySettings(from previous: Session) {
        location = previous.location ?? ""
        smallBlindText = previous.smallBlind.map { CurrencyFormatter.plainString(from: $0) } ?? ""
        bigBlindText = previous.bigBlind.map { CurrencyFormatter.plainString(from: $0) } ?? ""
        standardBuyInText = CurrencyFormatter.plainString(from: previous.standardBuyIn)
        // Copying a buy-in counts as choosing one. Without this, writing the
        // blinds a line above would immediately overwrite it with 100 big blinds.
        buyInEditedManually = true

        selectedPlayerIDs = repeatablePlayerIDs(from: previous)
        // A bank who has left the roster — or who isn't being seated tonight —
        // can't hold the money, and a bank session with no bank can't be created.
        bankPlayer = previous.bankPlayer.flatMap { selectedPlayerIDs.contains($0.id) ? $0 : nil }
        usesBank = previous.usesBank && bankPlayer != nil
    }

    private func toggle(_ player: Player) {
        if selectedPlayerIDs.contains(player.id) {
            selectedPlayerIDs.remove(player.id)
            if bankPlayer === player { bankPlayer = nil }
        } else {
            selectedPlayerIDs.insert(player.id)
        }
    }

    private func create() {
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        let session = Session(
            date: date,
            location: trimmedLocation.isEmpty ? nil : trimmedLocation,
            usesBank: usesBank,
            bankPlayer: bankPlayer,
            smallBlind: Decimal(string: smallBlindText),
            bigBlind: Decimal(string: bigBlindText),
            standardBuyIn: Decimal(string: standardBuyInText) ?? Decimal(defaultBuyIn)
        )
        modelContext.insert(session)
        group.sessions.append(session)
        for player in selectedPlayers {
            let entry = SessionEntry(player: player)
            entry.buyIns.append(BuyIn(amount: session.standardBuyIn))
            session.entries.append(entry)
        }
        GroupSyncService.shared.pushSnapshotIfShared(group)
        onCreate(session)
    }
}
