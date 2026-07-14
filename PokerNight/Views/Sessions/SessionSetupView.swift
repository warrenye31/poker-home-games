import SwiftUI
import SwiftData

struct SessionSetupView: View {
    let group: GameGroup
    var onNext: (NewSessionDraft) -> Void

    @AppStorage("defaultBuyIn") private var defaultBuyIn: Double = 20
    @State private var name = ""
    @State private var date = Date.now
    @State private var location = ""
    @State private var smallBlindText = ""
    @State private var bigBlindText = ""
    @State private var standardBuyInText = ""
    @State private var usesBank = false
    @State private var bankPlayer: Player?
    @State private var selectedPlayerIDs = Set<PersistentIdentifier>()
    @State private var newPlayerName = ""

    var body: some View {
        Form {
            Section {
                TextField("Session name (optional)", text: $name)
                    .listRowBackground(AppTheme.surface)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .listRowBackground(AppTheme.surface)
                TextField("Location (optional)", text: $location)
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
                HStack {
                    Text("Small blind")
                    Spacer()
                    TextField("Optional", text: $smallBlindText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(AppTheme.money())
                        .monospacedDigit()
                        .frame(width: 100)
                }
                .listRowBackground(AppTheme.surface)
                HStack {
                    Text("Big blind")
                    Spacer()
                    TextField("Optional", text: $bigBlindText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(AppTheme.money())
                        .monospacedDigit()
                        .frame(width: 100)
                }
                .listRowBackground(AppTheme.surface)
                HStack {
                    Text("Standard buy-in")
                    Spacer()
                    TextField("Amount", text: $standardBuyInText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(AppTheme.money())
                        .monospacedDigit()
                        .frame(width: 100)
                }
                .listRowBackground(AppTheme.surface)
            } header: {
                SectionLabel("Stakes")
            }

            Section {
                ForEach(group.players) { player in
                    let isSelected = selectedPlayerIDs.contains(player.persistentModelID)
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
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(AppTheme.surface)

                HStack {
                    TextField("Add new player", text: $newPlayerName)
                    Button("Add") {
                        let trimmed = newPlayerName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let player = Player(name: trimmed)
                        group.players.append(player)
                        selectedPlayerIDs.insert(player.persistentModelID)
                        newPlayerName = ""
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
                Button("Next") { next() }
                    .fontWeight(.semibold)
                    .disabled(selectedPlayerIDs.count < 2 || (usesBank && bankPlayer == nil))
            }
        }
        .onAppear {
            if standardBuyInText.isEmpty {
                standardBuyInText = defaultBuyIn.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(defaultBuyIn))
                    : String(defaultBuyIn)
            }
        }
    }

    private var selectedPlayers: [Player] {
        group.players.filter { selectedPlayerIDs.contains($0.persistentModelID) }
    }

    private func toggle(_ player: Player) {
        if selectedPlayerIDs.contains(player.persistentModelID) {
            selectedPlayerIDs.remove(player.persistentModelID)
            if bankPlayer === player { bankPlayer = nil }
        } else {
            selectedPlayerIDs.insert(player.persistentModelID)
        }
    }

    private func next() {
        let draft = NewSessionDraft(
            name: name.trimmingCharacters(in: .whitespaces),
            date: date,
            location: location.trimmingCharacters(in: .whitespaces),
            smallBlind: Decimal(string: smallBlindText),
            bigBlind: Decimal(string: bigBlindText),
            standardBuyIn: Decimal(string: standardBuyInText) ?? Decimal(defaultBuyIn),
            usesBank: usesBank,
            bankPlayer: bankPlayer,
            players: selectedPlayers
        )
        onNext(draft)
    }
}
