import SwiftUI
import UIKit

// MARK: - Snapshot

/// Plain-value copy of everything the share card draws.
///
/// The card renders from this rather than from the live SwiftData models on
/// purpose: `ImageRenderer` walks the view tree outside SwiftUI's own update
/// cycle, so a `@Model` that faults (or gets deleted) mid-render has nothing to
/// invalidate. Copying the handful of values up front also keeps the card
/// previewable without a model container.
struct GroupShareSnapshot {
    struct Standing: Identifiable {
        let id: UUID
        let name: String
        let gamesPlayed: Int
        let net: Decimal
        let isYou: Bool
    }

    let groupName: String
    let standings: [Standing]
    let sessionCount: Int
    let lastPlayed: Date?

    init(group: GameGroup, claimedPlayerID: UUID?) {
        groupName = group.name
        standings = group.players
            .map { player in
                Standing(
                    id: player.id,
                    name: player.name,
                    gamesPlayed: player.gamesPlayed,
                    net: player.lifetimeNet,
                    isYou: player.id == claimedPlayerID
                )
            }
            .sorted { $0.net > $1.net }
        // Lifetime nets only count completed sessions, so the session line has
        // to agree — counting the live game would put a number on the card that
        // none of the standings reflect yet.
        let completed = group.sessions.filter { $0.status == .completed }
        sessionCount = completed.count
        lastPlayed = completed.map(\.date).max()
    }
}

// MARK: - The rendered card

/// The image itself: group header, standings, and a small app credit.
///
/// Deliberately does *not* include the join code. A screenshot is made to be
/// posted somewhere public, and the code grants read access to the group.
struct GroupShareCard: View {
    let snapshot: GroupShareSnapshot

    /// Point width the renderer draws at; the exported pixel width is this
    /// times `ImageRenderer.scale`.
    static let width: CGFloat = 380

    /// Long rosters would produce a tall, unreadable strip in a chat bubble.
    private static let maxRows = 12

    /// A standing plus its finishing position, so the rows can be a plain
    /// `ForEach` over one identifiable value.
    private struct RankedStanding: Identifiable {
        let rank: Int
        let standing: GroupShareSnapshot.Standing
        var id: UUID { standing.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            VStack(spacing: 8) {
                ForEach(visibleStandings) { ranked in
                    row(ranked.standing, rank: ranked.rank)
                }
                if hiddenCount > 0 {
                    Text("+ \(countLabel(hiddenCount, "more player"))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                }
            }
            footer
        }
        .padding(22)
        .frame(width: Self.width, alignment: .leading)
        .background(AppTheme.background)
        // The renderer starts from the environment's default (light), and the
        // palette here is fixed dark — without this, `.primary` inside Monogram
        // would draw black text on a near-black card.
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Monogram(name: snapshot.groupName, kind: .group, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.groupName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
    }

    private func row(_ standing: GroupShareSnapshot.Standing, rank: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(AppTheme.money(.footnote))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 16, alignment: .trailing)
            Monogram(name: standing.name, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(standing.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if standing.isYou {
                        YouBadge()
                    }
                }
                Text(countLabel(standing.gamesPlayed, "game"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer(minLength: 8)
            Text(CurrencyFormatter.signedString(from: standing.net))
                .font(AppTheme.money(.callout))
                .monospacedDigit()
                .foregroundStyle(standing.net < 0 ? AppTheme.loss : .white)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Image(systemName: "suit.spade.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.accent)
            Text(AppLinks.appName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.65))
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private var visibleStandings: [RankedStanding] {
        snapshot.standings
            .prefix(Self.maxRows)
            .enumerated()
            .map { RankedStanding(rank: $0.offset + 1, standing: $0.element) }
    }

    private var hiddenCount: Int {
        max(0, snapshot.standings.count - Self.maxRows)
    }

    private var subtitle: String {
        var parts = [countLabel(snapshot.standings.count, "player")]
        parts.append(countLabel(snapshot.sessionCount, "game"))
        if let lastPlayed = snapshot.lastPlayed {
            parts.append("last played \(lastPlayed.formatted(date: .abbreviated, time: .omitted))")
        }
        return parts.joined(separator: " \u{00B7} ")
    }
}

// MARK: - Sheet

/// Turns the group's standings into a picture you can drop straight into the
/// group chat — the thing people were doing by hand with a phone screenshot,
/// minus the status bar, the half-cropped rows, and the join code.
struct GroupScreenshotShareSheet: View {
    let snapshot: GroupShareSnapshot

    @Environment(\.dismiss) private var dismiss
    @State private var rendered: UIImage?
    @State private var didCopy = false
    @State private var copyCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let rendered {
                        Image(uiImage: rendered)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(AppTheme.hairline, lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
                            .accessibilityLabel("Standings image for \(snapshot.groupName)")
                    } else {
                        ProgressView()
                            .padding(.vertical, 80)
                    }

                    Text("No join code in the picture \u{2014} safe to post anywhere.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .appScreenBackground()
            .navigationTitle("Share standings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let rendered {
                    actions(for: rendered)
                }
            }
            .sensoryFeedback(.success, trigger: copyCount)
            .onAppear { render() }
        }
    }

    private func actions(for image: UIImage) -> some View {
        let shareable = Image(uiImage: image)
        return VStack(spacing: 10) {
            ShareLink(
                item: shareable,
                preview: SharePreview(snapshot.groupName, image: shareable)
            ) {
                Label("Share screenshot", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(prominent: true))

            Button {
                UIPasteboard.general.image = image
                copyCount += 1
                withAnimation(.snappy(duration: 0.2)) { didCopy = true }
            } label: {
                Label(didCopy ? "Copied" : "Copy image", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(prominent: false))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    @MainActor
    private func render() {
        guard rendered == nil else { return }
        let renderer = ImageRenderer(content: GroupShareCard(snapshot: snapshot))
        // 3x so the card stays crisp when a chat app blows it up; opaque skips
        // the alpha channel it would never use.
        renderer.scale = 3
        renderer.isOpaque = true
        rendered = renderer.uiImage
    }
}
