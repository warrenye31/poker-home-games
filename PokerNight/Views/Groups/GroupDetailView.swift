import SwiftUI
import SwiftData

struct GroupDetailView: View {
    @Bindable var group: GameGroup
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingNewSession = false
    @State private var isAddingPlayer = false
    @State private var newPlayerName = ""
    @State private var isPresentingShareSheet = false
    @State private var isPresentingScreenshotSheet = false
    @State private var isPresentingClaimSheet = false
    @State private var isRefreshing = false
    @State private var claimedPlayerID: UUID?
    @State private var resumingSession: Session?
    @State private var sessionToDelete: Session?
    @State private var playerToRemove: Player?
    @State private var isEditingRoster = false
    @State private var groupToDelete: GameGroup?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if group.role == .viewer {
                Section {
                    ViewerSyncBanner(group: group, isRefreshing: $isRefreshing, refresh: refresh)
                        .cardRowContainer()
                }
            }

            Section {
                ForEach(group.players) { player in
                    HStack(spacing: 10) {
                        // Sits outside the card, in the row's inset gutter: the
                        // card's own trailing edge is spoken for by the money
                        // column, and PlayerStandingRow is shared with the stats
                        // standings, so it can't grow a remove button of its own.
                        if isEditingRoster && canRemove(player) {
                            Button {
                                playerToRemove = player
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.red)
                                    .accessibilityLabel("Remove \(player.name)")
                            }
                            .buttonStyle(.plain)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                        PlayerStandingRow(player: player, isYou: player.id == claimedPlayerID)
                    }
                    // Long-press still works as a shortcut, but Edit above is
                    // what makes removal discoverable — a context menu is
                    // invisible until you already know it's there.
                    .contextMenu {
                        if canRemove(player) {
                            Button(role: .destructive) {
                                playerToRemove = player
                            } label: {
                                Label("Remove from group", systemImage: "trash")
                            }
                        }
                    }
                }
                .cardRowContainer()

                if group.canEdit {
                    HStack {
                        Spacer()
                        Button {
                            isAddingPlayer = true
                        } label: {
                            Label("Add player", systemImage: "person.badge.plus")
                        }
                        .buttonStyle(.pill(prominent: false))
                        Spacer()
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } header: {
                HStack {
                    SectionLabel("Roster")
                    Spacer()
                    if group.canEdit && group.players.contains(where: canRemove) {
                        Button(isEditingRoster ? "Done" : "Edit") {
                            withAnimation(.snappy(duration: 0.2)) { isEditingRoster.toggle() }
                        }
                        .font(.caption.weight(.semibold))
                        .textCase(nil)
                    }
                }
            } footer: {
                // Where you change your pick, now that the overflow menu is gone.
                // Only shown once there's something to state.
                if let claimedPlayerName {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.fill.badge.checkmark")
                        Text("You're \(claimedPlayerName).")
                        if group.canChangeClaimedPlayer {
                            Button("Change") { isPresentingClaimSheet = true }
                                .font(.footnote.weight(.semibold))
                        } else {
                            Text("Locked — this group is shared.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.footnote)
                }
            }

            // Inviting is the whole point of a *group*, and it used to live
            // behind a toolbar glyph — the one place nobody looks. It sits under
            // the roster because that's what it grows: the people already listed
            // are the ones you're about to hand a code to.
            if group.canEdit {
                Section {
                    Button {
                        // Not disabled when the organizer hasn't claimed a
                        // player yet: a dead button teaches nothing. Send them
                        // to the picker that unblocks it instead.
                        if group.canShare {
                            isPresentingShareSheet = true
                        } else {
                            isPresentingClaimSheet = true
                        }
                    } label: {
                        InviteFriendsCard(needsClaim: !group.canShare)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            Section {
                // In-place entry point, mirroring the roster's "Add player"
                // pill. The toolbar + does the same job, but a toolbar glyph is
                // easy to miss when your attention is on the list it fills.
                if group.canEdit {
                    HStack {
                        Spacer()
                        Button {
                            isPresentingNewSession = true
                        } label: {
                            Label("New session", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.pill(prominent: sortedSessions.isEmpty))
                        Spacer()
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if sortedSessions.isEmpty {
                    Text("No sessions yet")
                        .foregroundStyle(.secondary)
                        .cardBackground()
                        .cardRowContainer()
                } else {
                    ForEach(sortedSessions) { session in
                        sessionRow(for: session)
                    }
                    .cardRowContainer()
                }
            } header: {
                SectionLabel("Session history")
            }

            // Bottom of the detail screen is where people look for "get rid of
            // this thing" — the list's context menu is a shortcut, not a way to
            // find out the action exists.
            Section {
                Button(role: .destructive) {
                    groupToDelete = group
                } label: {
                    HStack {
                        Spacer()
                        Label(
                            group.role == .viewer ? "Leave group" : "Delete group",
                            systemImage: group.role == .viewer ? "rectangle.portrait.and.arrow.right" : "trash"
                        )
                        Spacer()
                    }
                }
            }
            .listRowBackground(AppTheme.surface)
        }
        .listStyle(.insetGrouped)
        .appScreenBackground()
        .navigationTitle(group.name)
        // No `navigationDestination(for: Session.self)` here on purpose. This
        // view is pushed inside GroupsListView's NavigationStack, which already
        // declares one; two registrations for the same type in one stack is
        // undefined behaviour, and the innermost winning made inbox rows resolve
        // to the wrong screen and only correct themselves on the way back out.
        // The root's registration serves this screen's session rows too.
        .sheet(item: $resumingSession) { session in
            ResumeSessionFlowView(session: session)
        }
        .sessionDeleteConfirmation($sessionToDelete)
        .confirmationDialog(
            playerToRemove.map { "Remove \($0.name)?" } ?? "Remove player?",
            isPresented: Binding(
                get: { playerToRemove != nil },
                set: { if !$0 { playerToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let playerToRemove { removePlayer(playerToRemove) }
                playerToRemove = nil
            }
            Button("Cancel", role: .cancel) { playerToRemove = nil }
        } message: {
            Text(removePlayerMessage)
        }
        // Pops before the model goes away: this view holds `group` via
        // @Bindable and would fault on the next render if it outlived it.
        .groupDeleteConfirmation($groupToDelete) { dismiss() }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Shares a picture of the standings, not the group itself —
                // inviting now has a button of its own in the list, and this is
                // the thing people were doing by hand anyway: screenshotting
                // this screen and pasting it into the group chat. Pointless with
                // an empty roster, hence disabled.
                if group.canEdit {
                    Button {
                        isPresentingScreenshotSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(group.players.isEmpty)
                    .accessibilityLabel("Share a screenshot of the standings")
                    Button {
                        isPresentingNewSession = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Only while unanswered. Once you've picked, this disappears and the
            // roster footer carries the answer instead — a permanent bar for a
            // one-time decision is just clutter.
            if claimedPlayerID == nil && !group.players.isEmpty {
                ClaimPromptBar(isOrganizer: group.canEdit) {
                    isPresentingClaimSheet = true
                }
            }
        }
        .sheet(isPresented: $isPresentingNewSession) {
            NewSessionFlowView(group: group)
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            ShareGroupSheet(group: group)
        }
        .sheet(isPresented: $isPresentingScreenshotSheet) {
            GroupScreenshotShareSheet(
                snapshot: GroupShareSnapshot(group: group, claimedPlayerID: claimedPlayerID)
            )
        }
        .sheet(isPresented: $isPresentingClaimSheet) {
            ClaimPlayerSheet(group: group, onClaimChanged: refreshClaim)
        }
        .alert("New player", isPresented: $isAddingPlayer) {
            TextField("Name", text: $newPlayerName)
            Button("Cancel", role: .cancel) { newPlayerName = "" }
            Button("Add") {
                let trimmed = newPlayerName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let player = Player(name: trimmed)
                    group.players.append(player)
                    GroupSyncService.shared.pushSnapshotIfShared(group)
                }
                newPlayerName = ""
            }
        }
        .onAppear {
            appState.selectedGroup = group
            refreshClaim()
            if group.role == .viewer {
                Task { await refresh() }
                GroupSyncService.shared.startRealtimeSync(groupId: group.id, context: modelContext)
            }
        }
        .onDisappear {
            if group.role == .viewer {
                GroupSyncService.shared.stopRealtimeSync(groupId: group.id)
            }
        }
    }

    private func sessionRow(for session: Session) -> some View {
        SessionHistoryRow(
            session: session,
            subtitle: session.usesBank ? "Bank \u{00B7} \(session.bankPlayer?.name ?? "\u{2014}")" : "No bank",
            resumingSession: $resumingSession,
            sessionToDelete: $sessionToDelete
        )
    }

    private var sortedSessions: [Session] {
        group.sessions.sorted { $0.date > $1.date }
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        try? await GroupSyncService.shared.pullSnapshot(groupId: group.id, context: modelContext)
        refreshClaim()
    }

    /// Name of the player this device has claimed, so the roster footer can
    /// state the current answer ("You're Warren") rather than only the question.
    private var claimedPlayerName: String? {
        guard let claimedPlayerID else { return nil }
        return group.players.first { $0.id == claimedPlayerID }?.name
    }

    /// Only the organizer removes people, and never themselves — you can't
    /// delete the identity the whole group is anchored to (viewers read
    /// `adminPlayerID` to know which seat is reserved), and removing yourself
    /// mid-game is far more likely a misfire than an intent.
    private func canRemove(_ player: Player) -> Bool {
        group.canEdit
            && player.id != claimedPlayerID
            && player.id != group.adminPlayerID
    }

    private var removePlayerMessage: String {
        guard let playerToRemove else { return "" }
        let count = playerToRemove.entries.count
        guard count > 0 else { return "They'll be taken off the roster." }
        return "This also deletes their buy-ins and results from \(count) session\(count == 1 ? "" : "s")."
    }

    private func removePlayer(_ player: Player) {
        guard canRemove(player) else { return }
        // SwiftData nullifies SessionEntry.player instead of cascading, which
        // would strand entries belonging to nobody — and `pushSnapshot` silently
        // drops those, so they'd persist locally while vanishing for viewers.
        // Delete them outright; their buy-ins cascade from the entry.
        for entry in player.entries {
            modelContext.delete(entry)
        }
        modelContext.delete(player)
        // Mirrors the removal (and the orphan sweep) to anyone watching.
        GroupSyncService.shared.pushSnapshotIfShared(group)
        refreshClaim()
    }

    private func refreshClaim() {
        claimedPlayerID = PlayerClaimStore.validClaimedPlayerID(for: group)
    }
}

/// The group screen's main call to action: a full-width, filled banner rather
/// than another outlined pill.
///
/// Everything else on this screen is a card on charcoal, so the one action that
/// grows the group is the one thing painted in the accent — you shouldn't have
/// to read the screen to find it.
private struct InviteFriendsCard: View {
    let needsClaim: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.2.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Color.white.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Invite your friends")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(needsClaim
                     ? "Pick which player you are first"
                     : "Send a code so they can follow every game")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Bottom prompt asking who this device is, shown only until it's answered.
///
/// This replaces a toolbar glyph: "which player are you?" is a question about
/// identity, and no icon asks a question. For the organizer it also names the
/// thing it's blocking, since their answer is what unlocks inviting.
private struct ClaimPromptBar: View {
    let isOrganizer: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Which player are you?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(isOrganizer
                         ? "Pick yourself to start inviting people."
                         : "Pick yourself to highlight your results.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .cardBackground()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}

/// Small status row shown atop a viewer's read-only group: last-synced time,
/// a manual refresh affordance, and a friendly note while the server wakes up.
private struct ViewerSyncBanner: View {
    @Bindable var group: GameGroup
    @Binding var isRefreshing: Bool
    let refresh: () async -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Viewing read-only")
                    .font(.footnote.weight(.medium))
                if let lastSyncedAt = group.lastSyncedAt {
                    Text("Synced \(lastSyncedAt.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Waiting for first sync…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isRefreshing {
                ProgressView()
            } else {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .cardBackground()
    }
}
