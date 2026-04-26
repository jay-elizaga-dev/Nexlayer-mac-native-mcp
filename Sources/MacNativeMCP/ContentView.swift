import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) var appState
    @Environment(AuthManager.self) var authManager

    var body: some View {
        switch authManager.state {
        case .checking, .connecting:
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                    Text(authManager.state == .checking ? "Checking saved session…" : "Connecting…")
                        .font(AppFonts.label)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(minWidth: 480, minHeight: 320)

        case .unauthenticated, .error:
            LandingView()
                .frame(minWidth: 480, minHeight: 480)

        case .authenticated:
            mainUI
        }
    }

    private var mainUI: some View {
        HSplitView {
            ServersPanelView()
                .frame(minWidth: 220, maxWidth: 260)

            centerPanel
                .frame(minWidth: 400)

            rightPanel
                .frame(minWidth: 280)
        }
        .background(AppColors.background)
    }

    @ViewBuilder
    private var centerPanel: some View {
        if let id = appState.activeServerId,
           let server = appState.servers.first(where: { $0.id == id }) {
            ServerDetailView(server: server)
        } else {
            ConversationView()
        }
    }

    @ViewBuilder
    private var rightPanel: some View {
        if let server = appState.servers.first(where: { $0.id == appState.activeServerId }),
           let session = chatForActiveServer {
            ServerChatView(chatId: session.id, server: server)
        } else {
            OutputPanelView()
        }
    }

    /// Returns the active chat session for the selected server (prefers activeChatId, falls back to latest).
    private var chatForActiveServer: AppState.ChatSession? {
        guard let serverId = appState.activeServerId else { return nil }
        if let id = appState.activeChatId,
           let chat = appState.chatSessions.first(where: { $0.id == id }),
           chat.serverId == serverId {
            return chat
        }
        return appState.chatSessions.last(where: { $0.serverId == serverId })
    }
}
