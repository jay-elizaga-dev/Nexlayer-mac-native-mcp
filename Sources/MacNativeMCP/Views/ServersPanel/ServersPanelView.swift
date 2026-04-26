import SwiftUI

struct ServersPanelView: View {
    @Environment(AppState.self) var appState
    @Environment(MCPServerManager.self) var serverManager
    @Environment(NexlayerService.self) var nexlayer
    @State private var showAddSheet = false
    @State private var expandedServerIds: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SERVERS")
                    .font(AppFonts.label)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()

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

                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .foregroundStyle(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
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

    private func toggle(_ id: UUID) {
        if expandedServerIds.contains(id) { expandedServerIds.remove(id) }
        else { expandedServerIds.insert(id) }
    }
}
