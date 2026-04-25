import SwiftUI

struct ServerDetailView: View {
    let server: AppState.ServerConfig

    @Environment(AppState.self) private var appState
    @Environment(MCPServerManager.self) private var serverManager

    private var client: MCPClient? { serverManager.clients[server.id] }
    private var status: MCPServerManager.ConnectionStatus {
        guard let client else {
            return serverManager.connectionErrors[server.id] != nil ? .error : .stopped
        }
        switch client.state {
        case .ready:        return .connected
        case .connecting:   return .connecting
        case .disconnected: return .stopped
        case .error:        return .error
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(server.name)
                        .font(AppFonts.heading)
                        .foregroundStyle(AppColors.textPrimary)

                    if let info = client?.serverInfo {
                        Text("\(info.name)  ·  v\(info.version)")
                            .font(AppFonts.label)
                            .foregroundStyle(AppColors.textSecondary)
                    } else if server.transport == .http, !server.url.isEmpty {
                        Button {
                            if let url = URL(string: server.url) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(server.url)
                                    .font(AppFonts.label)
                                    .foregroundStyle(AppColors.accent)
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppColors.accent)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Open in browser")
                    } else {
                        Text(([server.command] + server.args).joined(separator: " "))
                            .font(AppFonts.label)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                statusBadge

                if status == .stopped || status == .error {
                    Button("Connect") {
                        Task { await serverManager.connect(server: server) }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.accent)
                    .font(AppFonts.label)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.border, lineWidth: 1))
                }
            }
            .padding(16)

            Divider().background(AppColors.border)

            // Error
            if let err = serverManager.connectionErrors[server.id] {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppColors.danger)
                    Text(err)
                        .font(AppFonts.label)
                        .foregroundStyle(AppColors.danger)
                    Spacer()
                }
                .padding(12)
                .background(AppColors.danger.opacity(0.08))
            }

            // Tools grid
            if status == .connecting {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Connecting to \(server.name)…")
                        .font(AppFonts.prose)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
            } else if let client, !client.tools.isEmpty {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(client.tools) { tool in
                            ToolCardView(tool: tool, serverId: server.id)
                        }
                    }
                    .padding(16)
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.border)
                    Text(status == .connected ? "No tools exposed" : "Not connected")
                        .font(AppFonts.prose)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
            }
        }
        .background(AppColors.background)
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 5) {
            switch status {
            case .connected:
                Circle().fill(AppColors.success).frame(width: 7, height: 7)
                Text("connected").font(AppFonts.label).foregroundStyle(AppColors.success)
            case .connecting:
                ProgressView().scaleEffect(0.5).frame(width: 7, height: 7)
                Text("connecting").font(AppFonts.label).foregroundStyle(AppColors.textSecondary)
            case .error:
                Circle().fill(AppColors.danger).frame(width: 7, height: 7)
                Text("error").font(AppFonts.label).foregroundStyle(AppColors.danger)
            case .stopped:
                Circle().fill(AppColors.textSecondary.opacity(0.4)).frame(width: 7, height: 7)
                Text("stopped").font(AppFonts.label).foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}
