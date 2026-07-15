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
                    PlayerStandingRow(player: player, isYou: player.id == claimedPlayerID)
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
        .sessionDeleteConfirmation($sessionToDelete)
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
