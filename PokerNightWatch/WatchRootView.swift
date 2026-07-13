import SwiftUI
import SwiftData

/// Entry point for the watch app: finds whatever session is currently
/// active across the synced groups and drops straight into the buy-in
/// screen for it, since that's the one thing worth doing from the wrist.
struct WatchRootView: View {
    @Query(sort: \GameGroup.name) private var groups: [GameGroup]
    @State private var selectedSessionID: PersistentIdentifier?

    var body: some View {
        NavigationStack {
            Group {
                if let session = selectedSession {
                    WatchBuyInView(session: session)
                        .toolbar {
                            if activeSessions.count > 1 {
                                ToolbarItem(placement: .topBarTrailing) {
                                    sessionSwitcher
                                }
                            }
                        }
                } else {
                    ContentUnavailableView(
                        "No active session",
                        systemImage: "suit.spade",
                        description: Text("Start a session on your phone first.")
                    )
                }
            }
        }
    }

    private var activeSessions: [Session] {
        groups.flatMap(\.sessions).filter { $0.status == .active }
    }

    private var selectedSession: Session? {
        if let id = selectedSessionID, let match = activeSessions.first(where: { $0.persistentModelID == id }) {
            return match
        }
        return activeSessions.first
    }

    private var sessionSwitcher: some View {
        Menu {
            ForEach(activeSessions) { session in
                Button(session.group?.name ?? "Session") {
                    selectedSessionID = session.persistentModelID
                }
            }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
        }
    }
}
