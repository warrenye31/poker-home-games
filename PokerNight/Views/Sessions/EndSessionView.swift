import SwiftUI
import SwiftData

struct EndSessionView: View {
    @Bindable var session: Session
    var onFinish: () -> Void

    @State private var cashOutText: [PersistentIdentifier: String] = [:]

    var body: some View {
        List {
            Section("Final stacks") {
                ForEach(session.entries) { entry in
                    HStack {
                        Text(entry.player?.name ?? "Unknown")
                        Spacer()
                        TextField("Cash out", text: binding(for: entry))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
            }

            Section {
                balanceBanner
            }
        }
        .navigationTitle("End session")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Finish") {
                    session.status = .completed
                    onFinish()
                }
                .disabled(!session.isBalanced)
            }
        }
    }

    private func binding(for entry: SessionEntry) -> Binding<String> {
        Binding(
            get: { cashOutText[entry.persistentModelID] ?? "" },
            set: { newValue in
                cashOutText[entry.persistentModelID] = newValue
                entry.cashOut = Decimal(string: newValue)
            }
        )
    }

    private var difference: Decimal {
        session.totalCashOuts - session.totalBuyIns
    }

    @ViewBuilder
    private var balanceBanner: some View {
        if session.entries.contains(where: { $0.cashOut == nil }) {
            Label("Enter every player's final stack", systemImage: "exclamationmark.circle")
                .foregroundStyle(.secondary)
        } else if difference == 0 {
            Label("Balanced", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
        } else {
            Label("Off by \(CurrencyFormatter.string(from: abs(difference)))", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.accentColor)
        }
    }
}
