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

    /// Attaches the shared group delete/leave confirmation, driven by a
    /// `GameGroup?` binding. Reached from two places — the group list's context
    /// menu and the button at the bottom of the group screen — which is exactly
    /// why the wording and the cleanup live here rather than at each call site.
    ///
    /// `onDeleted` runs *after* the model is removed; the detail screen uses it
    /// to pop, since it holds the group and can't outlive it.
    func groupDeleteConfirmation(
        _ groupToDelete: Binding<GameGroup?>,
        onDeleted: @escaping () -> Void = {}
    ) -> some View {
        modifier(GroupDeleteConfirmation(groupToDelete: groupToDelete, onDeleted: onDeleted))
    }
}

/// Shared confirmation for deleting (admin) or leaving (viewer) a group.
private struct GroupDeleteConfirmation: ViewModifier {
    @Binding var groupToDelete: GameGroup?
    let onDeleted: () -> Void
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content.confirmationDialog(
            groupToDelete?.role == .viewer ? "Leave this group?" : "Delete this group?",
            isPresented: Binding(
                get: { groupToDelete != nil },
                set: { if !$0 { groupToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(groupToDelete?.role == .viewer ? "Leave" : "Delete", role: .destructive) {
                if let group = groupToDelete {
                    // Viewer: drop this device's membership. Admin: delete the
                    // row for everyone — a local-only delete would leave the
                    // group alive on every device that joined it.
                    GroupSyncService.shared.leaveGroup(group)
                    GroupSyncService.shared.deleteRemoteGroup(group)
                    groupToDelete = nil
                    // Order matters: let the caller unmount (the detail screen
                    // pops) before the model disappears, or a view still holding
                    // this group faults on its next render. The local delete is
                    // deferred one turn so the pop is already in flight.
                    onDeleted()
                    DispatchQueue.main.async {
                        modelContext.delete(group)
                    }
                } else {
                    groupToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { groupToDelete = nil }
        } message: {
            Text(message)
        }
    }

    /// Deleting a *shared* group reaches other people's phones, so say so —
    /// "permanently removes the group" undersells it once viewers have joined.
    private var message: String {
        guard let group = groupToDelete else { return "" }
        if group.role == .viewer {
            return "This removes the group from your device. The host's data isn't affected."
        }
        if group.isShared {
            return "This permanently removes the group, its players, and all sessions — for everyone you invited, too. Their copy will stop working."
        }
        return "This permanently removes the group, its players, and all sessions."
    }
}

// MARK: - Group switcher

/// Toolbar menu for changing the active group on the Sessions and Stats tabs.
struct GroupSwitcherMenu: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \GameGroup.name) private var groups: [GameGroup]

    var body: some View {
        Menu {
            // A checkmark on the active row: a bare list of names doesn't say
            // which one you're looking at.
            ForEach(groups) { group in
                Button {
                    appState.selectedGroup = group
                } label: {
                    Label(
                        group.name,
                        systemImage: appState.selectedGroup?.id == group.id ? "checkmark" : ""
                    )
                }
            }
        } label: {
            // Names the current group with a chevron, rather than the old
            // `arrow.triangle.2.circlepath` — which is the *refresh* glyph and
            // read as "sync this", hiding the fact that groups are switchable.
            HStack(spacing: 4) {
                Text(appState.selectedGroup?.name ?? "Select group")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
            }
        }
    }
}
