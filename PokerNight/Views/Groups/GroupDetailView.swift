import SwiftUI
import SwiftData

struct GroupDetailView: View {
    @Bindable var group: GameGroup
    @Environment(AppState.self) private var appState
    @State private var isPresentingNewSession = false
    @State private var isAddingPlayer = false
    @State private var newPlayerName = ""

    var body: some View {
        List {
            Section {
                ForEach(group.players) { player in
                    HStack(spacing: 14) {
                        Monogram(name: player.name, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.name)
                                .font(.body.weight(.medium))
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
                        NavigationLink(value: session) {
                            SessionRow(session: session)
                        }
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
                    isPresentingNewSession = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $isPresentingNewSession) {
            NewSessionFlowView(group: group)
        }
        .alert("New player", isPresented: $isAddingPlayer) {
            TextField("Name", text: $newPlayerName)
            Button("Cancel", role: .cancel) { newPlayerName = "" }
            Button("Add") {
                let trimmed = newPlayerName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let player = Player(name: trimmed)
                    group.players.append(player)
                }
                newPlayerName = ""
            }
        }
        .onAppear { appState.selectedGroup = group }
    }

    private var sortedSessions: [Session] {
        group.sessions.sorted { $0.date > $1.date }
    }
}

private struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
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
