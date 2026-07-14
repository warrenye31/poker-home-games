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
    @State private var isPresentingClaimSheet = false
    @State private var isRefreshing = false
    @State private var claimedPlayerID: UUID?
    @State private var resumingSession: Session?
    @State private var sessionToDelete: Session?

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
                    HStack(spacing: 14) {
                        Monogram(name: player.name, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(player.name)
                                    .font(.body.weight(.medium))
                                if player.id == claimedPlayerID {
                                    Text("YOU")
                                        .font(.caption2.weight(.bold))
                                        .tracking(0.5)
                                        .foregroundStyle(AppTheme.accent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppTheme.accent.opacity(0.15), in: Capsule())
                                }
                            }
                            Text("\(player.gamesPlayed) game\(player.gamesPlayed == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        MoneyText(amount: player.lifetimeNet, role: .net, style: .callout)
                    }
                    .cardBackground()
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
                SectionLabel("Roster")
            }

            Section {
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
        }
        .listStyle(.insetGrouped)
        .appScreenBackground()
        .navigationTitle(group.name)
        .navigationDestination(for: Session.self) { session in
            SettlementView(session: session)
        }
        .sheet(item: $resumingSession) { session in
            ResumeSessionFlowView(session: session)
        }
        .confirmationDialog(
            "Delete this session?",
            isPresented: Binding(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    modelContext.delete(session)
                }
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
        } message: {
            Text("This permanently removes the session and its buy-ins.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !group.sessions.isEmpty {
                    ShareLink(
                        item: SessionHistoryExport(group: group),
                        preview: SharePreview("\(group.name) sessions")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                Button {
                    isPresentingClaimSheet = true
                } label: {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                }
                if group.canEdit {
                    Button {
                        isPresentingShareSheet = true
                    } label: {
                        Image(systemName: group.isShared ? "person.2.fill" : "person.badge.plus")
                    }
                    Button {
                        isPresentingNewSession = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingNewSession) {
            NewSessionFlowView(group: group)
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            ShareGroupSheet(group: group)
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

    /// Completed sessions push straight to settlement; active ones re-open the
    /// live flow instead, so we never show settlement for an unbalanced game.
    @ViewBuilder
    private func sessionRow(for session: Session) -> some View {
        Group {
            if session.status == .active {
                Button {
                    resumingSession = session
                } label: {
                    SessionRow(session: session)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: session) {
                    SessionRow(session: session)
                }
            }
        }
        // No full swipe / destructive role here: those animate the row out on
        // swipe, but we only want to open the confirmation. Deletion happens
        // for real once the dialog is confirmed.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                sessionToDelete = session
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(AppTheme.accent)
        }
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

    private func refreshClaim() {
        claimedPlayerID = PlayerClaimStore.validClaimedPlayerID(for: group)
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

private struct SessionRow: View {
    let session: Session

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
                Text(session.usesBank ? "Bank \u{00B7} \(session.bankPlayer?.name ?? "\u{2014}")" : "No bank")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MoneyText(amount: session.totalBuyIns, style: .callout)
        }
        .cardBackground()
    }
}
