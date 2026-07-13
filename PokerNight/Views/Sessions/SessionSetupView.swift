import SwiftUI
import SwiftData

struct SessionSetupView: View {
    let group: GameGroup
    var onStart: (Session) -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultBuyIn") private var defaultBuyIn: Double = 20
    @State private var date = Date.now
    @State private var usesBank = false
    @State private var bankPlayer: Player?
    @State private var selectedPlayerIDs = Set<PersistentIdentifier>()
    @State private var newPlayerName = ""

    var body: some View {
        Form {
            Section("Details") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Toggle("Use a bank", isOn: $usesBank)
                if usesBank {
                    Picker("Bank", selection: $bankPlayer) {
                        Text("Select a player").tag(Player?.none)
                        ForEach(selectedPlayers) { player in
                            Text(player.name).tag(Optional(player))
                        }
                    }
                }
            }

            Section("Players") {
                ForEach(group.players) { player in
                    Button {
                        toggle(player)
                    } label: {
                        HStack {
                            Text(player.name)
                            Spacer()
                            if selectedPlayerIDs.contains(player.persistentModelID) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
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
                    .disabled(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle("New session")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Start") { start() }
                    .disabled(selectedPlayerIDs.count < 2 || (usesBank && bankPlayer == nil))
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

    private func start() {
        let session = Session(date: date, usesBank: usesBank, bankPlayer: bankPlayer)
        modelContext.insert(session)
        group.sessions.append(session)
        for player in selectedPlayers {
            let entry = SessionEntry(player: player)
            entry.buyIns.append(BuyIn(amount: Decimal(defaultBuyIn)))
            session.entries.append(entry)
        }
        onStart(session)
    }
}
