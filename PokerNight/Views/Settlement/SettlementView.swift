import SwiftUI

struct SettlementView: View {
    let session: Session
    var onDone: (() -> Void)?

    private var transfers: [Transfer] {
        SettlementCalculator.calculate(session: session)
    }

    var body: some View {
        List {
            Section("Session") {
                ForEach(session.entries) { entry in
                    HStack {
                        Text(entry.player?.name ?? "Unknown")
                        Spacer()
                        Text(CurrencyFormatter.string(from: entry.net))
                            .foregroundStyle(entry.net < 0 ? .secondary : Color.accentColor)
                    }
                }
            }

            Section(session.usesBank ? "Bank settlement" : "Who pays who") {
                if transfers.isEmpty {
                    Text("Everyone's even")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(transfers) { transfer in
                        HStack {
                            Text(transfer.from.name)
                            Image(systemName: "arrow.right")
                                .foregroundStyle(Color.accentColor)
                            Text(transfer.to.name)
                            Spacer()
                            Text(CurrencyFormatter.string(from: transfer.amount))
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }

            Section {
                ShareLink(item: summaryText) {
                    Label("Share summary", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("Settlement")
        .toolbar {
            if let onDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }

    private var summaryText: String {
        var lines = ["\(session.date.formatted(date: .abbreviated, time: .omitted)) settlement:"]
        for transfer in transfers {
            lines.append("\(transfer.from.name) pays \(transfer.to.name) \(CurrencyFormatter.string(from: transfer.amount))")
        }
        return lines.joined(separator: "\n")
    }
}
