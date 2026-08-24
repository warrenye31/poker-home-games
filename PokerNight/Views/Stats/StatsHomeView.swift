import SwiftUI
import SwiftData
import Charts

struct StatsHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var isPresentingClaimSheet = false
    @State private var claimedPlayerID: UUID?
    @State private var range: LeaderboardRange = .allTime

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
                        GroupSwitcherMenu()
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
            List {
                Section {
                    rangePicker
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if ranked.isEmpty {
                    // Stays inside the List so the picker above it survives —
                    // swapping the whole screen for an empty state would strand
                    // someone on a window they can't change their way out of.
                    Section {
                        ContentUnavailableView(
                            range == .allTime ? "No players yet" : "Nothing in this window",
                            systemImage: "chart.bar",
                            description: Text(range.emptyDescription)
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } else {
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
                        SectionLabel(chartTitle)
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
            }
            .listStyle(.insetGrouped)
            .appScreenBackground()
        } else {
            ContentUnavailableView(
                "No group selected",
                systemImage: "chart.bar",
                description: Text("Open a group first from the Groups tab.")
            )
            .appScreenBackground()
        }
    }

    /// Segmented rather than a menu: three options people flip between while
    /// looking at the same list, so the cost of a tap matters more than the
    /// vertical space a menu would save.
    private var rangePicker: some View {
        Picker("Range", selection: $range) {
            ForEach(LeaderboardRange.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var chartTitle: String {
        range == .allTime ? "Lifetime net" : "Net \(range.label.lowercased())"
    }

    private func standingRow(_ entry: RankedPlayer) -> some View {
        PlayerStandingRow(
            player: entry.player,
            isYou: entry.player.id == claimedPlayerID,
            rank: entry.rank,
            net: entry.stats.net,
            games: entry.stats.gamesPlayed
        )
    }

    private func yourStatsCard(_ entry: RankedPlayer) -> some View {
        HStack(spacing: 14) {
            Monogram(name: entry.player.name, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(range == .allTime ? "Your net" : "Your net \(range.label.lowercased())")
                Text("Rank #\(entry.rank) \u{00B7} \(countLabel(entry.stats.gamesPlayed, "game"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MoneyText(amount: entry.stats.net, role: .net, style: .title3)
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

    private struct RankedPlayer: Identifiable {
        let rank: Int
        let stats: ScopedPlayerStats

        var player: Player { stats.player }
        /// `player.id`, not `persistentModelID`: the latter is reassigned when a
        /// newly-inserted model is first saved, which would churn ForEach/Chart
        /// identity mid-render. See `GameGroup.id`.
        var id: UUID { stats.id }
        var netValue: Double { stats.netValue }
    }

    private func rankedPlayers(in group: GameGroup) -> [RankedPlayer] {
        LeaderboardCalculator.standings(in: group, range: range)
            .enumerated()
            .map { RankedPlayer(rank: $0.offset + 1, stats: $0.element) }
    }
}
