import SwiftUI
import SwiftData

struct SessionsHomeView: View {
    @Environment(AppState.self) private var appState

    @State private var resumingSession: Session?
    @State private var sessionToDelete: Session?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(appState.selectedGroup?.name ?? "Sessions")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        GroupSwitcherMenu()
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let group = appState.selectedGroup {
            let sessions = group.sessions.sorted(by: { $0.date > $1.date })
            List {
                Section {
                    ForEach(sessions) { session in
                        sessionRow(for: session)
                    }
                    .cardRowContainer()
                }
            }
            .listStyle(.insetGrouped)
            .appScreenBackground()
            .navigationDestination(for: Session.self) { session in
                SettlementView(session: session)
            }
            .sheet(item: $resumingSession) { session in
                ResumeSessionFlowView(session: session)
            }
            .sessionDeleteConfirmation($sessionToDelete)
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "suit.spade",
                        description: Text("Start one from your group's page.")
                    )
                }
            }
        } else {
            ContentUnavailableView(
                "No group selected",
                systemImage: "suit.spade",
                description: Text("Open a group first from the Groups tab.")
            )
            .appScreenBackground()
        }
    }

    private func sessionRow(for session: Session) -> some View {
        SessionHistoryRow(
            session: session,
            subtitle: countLabel(session.entries.count, "player"),
            resumingSession: $resumingSession,
            sessionToDelete: $sessionToDelete
        )
    }
}
