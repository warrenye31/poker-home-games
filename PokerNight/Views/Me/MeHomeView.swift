import SwiftUI
import SwiftData

/// Your own results, pooled across every group you play in.
///
/// The other tabs are scoped to one group at a time, which answers "how did the
/// Tuesday game go" but never "am I up overall". This is the only place that
/// crosses group boundaries.
///
/// "You" is defined by the per-group claim (`PlayerClaimStore`), so a group where
/// you haven't picked a player simply doesn't contribute — there's no way to know
/// which of its players is you. That's also why the empty state points at the
/// picker rather than at creating data.
struct MeHomeView: View {
    @Query(sort: \GameGroup.name) private var groups: [GameGroup]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Me")
        }
    }

    // MARK: - Data

    /// A group plus the player you've claimed in it.
    private struct Identity: Identifiable {
        let group: GameGroup
        let player: Player
        var id: UUID { group.id }

        var net: Decimal { player.lifetimeNet }
        var gamesPlayed: Int { player.gamesPlayed }
    }

    /// One entry per group where you've said which player is you.
    private var identities: [Identity] {
        groups.compactMap { group in
            guard
                let claimedID = PlayerClaimStore.validClaimedPlayerID(for: group),
                let player = group.players.first(where: { $0.id == claimedID })
            else { return nil }
            return Identity(group: group, player: player)
        }
    }

    private var totalNet: Decimal {
        identities.reduce(Decimal(0)) { $0 + $1.net }
    }

    private var totalGames: Int {
        identities.reduce(0) { $0 + $1.gamesPlayed }
    }

    /// Every completed session you took part in, newest first, tagged with the
    /// group it came from — without that tag the list is ambiguous the moment
    /// you play in more than one game.
    private struct PlayedSession: Identifiable {
        let session: Session
        let groupName: String
        let net: Decimal
        var id: UUID { session.id }
    }

    private var playedSessions: [PlayedSession] {
        identities
            .flatMap { identity in
                identity.player.entries.compactMap { entry -> PlayedSession? in
                    guard let session = entry.session, session.status == .completed else { return nil }
                    return PlayedSession(
                        session: session,
                        groupName: identity.group.name,
                        net: entry.net
                    )
                }
            }
            .sorted { $0.session.date > $1.session.date }
    }

    // MARK: - View

    @ViewBuilder
    private var content: some View {
        if identities.isEmpty {
            ContentUnavailableView(
                "No results yet",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text(groups.isEmpty
                    ? "Join or create a group, then pick which player is you."
                    : "Open a group and pick which player is you to see your results here.")
            )
            .appScreenBackground()
        } else {
            List {
                Section {
                    summaryCard
                        .cardRowContainer()
                }

                Section {
                    ForEach(identities) { identity in
                        groupRow(identity)
                    }
                    .cardRowContainer()
                } header: {
                    SectionLabel("By group")
                }

                if !playedSessions.isEmpty {
                    Section {
                        ForEach(playedSessions) { played in
                            sessionRow(played)
                        }
                        .cardRowContainer()
                    } header: {
                        SectionLabel("Your sessions")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .appScreenBackground()
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 10) {
            SectionLabel("Lifetime net")
            MoneyText(amount: totalNet, role: .net, style: .largeTitle)
            Text("\(countLabel(totalGames, "game")) across \(countLabel(identities.count, "group"))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .cardBackground()
    }

    private func groupRow(_ identity: Identity) -> some View {
        HStack(spacing: 12) {
            Monogram(name: identity.group.name, kind: .group, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(identity.group.name)
                    .font(.body.weight(.medium))
                // Names who you are in this group: the same person is often a
                // different roster name from one game to the next.
                Text("\(identity.player.name) \u{00B7} \(countLabel(identity.gamesPlayed, "game"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MoneyText(amount: identity.net, role: .net, style: .callout)
        }
        .cardBackground()
    }

    private func sessionRow(_ played: PlayedSession) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(played.session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.body.weight(.medium))
                Text(played.groupName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MoneyText(amount: played.net, role: .net, style: .callout)
        }
        .cardBackground()
    }
}
