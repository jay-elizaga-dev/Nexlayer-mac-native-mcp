import SwiftUI

enum AppColors {
    static let background    = Color(hex: "#0E0E0E")
    static let surface       = Color(hex: "#161616")
    static let surfaceHover  = Color(hex: "#1F1F1F")
    static let border        = Color(hex: "#2A2A2A")
    static let textPrimary   = Color(hex: "#E8E8E8")
    static let textSecondary = Color(hex: "#888888")
    static let accent        = Color(hex: "#5B8AF7")
    static let accentHover   = Color(hex: "#4A77E8")
    static let toolCall      = Color(hex: "#1A2033")
    static let toolResult    = Color(hex: "#0F1A12")
    static let danger        = Color(hex: "#E05252")
    static let success       = Color(hex: "#52C97A")
    static let warning       = Color(hex: "#E0943A")
    static let titleBarBg    = Color(hex: "#090909")
    static let titleBarBorder = Color(hex: "#222222")
    static let panelHeaderBg = Color(hex: "#111111")
    static let inputBg       = Color(hex: "#141414")
    static let scrollbarTrack = Color(hex: "#1A1A1A")
    static let codeLineno    = Color(hex: "#3A3A3A")
    static let codeSelection = Color(hex: "#1E3158")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
