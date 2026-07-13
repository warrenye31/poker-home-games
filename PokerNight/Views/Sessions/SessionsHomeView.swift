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
            List {
                ForEach(group.sessions.sorted(by: { $0.date > $1.date })) { session in
                    NavigationLink(value: session) {
                        SessionSummaryRow(session: session)
                    }
                }
            }
            .navigationDestination(for: Session.self) { session in
                SettlementView(session: session)
            }
        } else {
            ContentUnavailableView(
                "No group selected",
                systemImage: "suit.spade",
                description: Text("Open a group first from the Groups tab.")
            )
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
            Text(session.date.formatted(date: .abbreviated, time: .omitted))
            Spacer()
            Text(CurrencyFormatter.string(from: session.totalBuyIns))
                .foregroundStyle(Color.accentColor)
        }
    }
}
