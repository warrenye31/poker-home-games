import SwiftUI
import SwiftData

struct LiveSessionView: View {
    @Bindable var session: Session
    var onEnd: () -> Void

    @AppStorage("defaultBuyIn") private var defaultBuyIn: Double = 20
    @State private var customAmountEntry: SessionEntry?
    @State private var customAmountText = ""

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Pot")
                    Spacer()
                    Text(CurrencyFormatter.string(from: session.totalBuyIns))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }

            Section("Players") {
                ForEach(session.entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.player?.name ?? "Unknown")
                            Text("\(entry.buyIns.count) buy-in\(entry.buyIns.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(CurrencyFormatter.string(from: entry.totalBuyIn))
                            .font(.body.weight(.medium))
                        Menu {
                            Button("Add \(CurrencyFormatter.string(from: Decimal(defaultBuyIn)))") {
                                entry.buyIns.append(BuyIn(amount: Decimal(defaultBuyIn)))
                            }
                            Button("Custom amount") {
                                customAmountEntry = entry
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .omitted))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("End session") { onEnd() }
            }
        }
        .alert(
            "Custom buy-in",
            isPresented: Binding(
                get: { customAmountEntry != nil },
                set: { if !$0 { customAmountEntry = nil } }
            )
        ) {
            TextField("Amount", text: $customAmountText)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { customAmountText = "" }
            Button("Add") {
                if let entry = customAmountEntry, let value = Decimal(string: customAmountText) {
                    entry.buyIns.append(BuyIn(amount: value))
                }
                customAmountText = ""
            }
        }
    }
}
