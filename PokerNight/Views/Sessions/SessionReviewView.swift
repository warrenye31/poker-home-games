import SwiftUI
import SwiftData

struct SessionReviewView: View {
    let group: GameGroup
    let draft: NewSessionDraft
    var onCreate: (Session) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var buyInCounts: [PersistentIdentifier: Int] = [:]

    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: draft.date.formatted(date: .abbreviated, time: .omitted))
                    .listRowBackground(AppTheme.surface)
                if !draft.location.isEmpty {
                    LabeledContent("Location", value: draft.location)
                        .listRowBackground(AppTheme.surface)
                }
                if let smallBlind = draft.smallBlind, let bigBlind = draft.bigBlind {
                    LabeledContent("Blinds", value: "\(CurrencyFormatter.blindString(from: smallBlind)) / \(CurrencyFormatter.blindString(from: bigBlind))")
                        .listRowBackground(AppTheme.surface)
                }
                LabeledContent("Standard buy-in", value: CurrencyFormatter.string(from: draft.standardBuyIn))
                    .listRowBackground(AppTheme.surface)
            } header: {
                SectionLabel("Session")
            }

            Section {
                VStack(spacing: 6) {
                    SectionLabel("Starting pot")
                    MoneyText(amount: startingPot, style: .title2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .listRowBackground(AppTheme.surface)

            Section {
                ForEach(draft.players) { player in
                    HStack(spacing: 14) {
                        Monogram(name: player.name, size: 34)
                        Text(player.name)
                            .font(.body.weight(.medium))
                        Spacer()
                        Stepper(
                            "\(count(for: player))",
                            value: countBinding(for: player),
                            in: 1...20
                        )
                        .fixedSize()
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(AppTheme.surface)
            } header: {
                SectionLabel("Buy-ins per player")
            }
        }
        .listStyle(.insetGrouped)
        .appScreenBackground()
        .navigationTitle("Review")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create session") { create() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            for player in draft.players where buyInCounts[player.persistentModelID] == nil {
                buyInCounts[player.persistentModelID] = 1
            }
        }
    }

    private var startingPot: Decimal {
        draft.players.reduce(Decimal(0)) { $0 + draft.standardBuyIn * Decimal(count(for: $1)) }
    }

    private func count(for player: Player) -> Int {
        buyInCounts[player.persistentModelID] ?? 1
    }

    private func countBinding(for player: Player) -> Binding<Int> {
        Binding(
            get: { count(for: player) },
            set: { buyInCounts[player.persistentModelID] = $0 }
        )
    }

    private func create() {
        let session = Session(
            date: draft.date,
            location: draft.location.isEmpty ? nil : draft.location,
            usesBank: draft.usesBank,
            bankPlayer: draft.bankPlayer,
            smallBlind: draft.smallBlind,
            bigBlind: draft.bigBlind,
            standardBuyIn: draft.standardBuyIn
        )
        modelContext.insert(session)
        group.sessions.append(session)
        for player in draft.players {
            let entry = SessionEntry(player: player)
            for _ in 0..<count(for: player) {
                entry.buyIns.append(BuyIn(amount: draft.standardBuyIn))
            }
            session.entries.append(entry)
        }
        onCreate(session)
    }
}
