import SwiftUI

@main
struct MacNativeMCPApp: App {
    @State private var appState = AppState()
    @State private var serverManager = MCPServerManager()
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(serverManager)
                .environment(authManager)
                .background(MainWindowSetupView())
                .preferredColorScheme(.dark)
                .task { AppTheme.applyDarkMode() }
                .onChange(of: authManager.state) { _, state in
                    if case .authenticated = state {
                        serverManager.apiKey = authManager.currentAPIKey
                    } else {
                        serverManager.apiKey = nil
                    }
                }
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
                .environment(serverManager)
                .environment(authManager)
        }
    }
}
