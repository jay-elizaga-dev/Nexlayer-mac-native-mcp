import SwiftUI

@main
struct MacNativeMCPApp: App {
    @State private var appState = AppState()

    init() {
        AppTheme.applyDarkMode()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .background(MainWindowSetupView())
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            CommandMenu("MCP") {
                Button("New Conversation", action: {}).keyboardShortcut("n", modifiers: .command)
                Divider()
                Button("Focus Input", action: {}).keyboardShortcut("l", modifiers: .command)
                Button("Clear Conversation", action: {}).keyboardShortcut(.delete, modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
