import SwiftUI
import SwiftData

struct SettlementView: View {
    @Bindable var session: Session
    var onDone: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    private var transfers: [Transfer] {
        SettlementCalculator.calculate(session: session)
    }

    var body: some View {
        List {
            Section {
                ForEach(session.entries) { entry in
                    HStack(spacing: 12) {
                        Monogram(name: entry.player?.name ?? "?", size: 32)
                        Text(entry.player?.name ?? "Unknown")
                            .font(.body.weight(.medium))
                        Spacer()
                        MoneyText(amount: entry.net, role: .net, style: .callout)
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(AppTheme.surface)
            } header: {
                SectionLabel("Results")
            }

            Section {
                if transfers.isEmpty {
                    Text("Everyone's even")
                        .foregroundStyle(.secondary)
                        .listRowBackground(AppTheme.surface)
                } else {
                    ForEach(transfers) { transfer in
                        transferRow(for: transfer)
                    }
                    .listRowBackground(AppTheme.surface)
                }
            } header: {
                SectionLabel(session.usesBank ? "Bank settlement" : "Who pays who")
            }

            Section {
                ShareLink(item: summaryText) {
                    Label("Share summary", systemImage: "square.and.arrow.up")
                        .font(.body.weight(.medium))
                }
                .listRowBackground(AppTheme.surface)
            }
        }
        .listStyle(.insetGrouped)
        .appScreenBackground()
        .navigationTitle("Settlement")
        .toolbar {
            if let onDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func transferRow(for transfer: Transfer) -> some View {
        let payment = payment(for: transfer)
        return Button {
            payment.isPaid.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: payment.isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(payment.isPaid ? AppTheme.accent : Color.secondary.opacity(0.5))
                HStack(spacing: 6) {
                    Text(transfer.from.name)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(transfer.to.name)
                }
                .font(.body.weight(.medium))
                .foregroundStyle(payment.isPaid ? Color.secondary : Color.primary)
                .strikethrough(payment.isPaid)
                Spacer()
                MoneyText(
                    amount: transfer.amount,
                    role: payment.isPaid ? .muted : .neutral,
                    style: .callout,
                    strikethrough: payment.isPaid
                )
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func payment(for transfer: Transfer) -> SettlementPayment {
        if let existing = session.settlementPayments.first(where: {
            $0.fromPlayer === transfer.from && $0.toPlayer === transfer.to
        }) {
            return existing
        }
        let created = SettlementPayment(
            session: session,
            fromPlayer: transfer.from,
            toPlayer: transfer.to,
            amount: transfer.amount
        )
        modelContext.insert(created)
        return created
    }

    private var summaryText: String {
        var lines = ["\(session.date.formatted(date: .abbreviated, time: .omitted)) settlement:"]
        for transfer in transfers {
            let paidSuffix = payment(for: transfer).isPaid ? " (paid)" : ""
            lines.append("\(transfer.from.name) pays \(transfer.to.name) \(CurrencyFormatter.string(from: transfer.amount))\(paidSuffix)")
        }
        return lines.joined(separator: "\n")
    }
}
