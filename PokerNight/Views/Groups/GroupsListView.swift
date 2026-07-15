import SwiftUI
import SwiftData

struct GroupsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameGroup.createdDate, order: .reverse) private var groups: [GameGroup]
    @State private var isPresentingNewGroup = false
    @State private var isPresentingJoinGroup = false
    @State private var groupToDelete: GameGroup?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(groups) { group in
                        NavigationLink(value: group) {
                            GroupRow(group: group)
                        }
                        // Context menu, not swipe: swipe buttons misalign
                        // against the card rows from .cardRowContainer(), and
                        // deleting a whole group deserves a confirmation —
                        // same pattern as session rows.
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
            .confirmationDialog(
                groupToDelete?.role == .viewer ? "Leave this group?" : "Delete this group?",
                isPresented: Binding(
                    get: { groupToDelete != nil },
                    set: { if !$0 { groupToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(groupToDelete?.role == .viewer ? "Leave" : "Delete", role: .destructive) {
                    if let group = groupToDelete {
                        GroupSyncService.shared.leaveGroup(group)
                        modelContext.delete(group)
                    }
                    groupToDelete = nil
                }
                Button("Cancel", role: .cancel) { groupToDelete = nil }
            } message: {
                Text(groupToDelete?.role == .viewer
                    ? "This removes the group from your device. The host's data isn't affected."
                    : "This permanently removes the group, its players, and all sessions.")
            }
            .listStyle(.insetGrouped)
            .appScreenBackground()
            .navigationTitle("Groups")
            .navigationDestination(for: GameGroup.self) { group in
                GroupDetailView(group: group)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isPresentingJoinGroup = true
                    } label: {
                        Image(systemName: "person.badge.key")
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
            .overlay {
                if groups.isEmpty {
                    ContentUnavailableView(
                        "No groups yet",
                        systemImage: "person.3",
                        description: Text("Create a group for your regular home game.")
                    )
                }
            }
        }
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
