import SwiftUI
import SwiftData

/// The one screen this app needs: pick your name, tap to log a buy-in
/// against the session that's live on the phone right now.
struct WatchBuyInView: View {
    @Bindable var session: Session

    @AppStorage("watchSelectedPlayerName") private var selectedPlayerName = ""
    @AppStorage("defaultBuyIn") private var defaultBuyIn: Double = 20
    @Environment(\.modelContext) private var modelContext
    @State private var buyInTick = 0

    var body: some View {
        Group {
            if roster.isEmpty {
                ContentUnavailableView(
                    "No players",
                    systemImage: "person.slash",
                    description: Text("Add players to this group from your phone.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        Picker("Player", selection: $selectedPlayerName) {
                            ForEach(roster, id: \.name) { player in
                                Text(player.name).tag(player.name)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 80)

                        MoneyText(amount: currentEntry?.totalBuyIn ?? 0, style: .title3)

                        Button {
                            logBuyIn()
                        } label: {
                            Label(
                                "+ Buy-in \(CurrencyFormatter.string(from: Decimal(defaultBuyIn)))",
                                systemImage: "plus.circle.fill"
                            )
                        }
                        .buttonStyle(.pill)
                        .disabled(selectedPlayerName.isEmpty)
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .appScreenBackground()
        .navigationTitle(session.group?.name ?? "Poker Night")
        .sensoryFeedback(.impact(weight: .medium), trigger: buyInTick)
        .onAppear(perform: ensureSelection)
    }

    private var roster: [Player] {
        (session.group?.players ?? []).sorted { $0.name < $1.name }
    }

    private var currentEntry: SessionEntry? {
        session.entries.first { $0.player?.name == selectedPlayerName }
    }

    private func ensureSelection() {
        guard !roster.contains(where: { $0.name == selectedPlayerName }) else { return }
        selectedPlayerName = roster.first?.name ?? ""
    }

    private func logBuyIn() {
        guard let player = roster.first(where: { $0.name == selectedPlayerName }) else { return }
        let entry = currentEntry ?? {
            let newEntry = SessionEntry(player: player)
            modelContext.insert(newEntry)
            session.entries.append(newEntry)
            return newEntry
        }()
        entry.buyIns.append(BuyIn(amount: Decimal(defaultBuyIn)))
        buyInTick += 1
    }
}
