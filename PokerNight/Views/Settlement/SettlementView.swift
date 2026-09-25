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
                ForEach(session.seatedEntries) { entry in
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
        .onAppear(perform: reconcilePayments)
        // Editing the session from the toolbar can reshape the settlement
        // while this screen is up.
        .onChange(of: transferSignature) { _, _ in reconcilePayments() }
    }

    private var canEdit: Bool { session.group?.canEdit ?? true }

    private func transferRow(for transfer: Transfer) -> some View {
        // `nil` only on a viewer whose last pull predates this settlement, or
        // for the instant before `reconcilePayments` runs — unpaid either way.
        let payment = session.settlementPayments.first { $0.matches(transfer) }
        let isPaid = payment?.isPaid ?? false
        return Button {
            guard canEdit, let payment else { return }
            payment.isPaid.toggle()
            pushIfShared()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isPaid ? AppTheme.accent : Color.secondary.opacity(0.5))
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
                .foregroundStyle(isPaid ? Color.secondary : Color.primary)
                .strikethrough(isPaid)
                Spacer()
                MoneyText(
                    amount: transfer.amount,
                    role: isPaid ? .muted : .neutral,
                    style: .callout,
                    strikethrough: isPaid
                )
            }
            .padding(.vertical, 4)
            .fullRowTapTarget()
        }
        .buttonStyle(.plain)
        .disabled(!canEdit)
    }

    /// Changes whenever the settlement does — who pays whom, or how much.
    private var transferSignature: String {
        transfers.map { "\($0.id):\($0.amount)" }.joined(separator: ",")
    }

    /// Only the organizer writes payment records. A viewer's copies come from
    /// the server, and any row a viewer created here would be swept away by
    /// its next pull anyway. An unfinished session has no settlement yet —
    /// its "transfers" are just whatever the half-entered cash-outs imply.
    private func reconcilePayments() {
        guard canEdit, session.status == .completed else { return }
        if SettlementPayment.reconcile(session: session, transfers: transfers, context: modelContext) {
            pushIfShared()
        }
    }

    private func pushIfShared() {
        if let group = session.group {
            GroupSyncService.shared.pushSnapshotIfShared(group)
        }
    }
}
