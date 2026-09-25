import SwiftUI
import SwiftData

struct LiveSessionView: View {
    @Bindable var session: Session
    var onEnd: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var customAmountEntry: SessionEntry?
    @State private var customAmountText = ""
    @State private var isEditingSession = false
    @State private var showChipGuide = false
    @State private var showAddPlayer = false
    /// The buy-in just added, offered back for a few seconds as "Undo" — a
    /// mis-tap on the wrong player is the most common mistake on this screen.
    @State private var undoToast: UndoToast?

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

                // Mid-game, "what's the green worth?" gets asked more than
                // anything else on this screen — so the answer lives one tap
                // from the pot rather than back in setup.
                ChipGuideRow(recommendation: chipRecommendation) { showChipGuide = true }
                    .listRowBackground(AppTheme.surface)
            }

            Section {
                ForEach(session.seatedEntries) { entry in
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
                                    addBuyIn(session.standardBuyIn, to: entry)
                                }
                                Button("Custom amount") {
                                    customAmountEntry = entry
                                }
                                if let last = latestBuyIn(of: entry) {
                                    Divider()
                                    Button(role: .destructive) {
                                        removeBuyIn(last, from: entry)
                                    } label: {
                                        Label(
                                            "Remove last buy-in (\(CurrencyFormatter.string(from: last.amount)))",
                                            systemImage: "arrow.uturn.backward"
                                        )
                                    }
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

                if canEdit {
                    Button {
                        showAddPlayer = true
                    } label: {
                        Label("Add a player", systemImage: "person.badge.plus")
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(AppTheme.surface)
                }
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
        .sheet(isPresented: $showAddPlayer) {
            AddPlayerToSessionSheet(session: session)
        }
        .sheet(isPresented: $showChipGuide) {
            if let chipRecommendation {
                ChipGuideView(recommendation: chipRecommendation, initialPlayerCount: session.entries.count)
            }
        }
        // Only a buy-in going *in* thumps; taking one back shouldn't feel
        // like adding one.
        .sensoryFeedback(trigger: totalBuyInsCount) { old, new in
            new > old ? .impact(weight: .medium) : nil
        }
        .safeAreaInset(edge: .bottom) {
            if let undoToast {
                undoBar(undoToast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: undoToast?.id)
        .task(id: undoToast?.id) {
            guard undoToast != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            // Cancelled when a newer toast replaces this one; leave that alone.
            guard !Task.isCancelled else { return }
            undoToast = nil
        }
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
                if let entry = customAmountEntry, let value = Decimal(string: customAmountText), value > 0 {
                    addBuyIn(value, to: entry)
                }
                customAmountText = ""
            }
        }
    }

    private var canEdit: Bool { session.group?.canEdit ?? true }

    private var chipRecommendation: ChipRecommendation? {
        ChipRecommendation.recommend(
            smallBlind: session.smallBlind,
            bigBlind: session.bigBlind,
            buyIn: session.standardBuyIn
        )
    }

    private var totalBuyInsCount: Int {
        session.entries.reduce(0) { $0 + $1.buyIns.count }
    }

    // MARK: - Buy-ins

    private struct UndoToast: Identifiable {
        let id = UUID()
        let buyIn: BuyIn
        let entry: SessionEntry
        let playerName: String
    }

    private func addBuyIn(_ amount: Decimal, to entry: SessionEntry) {
        let buyIn = BuyIn(amount: amount)
        entry.buyIns.append(buyIn)
        undoToast = UndoToast(buyIn: buyIn, entry: entry, playerName: entry.player?.name ?? "player")
        pushIfShared()
    }

    /// `buyIns` is a SwiftData relationship with no guaranteed order, so
    /// "last" means newest by timestamp, not the array's tail.
    private func latestBuyIn(of entry: SessionEntry) -> BuyIn? {
        entry.buyIns.max { $0.timestamp < $1.timestamp }
    }

    private func removeBuyIn(_ buyIn: BuyIn, from entry: SessionEntry) {
        entry.buyIns.removeAll { $0 === buyIn }
        modelContext.delete(buyIn)
        if undoToast?.buyIn === buyIn {
            undoToast = nil
        }
        pushIfShared()
    }

    private func undoBar(_ toast: UndoToast) -> some View {
        HStack(spacing: 12) {
            Text("Added \(CurrencyFormatter.string(from: toast.buyIn.amount)) for \(toast.playerName)")
                .font(.callout)
                .lineLimit(1)
            Spacer()
            Button("Undo") {
                removeBuyIn(toast.buyIn, from: toast.entry)
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.hairline)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func pushIfShared() {
        if let group = session.group {
            GroupSyncService.shared.pushSnapshotIfShared(group)
        }
    }
}
