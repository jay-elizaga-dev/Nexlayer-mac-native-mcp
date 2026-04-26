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
        HStack(spacing: 0) {
            SideDrawer()

            Divider().background(AppColors.border)

            if appState.sidebarMode == .cost {
                costLayout
            } else {
                serverLayout
            }
        }
        .background(AppColors.background)
    }

    // MARK: - Layouts

    private var serverLayout: some View {
        HSplitView {
            serversPanelIfNeeded
                .frame(minWidth: 220, maxWidth: 260)

            centerPanel
                .frame(minWidth: 400)

            rightPanel
                .frame(minWidth: 280)
        }
    }

    @ViewBuilder
    private var serversPanelIfNeeded: some View {
        if appState.sidebarOpen {
            // Drawer is open and showing servers nav — embed the server list inside the split
            ServersPanelView()
        } else {
            // Icon rail is visible, server list goes in main split
            ServersPanelView()
        }
    }

    private var costLayout: some View {
        HSplitView {
            CostReportsView()
                .frame(minWidth: 460)

            if let dep = appState.selectedCostReport {
                CostDetailView(deployment: dep)
                    .frame(minWidth: 280)
            } else {
                costDetailPlaceholder
                    .frame(minWidth: 280)
            }
        }
    }

    private var costDetailPlaceholder: some View {
        VStack {
            Spacer()
            Image(systemName: "hand.point.left")
                .font(.system(size: 28))
                .foregroundStyle(AppColors.textSecondary)
            Text("Select a deployment to see call details")
                .font(AppFonts.label)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.surface)
    }

    // MARK: - Center / right panels (servers mode)

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
            emptyRightPanel
        }
    }

    private var emptyRightPanel: some View {
        VStack {
            Spacer()
            Image(systemName: "bubble.left")
                .font(.system(size: 28))
                .foregroundStyle(AppColors.textSecondary)
            Text("Select a server and start a chat")
                .font(AppFonts.label)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.surface)
    }

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
