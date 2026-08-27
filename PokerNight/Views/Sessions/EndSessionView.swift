import SwiftUI
import SwiftData

struct EndSessionView: View {
    @Bindable var session: Session
    var onFinish: () -> Void

    /// Keyed by `SessionEntry.id` (a stable UUID), **not** `persistentModelID`.
    /// SwiftData hands a newly-inserted model a temporary `PersistentIdentifier`
    /// and remaps it to a permanent one when the context saves — and this screen
    /// writes `entry.cashOut` on every keystroke, so a save can land mid-typing.
    /// After the remap every key here is stale, every lookup returns nil, and the
    /// whole column of fields blanks at once while the summary still totals the
    /// model values. See `GameGroup.id`: persistentModelID is local-only and
    /// must not be used as a durable key.
    @State private var cashOutText: [UUID: String] = [:]
    @State private var isFinishing = false
    @State private var countingEntry: SessionEntry?
    /// Resolved once in `onAppear` rather than on demand: the recommendation is
    /// a small search, and as a computed property it would re-run for every
    /// player row on every keystroke. The stakes can't change from this screen,
    /// so there's nothing to keep it in sync with.
    @State private var chipRecommendation: ChipRecommendation?

    var body: some View {
        List {
            Section {
                summaryCard
                    .listRowBackground(bannerBackground)
            }

            Section {
                ForEach(session.seatedEntries) { entry in
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
                        // Counting a stack by color is the one moment this
                        // screen needs a calculator, and the chip guide already
                        // knows what each color is worth.
                        if canEdit && chipRecommendation != nil {
                            Button {
                                countingEntry = entry
                            } label: {
                                Image(systemName: "circle.hexagongrid.fill")
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Count chips for \(entry.player?.name ?? "player")")
                        }
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
                        .onChange(of: cashOutText[entry.id] ?? "") { _, newValue in
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
        .sheet(
            isPresented: Binding(
                get: { countingEntry != nil },
                set: { if !$0 { countingEntry = nil } }
            )
        ) {
            if let countingEntry, let chipRecommendation {
                ChipCountSheet(
                    recommendation: chipRecommendation,
                    playerName: countingEntry.player?.name ?? "this player"
                ) { total in
                    // Same path a typed cash-out takes: seed the field, and let
                    // its `.onChange` write the model, so the balance banner and
                    // the field can't disagree about what was entered.
                    cashOutText[countingEntry.id] = CurrencyFormatter.plainString(from: total)
                }
            }
        }
        .sensoryFeedback(trigger: session.isBalanced) { _, isBalanced in
            isBalanced ? .success : nil
        }
        .onAppear(perform: handleAppear)
    }

    private func handleAppear() {
        seedCashOutTextFromModel()
        chipRecommendation = ChipRecommendation.recommend(
            smallBlind: session.smallBlind,
            bigBlind: session.bigBlind,
            buyIn: session.standardBuyIn
        )
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
        for entry in session.entries where cashOutText[entry.id] == nil {
            if let cashOut = entry.cashOut {
                cashOutText[entry.id] = "\(cashOut)"
            }
        }
    }

    private var canEdit: Bool { session.group?.canEdit ?? true }

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
            get: { cashOutText[entry.id] ?? "" },
            set: { cashOutText[entry.id] = $0 }
        )
    }
}
