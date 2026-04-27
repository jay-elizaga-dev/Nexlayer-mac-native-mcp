import SwiftUI

@MainActor
struct ServerDetailView: View {
    let server: AppState.ServerConfig

    @Environment(AppState.self) private var appState
    @Environment(MCPServerManager.self) private var serverManager
    @Environment(NexlayerService.self) private var nexlayer

    @State private var tab: Tab = .overview

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case logs     = "Logs"
        case secrets  = "Secrets"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(AppColors.border)
            tabBar
            Divider().background(AppColors.border)
            tabContent
        }
        .background(AppColors.background)
        .task(id: server.id) {
            if server.isNexlayerDeployment {
                await nexlayer.fetchStatus(for: server)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.textPrimary)

                if !server.url.isEmpty {
                    Button {
                        if let url = URL(string: server.url) { NSWorkspace.shared.open(url) }
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
                }
            }

            Spacer()

            if server.isNexlayerDeployment {
                // Refresh
                Button {
                    Task { await nexlayer.fetchStatus(for: server) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Refresh status")

                // Restart
                Button {
                    Task {
                        try? await nexlayer.restartDeployment(server)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11))
                        Text("Restart")
                            .font(AppFonts.label)
                    }
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Rolling restart all pods")
            }
        }
        .padding(16)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button(t.rawValue) { tab = t }
                    .buttonStyle(.plain)
                    .font(AppFonts.label)
                    .foregroundStyle(tab == t ? AppColors.textPrimary : AppColors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        tab == t
                            ? AppColors.accent.opacity(0.12)
                            : Color.clear
                    )
                    .overlay(alignment: .bottom) {
                        if tab == t {
                            Rectangle()
                                .fill(AppColors.accent)
                                .frame(height: 2)
                        }
                    }
            }
            Spacer()
        }
        .background(AppColors.surface)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .overview: overviewTab
        case .logs:     logsTab
        case .secrets:  secretsTab
        }
    }

    // MARK: Overview

    private var overviewTab: some View {
        let key = server.nexlayerApp
        let isLoading = nexlayer.loading[key] == true
        let status = nexlayer.statusCache[key]
        let error = nexlayer.errors[key]

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView().scaleEffect(0.7)
                        Text("Fetching status…")
                            .font(AppFonts.label)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(16)
                } else if let error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColors.danger)
                        Text(error)
                            .font(AppFonts.label)
                            .foregroundStyle(AppColors.danger)
                    }
                    .padding(16)
                } else if let status {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Last refreshed \(status.fetchedAt.formatted(.relative(presentation: .named)))")
                                .font(AppFonts.label)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        Divider().background(AppColors.border).padding(.vertical, 8)

                        Text(status.raw)
                            .font(AppFonts.code)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                            .textSelection(.enabled)
                    }
                } else if !server.isNexlayerDeployment {
                    Text("Not a Nexlayer deployment — no status available.")
                        .font(AppFonts.prose)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(16)
                } else {
                    Text("No status yet — tap refresh.")
                        .font(AppFonts.prose)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(16)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Logs

    @State private var podName: String = ""

    private var logsTab: some View {
        let logKey = "\(server.nexlayerApp)/\(podName)"
        let logs = nexlayer.logsCache[logKey]
        let isLoading = nexlayer.loading[logKey] == true

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Pod name (e.g. gitea-server-gitea-56577b6cb9-fctql)", text: $podName)
                    .font(AppFonts.code)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(8)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Button("Fetch") {
                    Task { await nexlayer.fetchLogs(for: server, podName: podName) }
                }
                .buttonStyle(.plain)
                .font(AppFonts.label)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(podName.isEmpty ? AppColors.border : AppColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .disabled(podName.isEmpty)
            }
            .padding(12)

            Divider().background(AppColors.border)

            ScrollView {
                if isLoading {
                    ProgressView().padding(16)
                } else if let logs {
                    Text(logs)
                        .font(AppFonts.codeSmall)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .textSelection(.enabled)
                } else {
                    Text("Enter a pod name and tap Fetch.")
                        .font(AppFonts.prose)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(16)
                }
            }
        }
    }

    // MARK: Secrets

    private var secretsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(AppColors.accent)
                Text("Nexlayer secrets are managed via your **nexlayer.yaml** `env` block and applied on redeploy.")
                    .font(AppFonts.prose)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(12)
            .background(AppColors.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button("Open Nexlayer Dashboard →") {
                NSWorkspace.shared.open(URL(string: "https://app.nexlayer.com")!)
            }
            .buttonStyle(.plain)
            .font(AppFonts.label)
            .foregroundStyle(AppColors.accent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
