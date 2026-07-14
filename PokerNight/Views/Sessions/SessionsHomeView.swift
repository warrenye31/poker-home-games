import SwiftUI
import SwiftData

struct SessionsHomeView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \GameGroup.name) private var groups: [GameGroup]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(appState.selectedGroup?.name ?? "Sessions")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        groupSwitcher
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
                        NavigationLink(value: session) {
                            SessionSummaryRow(session: session)
                        }
                    }
                    .cardRowContainer()
                }
            }
            .listStyle(.insetGrouped)
            .appScreenBackground()
            .navigationDestination(for: Session.self) { session in
                SettlementView(session: session)
            }
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

    private var groupSwitcher: some View {
        Menu {
            ForEach(groups) { group in
                Button(group.name) { appState.selectedGroup = group }
            }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
        }
    }
}

private struct SessionSummaryRow: View {
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
                Text("\(session.entries.count) player\(session.entries.count == 1 ? "" : "s")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MoneyText(amount: session.totalBuyIns, style: .callout)
        }
        .cardBackground()
    }
}
