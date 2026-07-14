import SwiftUI
import SwiftData
import WidgetKit

struct EndSessionView: View {
    @Bindable var session: Session
    var onFinish: () -> Void

    @State private var cashOutText: [PersistentIdentifier: String] = [:]

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
                        TextField("Cash out", text: binding(for: entry))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(AppTheme.money())
                            .monospacedDigit()
                            .frame(width: 96)
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
                    guard session.isBalanced else { return }
                    session.status = .completed
                    WidgetCenter.shared.reloadTimelines(ofKind: SharedModelContainer.widgetKind)
                    onFinish()
                }
                .fontWeight(.semibold)
                .disabled(!session.isBalanced)
            }
        }
        .sensoryFeedback(trigger: session.isBalanced) { _, isBalanced in
            isBalanced ? .success : nil
        }
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
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
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
