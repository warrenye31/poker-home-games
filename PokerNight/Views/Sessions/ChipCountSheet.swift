import SwiftUI

/// Turns a pile of chips into a cash-out figure.
///
/// Counting down a stack at the end of the night is the one moment a home game
/// reaches for a calculator: four colors, four multiplications, once per player,
/// with everyone watching. The app already knows what each color is worth, so it
/// can do the arithmetic and hand the result straight to the cash-out field —
/// where the existing balance check catches whatever the count got wrong.
struct ChipCountSheet: View {
    let recommendation: ChipRecommendation
    let playerName: String
    /// Called with the counted total when the organizer accepts it.
    var onUse: (Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var counts: [ChipColor: Int] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 6) {
                        SectionLabel("Counted")
                        MoneyText(amount: total, role: total > 0 ? .accent : .muted, style: .largeTitle)
                        Text(countLabel(chipTotal, "chip"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .listRowBackground(AppTheme.surface)
                }

                Section {
                    ForEach(recommendation.denominations) { chip in
                        HStack(spacing: 14) {
                            ChipSwatch(color: chip.color, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chip.color.name)
                                    .font(.body.weight(.medium))
                                Text(chip.label)
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            // Only once there's something to total — a column of
                            // "$0.00" against every uncounted color is noise.
                            if (counts[chip.color] ?? 0) > 0 {
                                MoneyText(amount: subtotal(for: chip), role: .muted, style: .caption)
                            }
                            CursorEndTextField(
                                placeholder: "0",
                                text: countBinding(for: chip.color),
                                keyboardType: .numberPad,
                                alignment: .trailing,
                                style: .money()
                            )
                            .frame(width: 64)
                            .inputFieldStyle()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(AppTheme.surface)
                } header: {
                    SectionLabel("Chips in front of \(playerName)")
                }
            }
            .listStyle(.insetGrouped)
            .appScreenBackground()
            .navigationTitle("Count chips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use \(CurrencyFormatter.string(from: total))") {
                        onUse(total)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(chipTotal == 0)
                }
            }
        }
    }

    // MARK: - Derived

    private var total: Decimal {
        recommendation.denominations.reduce(Decimal(0)) { $0 + subtotal(for: $1) }
    }

    private var chipTotal: Int {
        counts.values.reduce(0, +)
    }

    private func subtotal(for chip: ChipDenomination) -> Decimal {
        chip.value * Decimal(counts[chip.color] ?? 0)
    }

    // MARK: - Input

    /// Text-backed so the field can be empty rather than showing a placeholder
    /// "0" the organizer has to clear before typing. `CursorEndTextField` only
    /// writes back when the string actually differs, so round-tripping through
    /// `Int` here doesn't fight the cursor mid-keystroke.
    private func countBinding(for color: ChipColor) -> Binding<String> {
        Binding(
            get: { counts[color].map(String.init) ?? "" },
            set: { counts[color] = Int($0.filter(\.isNumber)) }
        )
    }
}
