import SwiftUI
import SwiftData

struct StatsHomeView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \GameGroup.name) private var groups: [GameGroup]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Leaderboard")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        groupSwitcher
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let group = appState.selectedGroup {
            List {
                ForEach(rankedPlayers(in: group)) { ranked in
                    HStack {
                        Text(ranked.player.name)
                        Spacer()
                        Text(CurrencyFormatter.string(from: ranked.player.lifetimeNet))
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "No group selected",
                systemImage: "chart.bar",
                description: Text("Open a group first from the Groups tab.")
            )
        }
    }

    private var groupSwitcher: some View {
        Menu {
            ForEach(groups) { group in
                Button(group.name) { appState.selectedGroup = group }
            }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
        }
    }

    private struct RankedPlayer: Identifiable {
        let player: Player
        var id: PersistentIdentifier { player.persistentModelID }
    }

    private func rankedPlayers(in group: GameGroup) -> [RankedPlayer] {
        group.players
            .sorted { $0.lifetimeNet > $1.lifetimeNet }
            .map(RankedPlayer.init)
    }
}
