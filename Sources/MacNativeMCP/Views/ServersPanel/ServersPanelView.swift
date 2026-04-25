import SwiftUI

struct ServersPanelView: View {
    @Environment(AppState.self) var appState
    @Environment(MCPServerManager.self) var serverManager
    @State private var showAddSheet = false
    @State private var expandedServerIds: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SERVERS")
                    .font(AppFonts.label)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
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
