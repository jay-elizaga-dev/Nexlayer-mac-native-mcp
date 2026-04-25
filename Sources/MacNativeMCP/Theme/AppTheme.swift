import AppKit

enum AppTheme {
    static func applyDarkMode() {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}
