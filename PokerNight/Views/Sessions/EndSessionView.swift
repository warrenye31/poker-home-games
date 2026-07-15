import SwiftUI
import SwiftData

struct EndSessionView: View {
    @Bindable var session: Session
    var onFinish: () -> Void

    @State private var cashOutText: [PersistentIdentifier: String] = [:]
    @State private var isFinishing = false

    var body: some View {
        List {
            Section {
                summaryCard
                    .listRowBackground(bannerBackground)
            }

            Section {
                ForEach(session.entries) { entry in
                    HStack(spacing: 14) {
                        Monogram(name: entry.player?.name ?? "?", size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.player?.name ?? "Unknown")
                                .font(.body.weight(.medium))
                            Text("Buy-in \(CurrencyFormatter.string(from: entry.totalBuyIn))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        CursorEndTextField(
                            placeholder: "Cash out",
                            text: binding(for: entry),
                            keyboardType: .decimalPad,
                            alignment: .trailing,
                            style: .money()
                        )
                        .frame(width: 96)
                        .disabled(!canEdit)
                        .inputFieldStyle()
                        .onChange(of: cashOutText[entry.persistentModelID] ?? "") { _, newValue in
                            entry.cashOut = Decimal(string: newValue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(AppTheme.surface)
            } header: {
                SectionLabel("Final stacks")
            }
        }
        .listStyle(.insetGrouped)
        .appScreenBackground()
        .navigationTitle("End session")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Finish") {
                    // Hard gate: never advance to settlement on an unbalanced
                    // session, even if the disabled state is somehow bypassed.
                    // `isFinishing` gates re-entrancy: spam-tapping before the
                    // navigation push completes used to append a duplicate
                    // `.settlement` step per tap, stacking repeat settlement
                    // screens on the nav path and re-firing the group sync push.
                    guard session.isBalanced, !isFinishing else { return }
                    isFinishing = true
                    session.status = .completed
                    if let group = session.group {
                        GroupSyncService.shared.pushSnapshotIfShared(group)
                    }
                    onFinish()
                }
                .fontWeight(.semibold)
                .disabled(!session.isBalanced || !canEdit || isFinishing)
            }
        }
        .sensoryFeedback(trigger: session.isBalanced) { _, isBalanced in
            isBalanced ? .success : nil
        }
        .onAppear(perform: handleAppear)
    }

    private func handleAppear() {
        seedCashOutTextFromModel()
        // SwiftUI preserves this view's @State at its slot in the nav path
        // when a Finish tap pushes Settlement on top of it, rather than
        // tearing it down. Without resetting here, navigating back to a still
        // -active session after a successful Finish would find `isFinishing`
        // still `true` from before and the button permanently disabled.
        isFinishing = false
    }

    /// `cashOutText` starts empty every time this view is (re)created, but
    /// `entry.cashOut` may already hold a value — either from a previous visit
    /// to this screen, or from a keystroke that reached the model via
    /// `.onChange` right before the app was backgrounded/crashed and SwiftData
    /// autosaved. Without this, the field renders blank while the summary
    /// above still totals the stale model value, e.g. showing "$100 over the
    /// pot" with every field visibly empty.
    private func seedCashOutTextFromModel() {
        for entry in session.entries where cashOutText[entry.persistentModelID] == nil {
            if let cashOut = entry.cashOut {
                cashOutText[entry.persistentModelID] = "\(cashOut)"
            }
        }
    }

    private var canEdit: Bool { session.group?.canEdit ?? true }

    private var difference: Decimal {
        session.totalCashOuts - session.totalBuyIns
    }
    // MARK: - Summary

    @ViewBuilder
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                statColumn(title: "Total buy-in", amount: session.totalBuyIns, role: .neutral)
                Divider().frame(height: 42)
                statColumn(title: remainingTitle, amount: abs(remaining), role: remaining == 0 ? .neutral : .accent)
            }
            balanceStatus
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func statColumn(title: String, amount: Decimal, role: MoneyText.Role) -> some View {
        VStack(spacing: 4) {
            SectionLabel(title)
            MoneyText(amount: amount, role: role, style: .title2)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var balanceStatus: some View {
        if !allStacksEntered {
            Label("Enter every player's final stack", systemImage: "exclamationmark.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else if remaining == 0 {
            Label("Balanced", systemImage: "checkmark.circle.fill")
                .font(.callout.weight(.medium))
        } else {
            Label("Off by \(CurrencyFormatter.string(from: abs(remaining)))", systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.medium))
                .foregroundStyle(AppTheme.accent)
        }
    }

    // MARK: - Derived state

    /// Cash still unaccounted for: what went in, minus every stack entered so
    /// far. Positive means stacks are still short; negative means they overshoot
    /// the pot. Recomputes live as each field is edited.
    private var remaining: Decimal {
        session.totalBuyIns - session.totalCashOuts
    }

    private var allStacksEntered: Bool {
        !session.entries.isEmpty && session.entries.allSatisfy { $0.cashOut != nil }
    }

    private var remainingTitle: String {
        if remaining > 0 { return "Left to cash out" }
        if remaining < 0 { return "Over the pot" }
        return "Remaining"
    }

    private var bannerBackground: Color {
        allStacksEntered && remaining != 0 ? AppTheme.accent.opacity(0.12) : AppTheme.surface
    }

    // MARK: - Input

    /// Pure text binding — it only touches local `@State`. Syncing the parsed
    /// value back to the model happens in `.onChange` instead, so the field
    /// isn't re-rendered mid-keystroke (which reset the cursor to the front and
    /// made new digits land before the existing ones).
    private func binding(for entry: SessionEntry) -> Binding<String> {
        Binding(
            get: { cashOutText[entry.persistentModelID] ?? "" },
            set: { cashOutText[entry.persistentModelID] = $0 }
        )
    }
}
