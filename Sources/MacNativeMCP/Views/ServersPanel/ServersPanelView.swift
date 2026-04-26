import SwiftUI

struct ServersPanelView: View {
    @Environment(AppState.self) var appState
    @Environment(MCPServerManager.self) var serverManager
    @Environment(NexlayerService.self) var nexlayer
    @State private var showAddSheet = false
    @State private var expandedServerIds: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("SERVERS")
                    .font(AppFonts.label)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()

                // Sync deployments from Nexlayer
                Button {
                    Task {
                        if let configs = try? await nexlayer.fetchDeployments(namespace: "amiable-beetle") {
                            appState.syncDeployments(configs)
                        }
                    }
                } label: {
                    if nexlayer.isSyncing {
                        ProgressView().scaleEffect(0.55).frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Sync deployments from Nexlayer")
                .disabled(nexlayer.isSyncing || nexlayer.client == nil)

                // Add server
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "externaldrive.badge.plus")
                        .foregroundStyle(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Add server")

                // New chat — creates a chat for the selected server
                Button(action: newChatAction) {
                    Image(systemName: "plus.bubble")
                        .foregroundStyle(appState.activeServerId != nil
                                         ? AppColors.accent
                                         : AppColors.textSecondary)
                }
                .buttonStyle(.plain)
                .help(appState.activeServerId != nil
                      ? "New chat for selected server"
                      : "Select a server first")
                .disabled(appState.activeServerId == nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().background(AppColors.border)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(appState.servers) { server in
                        ServerRowView(
                            server: server,
                            isExpanded: expandedServerIds.contains(server.id),
                            onToggle: { toggle(server.id) },
                            onDelete: { appState.removeServer(id: server.id) }
                        )
                    }
                }
            }
        }
        .background(AppColors.surface)
        .sheet(isPresented: $showAddSheet) {
            AddServerSheet { config in
                appState.addServer(config)
                showAddSheet = false
            }
        }
    }

    private func newChatAction() {
        guard let id = appState.activeServerId,
              let server = appState.servers.first(where: { $0.id == id }) else { return }
        appState.createChat(for: server)
    }

    private func toggle(_ id: UUID) {
        if expandedServerIds.contains(id) { expandedServerIds.remove(id) }
        else { expandedServerIds.insert(id) }
    }
}
