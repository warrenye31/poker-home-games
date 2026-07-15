import SwiftUI
import SwiftData

struct LiveSessionView: View {
    @Bindable var session: Session
    var onEnd: () -> Void

    @State private var customAmountEntry: SessionEntry?
    @State private var customAmountText = ""
    @State private var isEditingSession = false

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
                            Text(countLabel(entry.buyIns.count, "buy-in"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        MoneyText(amount: entry.totalBuyIn, style: .callout)
                        if canEdit {
                            Menu {
                                Button("Add \(CurrencyFormatter.string(from: session.standardBuyIn))") {
                                    entry.buyIns.append(BuyIn(amount: session.standardBuyIn))
                                    pushIfShared()
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
        .navigationTitle(session.displayName)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isEditingSession = true
                    } label: {
                        Image(systemName: "pencil.circle")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("End session") { onEnd() }
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $isEditingSession) {
            EditSessionView(session: session)
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
                    pushIfShared()
                }
                customAmountText = ""
            }
        }
    }

    private var canEdit: Bool { session.group?.canEdit ?? true }

    private var totalBuyInsCount: Int {
        session.entries.reduce(0) { $0 + $1.buyIns.count }
    }

    private func pushIfShared() {
        if let group = session.group {
            GroupSyncService.shared.pushSnapshotIfShared(group)
        }
    }
}
