import SwiftUI

enum AppTheme {
    // MARK: Palette
    static let accent = Color(red: 0.89, green: 0.29, blue: 0.29)
    static let background = Color(red: 0.055, green: 0.055, blue: 0.07)
    static let surface = Color(red: 0.11, green: 0.11, blue: 0.13)
    static let hairline = Color.white.opacity(0.08)
    /// Lifted red for negative amounts — the brand accent is too dark to read as body text on surfaces.
    static let loss = Color(red: 0.95, green: 0.45, blue: 0.42)

    // MARK: Type
    /// Rounded, semibold, fixed-width digits — every money value in the app renders in this.
    static func money(_ style: Font.TextStyle = .body) -> Font {
        .system(style, design: .rounded).weight(.semibold)
    }
}
