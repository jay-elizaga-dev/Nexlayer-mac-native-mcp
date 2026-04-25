import SwiftUI

struct ServerRowView: View {
    @Environment(AppState.self) var appState
    @Environment(MCPServerManager.self) var serverManager

    let server: AppState.ServerConfig
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var showEditSheet = false
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.15), value: isExpanded)
                        .frame(width: 14)
                }
                .buttonStyle(.plain)

                Text(server.name.isEmpty ? "(unnamed)" : server.name)
                    .font(AppFonts.prose)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                    .scaleEffect(isConnecting ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isConnecting)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(appState.activeServerId == server.id ? AppColors.accent.opacity(0.15) : isHovered ? AppColors.surfaceHover : Color.clear)
            .onHover { isHovered = $0 }
            .onTapGesture { appState.activeServerId = server.id }
            .contentShape(Rectangle())
            .contextMenu {
                Button("Edit") { showEditSheet = true }
                Divider()
                if status == .stopped {
                    Button("Start") {
                        Task { await serverManager.connect(server: server) }
                    }
                } else {
                    Button("Stop") {
                        Task { await serverManager.disconnect(server: server) }
                    }
                }
                Divider()
                Button("Delete", role: .destructive, action: onDelete)
            }

            if isExpanded {
                let tools = serverManager.clients[server.id]?.tools ?? []
                if tools.isEmpty {
                    Text("No tools")
                        .font(AppFonts.label)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 36)
                        .padding(.vertical, 6)
                } else {
                    ForEach(tools) { tool in
                        ToolRowView(tool: tool)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddServerSheet(initial: server) { updated in
                appState.updateServer(updated)
                showEditSheet = false
            }
        }
    }

    private var status: MCPServerManager.ConnectionStatus {
        guard let client = serverManager.clients[server.id] else { return .stopped }
        switch client.state {
        case .ready:                 return .connected
        case .disconnected,
             .connecting:            return .stopped
        case .error:                 return .error
        }
    }

    private var statusColor: Color {
        switch status {
        case .connected:  return AppColors.success
        case .connecting: return AppColors.accent
        case .stopped:    return AppColors.textSecondary
        case .error:      return AppColors.danger
        }
    }
}
