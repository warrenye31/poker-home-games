import SwiftUI

/// A poker chip drawn from the color name alone — filled disc, edge spots, and
/// an inset ring. Cheap enough to render a dozen of, and it makes the guide
/// scannable at a glance instead of a wall of dollar amounts.
struct ChipSwatch: View {
    let color: ChipColor
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(fill)
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(edge)
                    .frame(width: size * 0.13, height: size * 0.19)
                    .offset(y: -size * 0.405)
                    .rotationEffect(.degrees(Double(index) / 6 * 360))
            }
            Circle()
                .strokeBorder(edge.opacity(0.85), lineWidth: size * 0.055)
                .padding(size * 0.17)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
    }

    private var fill: Color {
        switch color {
        case .white: Color(white: 0.92)
        case .red: Color(red: 0.78, green: 0.19, blue: 0.21)
        case .green: Color(red: 0.11, green: 0.47, blue: 0.31)
        case .black: Color(white: 0.13)
        }
    }

    /// Edge spots contrast against the disc: dark on the white chip, white on
    /// everything else, matching how real sets are printed.
    private var edge: Color {
        color == .white ? Color(white: 0.45) : Color(white: 0.96)
    }
}

/// Tells the organizer what each chip color is worth for these stakes, what a
/// starting stack looks like, and how many chips to physically put on the table.
///
/// Nothing here is stored — it's all derived from the session's blinds and
/// buy-in, so changing the stakes and reopening this shows a new plan.
struct ChipGuideView: View {
    let recommendation: ChipRecommendation

    @Environment(\.dismiss) private var dismiss
    /// Seeded from the session's roster, then adjustable — the host often wants
    /// to know what one more arrival would cost them in chips.
    @State private var playerCount: Int

    init(recommendation: ChipRecommendation, initialPlayerCount: Int) {
        self.recommendation = recommendation
        _playerCount = State(initialValue: min(max(initialPlayerCount, 2), 12))
    }

    var body: some View {
        NavigationStack {
            List {
                stakesSection
                denominationsSection
                startingStackSection
                tableSection
                notesSection
            }
            .listStyle(.insetGrouped)
            .appScreenBackground()
            .navigationTitle("Chip guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var stakesSection: some View {
        Section {
            HStack(spacing: 0) {
                stat(title: "Blinds", value: blindsLabel)
                Divider().frame(height: 40)
                stat(title: "Buy-in", value: CurrencyFormatter.string(from: recommendation.buyIn))
            }
            .padding(.vertical, 6)
            .listRowBackground(AppTheme.surface)
        }
    }

    private var denominationsSection: some View {
        Section {
            ForEach(recommendation.denominations) { chip in
                HStack(spacing: 14) {
                    ChipSwatch(color: chip.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chip.color.name)
                            .font(.body.weight(.medium))
                        Text(chip == recommendation.topChip ? "Rebuys only" : chip.color.positionLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    MoneyText(amount: chip.value, style: .title3)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(AppTheme.surface)
        } header: {
            SectionLabel("What each chip is worth")
        } footer: {
            Text("Colors are the usual convention — if your set runs blue instead of green, keep the order and the values still hold.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var startingStackSection: some View {
        Section {
            ForEach(recommendation.denominations.filter { $0.startingCount > 0 }) { chip in
                HStack(spacing: 14) {
                    ChipSwatch(color: chip.color, size: 30)
                    Text("\(chip.startingCount) × \(chip.label)")
                        .font(.body.weight(.medium))
                        .monospacedDigit()
                    Spacer()
                    MoneyText(amount: chip.startingValue, role: .muted, style: .callout)
                }
                .padding(.vertical, 2)
            }

            HStack {
                Text("One stack")
                    .font(.body.weight(.semibold))
                Spacer()
                MoneyText(amount: recommendation.stackValue, role: .accent, style: .callout)
            }
        } header: {
            SectionLabel("Each player starts with")
        } footer: {
            Text("\(countLabel(recommendation.chipsPerStack, "chip")) per stack. \(recommendation.topChip.color.name)s stay with the host for rebuys — \(countLabel(recommendation.rebuyInTopChips, "chip")) buys back in.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .listRowBackground(AppTheme.surface)
    }

    private var tableSection: some View {
        Section {
            Stepper(value: $playerCount, in: 2...12) {
                HStack {
                    Text("Players")
                    Spacer()
                    Text("\(playerCount)")
                        .font(AppTheme.money(.body))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(recommendation.denominations) { chip in
                HStack(spacing: 14) {
                    ChipSwatch(color: chip.color, size: 30)
                    Text(chip.color.name)
                    Spacer()
                    Text("\(recommendation.tableCount(for: chip, playerCount: playerCount))")
                        .font(AppTheme.money(.callout))
                        .monospacedDigit()
                }
                .padding(.vertical, 2)
            }

            HStack {
                Text("Total chips")
                    .font(.body.weight(.semibold))
                Spacer()
                Text("\(recommendation.totalChips(playerCount: playerCount))")
                    .font(AppTheme.money(.callout))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.accent)
            }
        } header: {
            SectionLabel("Chips to put out")
        } footer: {
            Text("Includes two rebuys' worth of \(recommendation.topChip.color.name.lowercased())s per player. A 300-chip set covers most of this comfortably.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .listRowBackground(AppTheme.surface)
    }

    private var notesSection: some View {
        Section {
            ForEach(recommendation.notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .listRowBackground(AppTheme.surface)
        } header: {
            SectionLabel("Worth knowing")
        }
    }

    // MARK: - Pieces

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            SectionLabel(title)
            Text(value)
                .font(AppTheme.money(.title3))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var blindsLabel: String {
        guard recommendation.smallBlind > 0 || recommendation.bigBlind > 0 else { return "—" }
        return "\(CurrencyFormatter.blindString(from: recommendation.smallBlind)) / \(CurrencyFormatter.blindString(from: recommendation.bigBlind))"
    }

    /// Plain-text version for the group chat, so nobody has to open the app to
    /// find out what the greens are worth.
    private var shareText: String {
        var lines = ["Chip values — \(blindsLabel) blinds, \(CurrencyFormatter.string(from: recommendation.buyIn)) buy-in", ""]
        for chip in recommendation.denominations {
            let suffix = chip.startingCount > 0 ? " (\(chip.startingCount) per stack)" : " (rebuys)"
            lines.append("\(chip.color.name) = \(chip.label)\(suffix)")
        }
        lines.append("")
        lines.append("One stack = \(CurrencyFormatter.string(from: recommendation.stackValue)) in \(countLabel(recommendation.chipsPerStack, "chip")).")
        return lines.joined(separator: "\n")
    }
}

/// The row that opens the guide, showing the recommended values inline so the
/// common case (a glance at what the chips are worth) needs no tap at all.
struct ChipGuideRow: View {
    let recommendation: ChipRecommendation?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chip denominations")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(recommendation?.summaryLine ?? "Set blinds and a buy-in to see a suggestion")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(recommendation == nil)
    }
}
