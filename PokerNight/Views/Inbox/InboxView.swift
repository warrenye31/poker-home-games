import SwiftUI
import SwiftData

/// Every unsettled debt involving you, across all groups.
///
/// Reached from the Inbox button on the Groups screen. Rows push through to the
/// settlement they came from, which is where the paid checkbox lives — a
/// reminder you can't act on is just nagging.
struct InboxView: View {
    @Query(sort: \GameGroup.name) private var groups: [GameGroup]

    var body: some View {
        content
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
    }

    private var debts: [OutstandingDebt] {
        DebtInbox.outstanding(in: groups)
    }

    @ViewBuilder
    private var content: some View {
        let debts = debts
        if debts.isEmpty {
            ContentUnavailableView(
                "All settled",
                systemImage: "checkmark.circle",
                description: Text("Nobody owes you, and you don't owe anybody.")
            )
            .appScreenBackground()
        } else {
            // Deliberately no net total. Owing someone $100 and being owed $100
            // by someone else is not "square" — it's two payments that both
            // still have to happen, with two different people. Netting them
            // reports "nothing to do" about a screen whose entire job is to say
            // what's left to do.
            List {
                Section {
                    ForEach(debts) { debt in
                        NavigationLink(value: debt.session) {
                            DebtRow(debt: debt)
                        }
                    }
                    .cardRowContainer()
                } header: {
                    SectionLabel(countLabel(debts.count, "open transaction"))
                }
            }
            .listStyle(.insetGrouped)
            .appScreenBackground()
        }
    }
}

/// One unsettled debt: who, how much, and which game it came from.
struct DebtRow: View {
    let debt: OutstandingDebt

    var body: some View {
        HStack(spacing: 12) {
            Monogram(name: debt.counterparty.name, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(debt.youOwe
                     ? "You owe \(debt.counterparty.name)"
                     : "\(debt.counterparty.name) owes you")
                    .font(.body.weight(.medium))
                // Names the game as well as the group: "which night was this?"
                // is the first thing anyone asks about a stale debt. The note
                // ("Buy-in"/"Cash-out") is what separates the two rows you get
                // opposite the bank in a bank game.
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MoneyText(amount: debt.signedAmount, role: .net, style: .callout)
        }
        .cardBackground()
    }

    private var subtitle: String {
        let where_ = "\(debt.group.name) \u{00B7} \(debt.session.date.formatted(date: .abbreviated, time: .omitted))"
        guard let note = debt.note else { return where_ }
        return "\(note) \u{00B7} \(where_)"
    }
}
