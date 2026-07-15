import SwiftUI
import SwiftData

struct SettlementView: View {
    @Bindable var session: Session
    var onDone: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var isEditingSession = false

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
            }
            if let onDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $isEditingSession) {
            EditSessionView(session: session)
        }
    }

    private var canEdit: Bool { session.group?.canEdit ?? true }

    private func transferRow(for transfer: Transfer) -> some View {
        let payment = payment(for: transfer)
        return Button {
            guard canEdit else { return }
            payment.isPaid.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: payment.isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(payment.isPaid ? AppTheme.accent : Color.secondary.opacity(0.5))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(transfer.from.name)
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(transfer.to.name)
                    }
                    .font(.body.weight(.medium))
                    // Bank sessions list each player twice, once per direction;
                    // without this they're two identical-looking rows.
                    if let note = transfer.note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
        .disabled(!canEdit)
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

}
