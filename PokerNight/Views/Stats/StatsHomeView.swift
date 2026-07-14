import SwiftUI
import SwiftData
import Charts

struct StatsHomeView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \GameGroup.name) private var groups: [GameGroup]
    @State private var isPresentingClaimSheet = false
    @State private var claimedPlayerID: UUID?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Leaderboard")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if appState.selectedGroup != nil {
                            Button {
                                isPresentingClaimSheet = true
                            } label: {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                            }
                        }
                        groupSwitcher
                    }
                }
                .sheet(isPresented: $isPresentingClaimSheet) {
                    if let group = appState.selectedGroup {
                        ClaimPlayerSheet(group: group, onClaimChanged: refreshClaim)
                    }
                }
                .onAppear(perform: refreshClaim)
                .onChange(of: appState.selectedGroup?.id) { _, _ in refreshClaim() }
        }
    }

    private func refreshClaim() {
        claimedPlayerID = appState.selectedGroup.flatMap { PlayerClaimStore.validClaimedPlayerID(for: $0) }
    }

    @ViewBuilder
    private var content: some View {
        if let group = appState.selectedGroup {
            let ranked = rankedPlayers(in: group)
            if ranked.isEmpty {
                ContentUnavailableView(
                    "No players yet",
                    systemImage: "chart.bar",
                    description: Text("Add players to this group to see stats.")
                )
                .appScreenBackground()
            } else {
                List {
                    if let claimedPlayerID, let you = ranked.first(where: { $0.player.id == claimedPlayerID }) {
                        Section {
                            yourStatsCard(you)
                                .cardRowContainer()
                        }
                    }

                    Section {
                        netChart(for: ranked)
                            .frame(height: CGFloat(ranked.count) * 36 + 28)
                            .cardBackground()
                            .cardRowContainer()
                    } header: {
                        SectionLabel("Lifetime net")
                    }

                    Section {
                        ForEach(ranked) { entry in
                            standingRow(entry)
                        }
                        .cardRowContainer()
                    } header: {
                        SectionLabel("Standings")
                    }
                }
                .listStyle(.insetGrouped)
                .appScreenBackground()
            }
        } else {
            ContentUnavailableView(
                "No group selected",
                systemImage: "chart.bar",
                description: Text("Open a group first from the Groups tab.")
            )
            .appScreenBackground()
        }
    }

    private func standingRow(_ entry: RankedPlayer) -> some View {
        let isYou = entry.player.id == claimedPlayerID
        return HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(AppTheme.money(.footnote))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
            Monogram(name: entry.player.name, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.player.name)
                        .font(.body.weight(.medium))
                    if isYou {
                        Text("YOU")
                            .font(.caption2.weight(.bold))
                            .tracking(0.5)
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.15), in: Capsule())
                    }
                }
                Text("\(entry.player.gamesPlayed) game\(entry.player.gamesPlayed == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MoneyText(amount: entry.player.lifetimeNet, role: .net, style: .callout)
        }
        .cardBackground()
    }

    private func yourStatsCard(_ entry: RankedPlayer) -> some View {
        HStack(spacing: 14) {
            Monogram(name: entry.player.name, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel("Your net")
                Text("Rank #\(entry.rank) \u{00B7} \(entry.player.gamesPlayed) game\(entry.player.gamesPlayed == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MoneyText(amount: entry.player.lifetimeNet, role: .net, style: .title3)
        }
        .cardBackground()
    }

    private func netChart(for ranked: [RankedPlayer]) -> some View {
        Chart(ranked) { entry in
            BarMark(
                x: .value("Net", entry.netValue),
                y: .value("Player", entry.player.name),
                height: .fixed(16)
            )
            .foregroundStyle(AppTheme.accent)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                    .foregroundStyle(AppTheme.hairline)
                AxisValueLabel()
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.primary)
            }
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
        let rank: Int
        let player: Player
        var id: PersistentIdentifier { player.persistentModelID }
        var netValue: Double { Double(truncating: player.lifetimeNet as NSNumber) }
    }

    private func rankedPlayers(in group: GameGroup) -> [RankedPlayer] {
        group.players
            .sorted { $0.lifetimeNet > $1.lifetimeNet }
            .enumerated()
            .map { RankedPlayer(rank: $0.offset + 1, player: $0.element) }
    }
}
