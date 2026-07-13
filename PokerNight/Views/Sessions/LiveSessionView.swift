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
                VStack(spacing: 6) {
                    SectionLabel("Pot")
                    MoneyText(amount: session.totalBuyIns, style: .largeTitle)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .listRowBackground(AppTheme.surface)
            }

            Section {
                ForEach(session.entries) { entry in
                    HStack(spacing: 14) {
                        Monogram(name: entry.player?.name ?? "?", size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.player?.name ?? "Unknown")
                                .font(.body.weight(.medium))
                            Text("\(entry.buyIns.count) buy-in\(entry.buyIns.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        MoneyText(amount: entry.totalBuyIn, style: .callout)
                        Menu {
                            Button("Add \(CurrencyFormatter.string(from: Decimal(defaultBuyIn)))") {
                                entry.buyIns.append(BuyIn(amount: Decimal(defaultBuyIn)))
                            }
                            Button("Custom amount") {
                                customAmountEntry = entry
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(AppTheme.surface)
            } header: {
                SectionLabel("Players")
            }
        }
        .listStyle(.insetGrouped)
        .appScreenBackground()
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .omitted))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("End session") { onEnd() }
                    .fontWeight(.semibold)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: totalBuyInsCount)
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

    private var totalBuyInsCount: Int {
        session.entries.reduce(0) { $0 + $1.buyIns.count }
    }
}
