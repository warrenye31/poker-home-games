import SwiftUI
import SwiftData

struct EndSessionView: View {
    @Bindable var session: Session
    var onFinish: () -> Void

    @State private var cashOutText: [PersistentIdentifier: String] = [:]

    var body: some View {
        List {
            Section {
                ForEach(session.entries) { entry in
                    HStack(spacing: 14) {
                        Monogram(name: entry.player?.name ?? "?", size: 34)
                        Text(entry.player?.name ?? "Unknown")
                            .font(.body.weight(.medium))
                        Spacer()
                        TextField("Cash out", text: binding(for: entry))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(AppTheme.money())
                            .monospacedDigit()
                            .frame(width: 100)
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(AppTheme.surface)
            } header: {
                SectionLabel("Final stacks")
            }

            Section {
                balanceBanner
                    .listRowBackground(bannerBackground)
            }
        }
        .listStyle(.insetGrouped)
        .appScreenBackground()
        .navigationTitle("End session")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Finish") {
                    session.status = .completed
                    onFinish()
                }
                .fontWeight(.semibold)
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

    private var isOffBalance: Bool {
        session.entries.allSatisfy { $0.cashOut != nil } && difference != 0
    }

    private var bannerBackground: Color {
        isOffBalance ? AppTheme.accent.opacity(0.12) : AppTheme.surface
    }

    @ViewBuilder
    private var balanceBanner: some View {
        if session.entries.contains(where: { $0.cashOut == nil }) {
            Label("Enter every player's final stack", systemImage: "exclamationmark.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else if difference == 0 {
            Label("Balanced", systemImage: "checkmark.circle.fill")
                .font(.callout.weight(.medium))
        } else {
            Label("Off by \(CurrencyFormatter.string(from: abs(difference)))", systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.medium))
                .foregroundStyle(AppTheme.accent)
        }
    }
}
