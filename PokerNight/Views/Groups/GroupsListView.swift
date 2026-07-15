import SwiftUI
import SwiftData

/// Destinations on the Groups stack that aren't a model value.
///
/// Exists so the inbox can be pushed with `NavigationLink(value:)` like
/// everything else here. Every link in a stack should use the same mechanism:
/// closure-based links and `navigationDestination` don't compose, and the seams
/// only show up as misrouted pushes at runtime.
private enum HomeRoute: Hashable {
    case inbox
}

struct GroupsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameGroup.createdDate, order: .reverse) private var groups: [GameGroup]
    @State private var isPresentingNewGroup = false
    @State private var isPresentingJoinGroup = false
    @State private var groupToDelete: GameGroup?
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            List {
                // Joining is a first-class action for anyone invited to someone
                // else's game — it was a toolbar glyph, which is the one place a
                // brand-new user with an empty screen won't look.
                Section {
                    Button {
                        isPresentingJoinGroup = true
                    } label: {
                        JoinGroupButton()
                    }
                    .buttonStyle(.plain)
                    .cardRowContainer()
                }

                Section {
                    // In-list rather than a full-screen overlay: the overlay
                    // covered the Join row above and swallowed its taps, so a
                    // brand-new user couldn't join anyone's game.
                    if groups.isEmpty {
                        Text("No groups yet \u{2014} create one above, or join with a code.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardBackground()
                            .cardRowContainer()
                    }
                    ForEach(groups) { group in
                        HStack(spacing: 10) {
                            // Same treatment as the roster: the control lives in
                            // the row's inset gutter, since swipe actions and
                            // EditButton both render against the List row frame
                            // and misalign with .cardRowContainer()'s insets.
                            if isEditing {
                                Button {
                                    groupToDelete = group
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.red)
                                        .accessibilityLabel(
                                            group.role == .viewer
                                                ? "Leave \(group.name)"
                                                : "Delete \(group.name)"
                                        )
                                }
                                .buttonStyle(.plain)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            }
                            NavigationLink(value: group) {
                                GroupRow(group: group)
                            }
                        }
                        // Long-press remains as a shortcut; the Edit button above
                        // is what makes this discoverable at all.
                        .contextMenu {
                            Button(role: .destructive) {
                                groupToDelete = group
                            } label: {
                                Label(group.role == .viewer ? "Leave group" : "Delete", systemImage: "trash")
                            }
                        }
                    }
                    .cardRowContainer()
                }
            }
            .groupDeleteConfirmation($groupToDelete)
            .listStyle(.insetGrouped)
            .appScreenBackground()
            .navigationTitle("Groups")
            .navigationDestination(for: GameGroup.self) { group in
                GroupDetailView(group: group)
            }
            // Inbox rows push straight to the settlement they came from, which is
            // where the paid checkbox lives — a reminder you can't act on is nagging.
            .navigationDestination(for: Session.self) { session in
                SettlementView(session: session)
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .inbox: InboxView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !groups.isEmpty {
                        Button(isEditing ? "Done" : "Edit") {
                            withAnimation(.snappy(duration: 0.2)) { isEditing.toggle() }
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !groups.isEmpty {
                        // Value-based, like every other link in this stack. A
                        // closure-based `NavigationLink { InboxView() }` here
                        // re-evaluates every time the toolbar re-renders — and
                        // pushing a session from inside the inbox re-renders it,
                        // which re-fired this link and pushed a *second* inbox on
                        // top of the settlement. Hence "tapping a card shows the
                        // inbox again, and backing out reveals the session".
                        NavigationLink(value: HomeRoute.inbox) {
                            InboxToolbarIcon(openCount: outstandingDebts.count)
                        }
                    }
                    Button {
                        isPresentingNewGroup = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewGroup) {
                GroupFormView()
            }
            .sheet(isPresented: $isPresentingJoinGroup) {
                JoinGroupSheet(onJoined: { _ in })
            }
        }
    }

    private var outstandingDebts: [OutstandingDebt] {
        DebtInbox.outstanding(in: groups)
    }

}

/// Toolbar entry point to the inbox, with an unread-style count badge.
///
/// The badge is the whole point of putting it here: it has to say "something is
/// waiting" from a glance at a screen you're not looking at yet. Hidden at zero
/// rather than showing a `0`, matching how every other iOS badge behaves.
private struct InboxToolbarIcon: View {
    let openCount: Int

    var body: some View {
        Image(systemName: "tray.full.fill")
            .overlay(alignment: .topTrailing) {
                if openCount > 0 {
                    Text("\(openCount)")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(AppTheme.accent, in: Capsule())
                        // Pushed clear of the glyph's own bounds so it reads as
                        // a badge sitting on top rather than part of the icon.
                        .alignmentGuide(.top) { $0[.bottom] - 6 }
                        .alignmentGuide(.trailing) { $0[.leading] + 10 }
                }
            }
            .accessibilityLabel(
                openCount > 0
                    ? "Inbox, \(countLabel(openCount, "open transaction"))"
                    : "Inbox"
            )
    }
}

/// Home-screen row for joining someone else's group with a share code.
private struct JoinGroupButton: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.key")
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Join a group")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                // Says where the code comes from: without it, "join" invites
                // hunting for a button that doesn't exist on this device.
                Text("Enter a code the organizer shared with you")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .cardBackground()
    }
}

private struct GroupRow: View {
    let group: GameGroup

    var body: some View {
        HStack(spacing: 14) {
            Monogram(name: group.name, kind: .group, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .cardBackground()
    }

    private var subtitle: String {
        let playerText = countLabel(group.players.count, "player")
        if let last = group.sessions.map(\.date).max() {
            return "\(playerText) \u{00B7} last played \(last.formatted(date: .abbreviated, time: .omitted))"
        }
        return playerText
    }
}
