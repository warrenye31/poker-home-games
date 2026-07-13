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
            Section("Roster") {
                ForEach(group.players) { player in
                    Text(player.name)
                }
                Button {
                    isAddingPlayer = true
                } label: {
                    Label("Add player", systemImage: "person.badge.plus")
                }
            }

            Section("Session history") {
                if sortedSessions.isEmpty {
                    Text("No sessions yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedSessions) { session in
                        NavigationLink(value: session) {
                            SessionRow(session: session)
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationDestination(for: Session.self) { session in
            SettlementView(session: session)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
            VStack(alignment: .leading, spacing: 4) {
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.body.weight(.medium))
                Text(session.usesBank ? "Bank: \(session.bankPlayer?.name ?? "-")" : "No bank")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(CurrencyFormatter.string(from: session.totalBuyIns))
                .foregroundStyle(Color.accentColor)
                .font(.body.weight(.medium))
        }
    }
}
