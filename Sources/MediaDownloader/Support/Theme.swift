import AppKit
import SwiftUI

// Brand colors, matched to the app icon's blue gradient.
extension NSColor {
    /// Primary brand blue for AppKit drawing (matches Color.appAccent, #0A84FF).
    static let appAccent = NSColor(srgbRed: 10 / 255, green: 132 / 255, blue: 255 / 255, alpha: 1)
}

extension Color {
    /// Primary brand blue — the workhorse accent for selection, rings, and highlights.
    static let appAccent = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255) // #0A84FF

    /// Bright sky-blue from the top of the icon gradient.
    static let appAccentBright = Color(red: 10 / 255, green: 178 / 255, blue: 254 / 255) // #0AB2FE

    /// Deeper blue from the bottom of the icon gradient.
    static let appAccentDeep = Color(red: 11 / 255, green: 120 / 255, blue: 254 / 255) // #0B78FE
}

extension LinearGradient {
    /// Vertical blue gradient echoing the app icon (bright top → deep bottom).
    static let appAccent = LinearGradient(
        colors: [.appAccentBright, .appAccentDeep],
        startPoint: .top,
        endPoint: .bottom
    )
}
