import WidgetKit
import SwiftUI
import SwiftData

struct PlayerStanding: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let net: Decimal
}

struct LeaderboardEntry: TimelineEntry {
    let date: Date
    let groupName: String?
    let standings: [PlayerStanding]
}

/// Reads the last group selected in the app (via the shared App Group
/// defaults) and computes its lifetime-net standings from the shared
/// SwiftData store.
struct LeaderboardProvider: TimelineProvider {
    func placeholder(in context: Context) -> LeaderboardEntry {
        LeaderboardEntry(
            date: .now,
            groupName: "Friday Night",
            standings: [
                PlayerStanding(rank: 1, name: "Alex", net: 120),
                PlayerStanding(rank: 2, name: "Sam", net: 40),
                PlayerStanding(rank: 3, name: "Jordan", net: -60)
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LeaderboardEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LeaderboardEntry>) -> Void) {
        let entry = loadEntry()
        let nextRefresh = Date.now.addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry() -> LeaderboardEntry {
        guard let groupName = SharedModelContainer.sharedDefaults?.string(
            forKey: SharedModelContainer.selectedGroupNameKey
        ) else {
            return LeaderboardEntry(date: .now, groupName: nil, standings: [])
        }

        let context = ModelContext(SharedModelContainer.make())
        let descriptor = FetchDescriptor<GameGroup>(
            predicate: #Predicate<GameGroup> { $0.name == groupName }
        )

        guard let group = try? context.fetch(descriptor).first else {
            return LeaderboardEntry(date: .now, groupName: groupName, standings: [])
        }

        let ranked = group.players
            .sorted { $0.lifetimeNet > $1.lifetimeNet }
            .enumerated()
            .map { PlayerStanding(rank: $0.offset + 1, name: $0.element.name, net: $0.element.lifetimeNet) }

        return LeaderboardEntry(date: .now, groupName: groupName, standings: ranked)
    }
}

struct PokerNightWidgetEntryView: View {
    var entry: LeaderboardProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "suit.spade.fill")
                    .foregroundStyle(AppTheme.accent)
                Text(entry.groupName ?? "Poker Night")
                    .font(.headline)
                    .lineLimit(1)
            }

            if entry.standings.isEmpty {
                Spacer(minLength: 4)
                Text(entry.groupName == nil ? "Open the app to pick a group" : "No players yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(entry.standings.prefix(maxRows)) { standing in
                    HStack(spacing: 8) {
                        Text("\(standing.rank)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 14, alignment: .leading)
                        Text(standing.name)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Spacer()
                        Text(CurrencyFormatter.signedString(from: standing.net))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(standing.net < 0 ? AppTheme.loss : Color.primary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(AppTheme.background, for: .widget)
    }

    private var maxRows: Int {
        switch family {
        case .systemLarge: 8
        case .systemMedium: 4
        default: 3
        }
    }
}

struct LeaderboardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedModelContainer.widgetKind, provider: LeaderboardProvider()) { entry in
            PokerNightWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Leaderboard")
        .description("Shows the standings for your last-selected group.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct PokerNightWidgetBundle: WidgetBundle {
    var body: some Widget {
        LeaderboardWidget()
    }
}
