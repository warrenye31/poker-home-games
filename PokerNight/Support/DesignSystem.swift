import SwiftUI

// MARK: - Money

/// Single rendering path for currency so digits stay rounded, semibold,
/// and fixed-width across the whole app.
struct MoneyText: View {
    enum Role {
        /// Plain amount in primary white.
        case neutral
        /// Signed net: "+$120" in white, "−$45" in red.
        case net
        /// Brand red, reserved for the few hero amounts.
        case accent
        /// Secondary gray, for settled or dimmed rows.
        case muted
    }

    let amount: Decimal
    var role: Role = .neutral
    var style: Font.TextStyle = .body
    var strikethrough = false

    var body: some View {
        Text(role == .net ? CurrencyFormatter.signedString(from: amount) : CurrencyFormatter.string(from: amount))
            .font(AppTheme.money(style))
            .monospacedDigit()
            .strikethrough(strikethrough)
            .foregroundStyle(color)
    }

    private var color: Color {
        switch role {
        case .neutral: .primary
        case .net: amount < 0 ? AppTheme.loss : .primary
        case .accent: AppTheme.accent
        case .muted: .secondary
        }
    }
}

// MARK: - Labels

/// Tracked-uppercase section header used by every list in the app.
struct SectionLabel: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}

/// Badge for sessions that are still running.
struct LivePill: View {
    var body: some View {
        Text("LIVE")
            .font(.caption2.weight(.bold))
            .tracking(1)
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(AppTheme.accent.opacity(0.15), in: Capsule())
    }
}

// MARK: - Monogram

/// Initials avatar — circular for players, rounded-square for groups.
struct Monogram: View {
    enum Kind {
        case player, group
    }

    let name: String
    var kind: Kind = .player
    var size: CGFloat = 36

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .background(shape.fill(Color.white.opacity(0.07)))
            .overlay(shape.stroke(AppTheme.hairline, lineWidth: 1))
    }

    private var shape: AnyShape {
        switch kind {
        case .player: AnyShape(Circle())
        case .group: AnyShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        }
    }

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        guard !letters.isEmpty else { return "?" }
        return letters.map(String.init).joined().uppercased()
    }
}

// MARK: - Screen chrome

extension View {
    /// Hides the default grouped-list background and paints the app's
    /// near-black canvas behind everything.
    func appScreenBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
    }
}

// MARK: - Cards

/// Card chrome shared by every restyled list row: charcoal surface fill,
/// 12pt rounded corners, and a red accent bar on the leading edge.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 14)
            .padding(.trailing, 14)
            .padding(.leading, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(AppTheme.accent)
                    .frame(width: 4)
                    .padding(.vertical, 10)
                    .padding(.leading, 6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension View {
    /// Applies the shared card chrome (surface fill, rounded corners, red accent bar).
    func cardBackground() -> some View {
        modifier(CardBackground())
    }

    /// Configures a List row to render as a free-floating card: clears the
    /// system row background/separator and adds breathing room between cards.
    /// Pair with `.cardBackground()` on the row's content.
    func cardRowContainer() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

// MARK: - Pill buttons

/// Capsule button used for the mockup's pill-style CTAs — filled/red when
/// prominent, outlined/transparent otherwise.
struct PillButtonStyle: ButtonStyle {
    var isProminent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.vertical, 10)
            .padding(.horizontal, 22)
            .foregroundStyle(isProminent ? Color.white : AppTheme.accent)
            .background(isProminent ? AppTheme.accent : Color.clear, in: Capsule())
            .overlay {
                if !isProminent {
                    Capsule().stroke(AppTheme.accent.opacity(0.6), lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pill: PillButtonStyle { PillButtonStyle() }
    static func pill(prominent: Bool) -> PillButtonStyle { PillButtonStyle(isProminent: prominent) }
}
