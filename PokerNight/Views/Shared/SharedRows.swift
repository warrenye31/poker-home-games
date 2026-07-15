import SwiftUI
import SwiftData

// MARK: - Counted nouns

/// "1 game" / "3 games" — the one pluralization idiom every list subtitle uses.
func countLabel(_ count: Int, _ noun: String) -> String {
    "\(count) \(noun)\(count == 1 ? "" : "s")"
}

// MARK: - "You" badge

/// Small accent pill marking the roster player this device has claimed.
struct YouBadge: View {
    var body: some View {
        Text("YOU")
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppTheme.accent.opacity(0.15), in: Capsule())
    }
}

// MARK: - Player rows

/// Card row for a player: monogram, name (+ YOU badge), games played, and
/// lifetime net. Shared by the group roster and the stats standings so a
/// player reads identically everywhere; standings pass a `rank` to prepend.
struct PlayerStandingRow: View {
    let player: Player
    var isYou = false
    var rank: Int?

    var body: some View {
        HStack(spacing: 12) {
            if let rank {
                Text("\(rank)")
                    .font(AppTheme.money(.footnote))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .trailing)
            }
            Monogram(name: player.name, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(player.name)
                        .font(.body.weight(.medium))
                    if isYou {
                        YouBadge()
                    }
                }
                Text(countLabel(player.gamesPlayed, "game"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MoneyText(amount: player.lifetimeNet, role: .net, style: .callout)
        }
        .cardBackground()
    }
}

// MARK: - Session rows

/// Card row for a session in any list: date + LIVE pill, a contextual
/// subtitle, and the total pot on the right.
struct SessionCardRow: View {
    let session: Session
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(session.displayName)
                        .font(.body.weight(.semibold))
                    if session.status == .active {
                        LivePill()
                    }
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MoneyText(amount: session.totalBuyIns, style: .callout)
        }
        .cardBackground()
    }
}

/// Standard interactive wrapper for a session card. Completed sessions push
/// straight to settlement; active ones re-open the live flow instead, so we
/// never show settlement for an unbalanced game. Editors get a long-press
/// delete that routes through `sessionDeleteConfirmation`.
///
/// Context menu instead of a swipe action: swipe buttons render against the
/// List row's own frame, which drifts out of alignment with the custom card
/// background/insets from `.cardRowContainer()`. A long-press menu is
/// positioned by the system at the touch point, so it can't desync from the
/// row it belongs to.
struct SessionHistoryRow: View {
    let session: Session
    let subtitle: String
    @Binding var resumingSession: Session?
    @Binding var sessionToDelete: Session?

    var body: some View {
        Group {
            if session.status == .active {
                Button {
                    resumingSession = session
                } label: {
                    SessionCardRow(session: session, subtitle: subtitle)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: session) {
                    SessionCardRow(session: session, subtitle: subtitle)
                }
            }
        }
        .contextMenu {
            if session.group?.canEdit ?? true {
                Button(role: .destructive) {
                    sessionToDelete = session
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Session delete confirmation

/// Shared "Delete this session?" dialog. Deletes locally and re-pushes the
/// group snapshot so shared groups drop the session server-side immediately
/// instead of waiting for the next unrelated edit to sync.
private struct SessionDeleteConfirmation: ViewModifier {
    @Binding var sessionToDelete: Session?
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Delete this session?",
            isPresented: Binding(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    let group = session.group
                    modelContext.delete(session)
                    if let group {
                        GroupSyncService.shared.pushSnapshotIfShared(group)
                    }
                }
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
        } message: {
            Text("This permanently removes the session and its buy-ins.")
        }
    }
}

extension View {
    /// Attaches the shared session-delete confirmation dialog, driven by a
    /// `Session?` binding (set it to present; cleared on dismiss).
    func sessionDeleteConfirmation(_ sessionToDelete: Binding<Session?>) -> some View {
        modifier(SessionDeleteConfirmation(sessionToDelete: sessionToDelete))
    }
}

// MARK: - Group switcher

/// Toolbar menu for changing the active group on the Sessions and Stats tabs.
struct GroupSwitcherMenu: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \GameGroup.name) private var groups: [GameGroup]

    var body: some View {
        Menu {
            ForEach(groups) { group in
                Button(group.name) { appState.selectedGroup = group }
            }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
        }
    }
}
