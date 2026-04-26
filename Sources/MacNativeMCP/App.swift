import SwiftUI

struct MacNativeMCPApp: App {
    @State private var appState = AppState()
    @State private var serverManager = MCPServerManager()
    @State private var authManager = AuthManager()
    @State private var nexlayerService = NexlayerService()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(serverManager)
                .environment(authManager)
                .environment(nexlayerService)
                .background(MainWindowSetupView())
                .preferredColorScheme(.dark)
                .task {
                    AppTheme.applyDarkMode()
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
                .onChange(of: authManager.state) { _, state in
                    if case .authenticated = state {
                        serverManager.apiKey = authManager.currentAPIKey
                        if let client = authManager.nexlayerClient {
                            nexlayerService.setClient(client)
                        }
                    } else {
                        serverManager.apiKey = nil
                        nexlayerService.reset()
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
                .environment(nexlayerService)
        }
    }
}
