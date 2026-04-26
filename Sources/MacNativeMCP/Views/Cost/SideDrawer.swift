import SwiftUI

/// Left sidebar drawer.
/// Open + Servers mode  → 240px panel containing the full server list
/// Open + Cost mode     → 200px nav panel (cost summary in main area)
/// Closed               → 44px icon rail
struct SideDrawer: View {
    @Environment(AppState.self) var appState
    @Environment(NexlayerService.self) var nexlayer

    private var drawerWidth: CGFloat {
        appState.sidebarMode == .servers ? 240 : 200
    }

    var body: some View {
        if appState.sidebarOpen {
            expandedDrawer
                .frame(width: drawerWidth)
        } else {
            iconRail
                .frame(width: 44)
        }
    }

    // MARK: - Expanded

    private var expandedDrawer: some View {
        VStack(spacing: 0) {
            drawerHeader

            Divider().background(AppColors.border)

            switch appState.sidebarMode {
            case .servers:
                serversContent
            case .cost:
                costNavContent
            }
        }
        .background(AppColors.surface)
    }

    private var drawerHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: appState.sidebarMode == .servers ? "server.rack" : "chart.bar.xaxis")
                .foregroundStyle(AppColors.accent)
                .frame(width: 16)
            Text(appState.sidebarMode == .servers ? "SERVERS" : "COST & USAGE")
                .font(AppFonts.label)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    appState.sidebarOpen = false
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .foregroundStyle(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Collapse sidebar")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Servers content (embedded server list)

    private var serversContent: some View {
        ServersPanelView(showHeader: false)
    }

    // MARK: - Cost nav content

    private var costNavContent: some View {
        VStack(spacing: 0) {
            navButton(icon: "server.rack",    label: "Servers",     mode: .servers)
            navButton(icon: "chart.bar.xaxis", label: "Cost & Usage", mode: .cost)

            Spacer()
            costFooter
        }
    }

    @ViewBuilder
    private func navButton(icon: String, label: String, mode: AppState.SidebarMode) -> some View {
        Button { appState.sidebarMode = mode } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).frame(width: 16)
                Text(label).font(AppFonts.prose)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(appState.sidebarMode == mode
                        ? AppColors.accent.opacity(0.15)
                        : Color.clear)
            .foregroundStyle(appState.sidebarMode == mode
                             ? AppColors.accent
                             : AppColors.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private var costFooter: some View {
        VStack(spacing: 4) {
            Divider().background(AppColors.border)
            HStack(spacing: 6) {
                Image(systemName: "creditcard")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textSecondary)
                if nexlayer.isCheckingCredits {
                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                } else {
                    Text(nexlayer.credits.flatMap { firstLine($0) } ?? "—")
                        .font(AppFonts.label)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Button { Task { await nexlayer.fetchCredits() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(nexlayer.isCheckingCredits)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Icon Rail

    private var iconRail: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    appState.sidebarOpen = true
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 44, height: 36)
            }
            .buttonStyle(.plain)
            .help("Expand sidebar")

            Divider().background(AppColors.border)

            railIcon(icon: "server.rack",     mode: .servers)
            railIcon(icon: "chart.bar.xaxis", mode: .cost)

            Spacer()
        }
        .background(AppColors.surface)
    }

    @ViewBuilder
    private func railIcon(icon: String, mode: AppState.SidebarMode) -> some View {
        Button { appState.sidebarMode = mode } label: {
            Image(systemName: icon)
                .frame(width: 44, height: 36)
                .foregroundStyle(appState.sidebarMode == mode ? AppColors.accent : AppColors.textSecondary)
                .background(appState.sidebarMode == mode ? AppColors.accent.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func firstLine(_ text: String) -> String? {
        text.components(separatedBy: "\n").first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }
}
