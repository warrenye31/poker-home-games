import SwiftUI
import SwiftData

struct GroupsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameGroup.createdDate, order: .reverse) private var groups: [GameGroup]
    @State private var isPresentingNewGroup = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    NavigationLink(value: group) {
                        GroupRow(group: group)
                    }
                }
                .onDelete(perform: deleteGroups)
            }
            .listStyle(.plain)
            .navigationTitle("Groups")
            .navigationDestination(for: GameGroup.self) { group in
                GroupDetailView(group: group)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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

    private func deleteGroups(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(groups[index])
        }
    }
}

private struct GroupRow: View {
    let group: GameGroup

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        let count = group.players.count
        let playerText = "\(count) player\(count == 1 ? "" : "s")"
        if let last = group.sessions.map(\.date).max() {
            return "\(playerText) \u{00B7} last played \(last.formatted(date: .abbreviated, time: .omitted))"
        }
        return playerText
    }
}
