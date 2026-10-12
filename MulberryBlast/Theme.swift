import SwiftUI

enum Theme {
    static let background = LinearGradient(
        colors: [Color(hex: 0x1A0F1E), Color(hex: 0x2A1230)],
        startPoint: .top, endPoint: .bottom)
    static let boardBackground = Color(hex: 0x2D1B33)
    static let emptyCell = Color(hex: 0x3A2442)
    static let accent = Color(hex: 0xF2C4D8)
    static let textDim = Color(hex: 0xB89AC4)

    /// Berry / wine block colors, indexed by Piece.color
    static let blocks: [Color] = [
        Color(hex: 0xA8326E), // mulberry
        Color(hex: 0xD6478F), // magenta
        Color(hex: 0x7B3FA0), // violet
        Color(hex: 0xC2577A), // rose
        Color(hex: 0x8E2A5A), // wine
        Color(hex: 0xB86AD6), // orchid
        Color(hex: 0xE0708C), // raspberry
    ]
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
