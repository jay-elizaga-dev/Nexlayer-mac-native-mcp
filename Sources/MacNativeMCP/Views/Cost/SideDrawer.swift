import SwiftUI

/// Left sidebar drawer.
/// Open + Servers mode  → 240px panel containing the full server list
/// Open + Cost mode     → 200px nav panel (cost summary in main area)
/// Closed               → 44px icon rail
struct SideDrawer: View {
    @Environment(AppState.self) var appState
    @Environment(NexlayerService.self) var nexlayer
    @Environment(AuthManager.self) var auth

    @State private var showUserMenu = false

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

            Divider().background(AppColors.border)
            expandedUserRow
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
            navButton(icon: "server.rack",     label: "Servers",      mode: .servers)
            navButton(icon: "chart.bar.xaxis", label: "Cost & Usage", mode: .cost)
            Spacer()
            creditsRow
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

    private var creditsRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "creditcard")
                .font(.system(size: 10))
                .foregroundStyle(AppColors.textSecondary)
            if nexlayer.isCheckingCredits || nexlayer.isEstablishingSession {
                ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                Text(nexlayer.isEstablishingSession ? "Signing in…" : "Checking…")
                    .font(AppFonts.label)
                    .foregroundStyle(AppColors.textSecondary)
            } else if let credits = nexlayer.credits {
                let line = firstLine(credits) ?? credits
                let isErr = line.lowercased().contains("error") || line.lowercased().contains("sign in")
                Text(isErr ? "Sign in required" : line)
                    .font(AppFonts.label)
                    .foregroundStyle(isErr ? AppColors.danger : AppColors.textSecondary)
                    .lineLimit(1)
            } else {
                Text("—").font(AppFonts.label).foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Button {
                Task {
                    if nexlayer.jwtToken == nil { await nexlayer.establishSession() }
                    await nexlayer.fetchCredits()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(nexlayer.isCheckingCredits || nexlayer.isEstablishingSession)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - User avatar row (expanded)

    private var expandedUserRow: some View {
        Button { showUserMenu = true } label: {
            HStack(spacing: 8) {
                userAvatar(size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(auth.state == .authenticated ? "Signed in" : "Not signed in")
                        .font(AppFonts.label)
                        .foregroundStyle(AppColors.textPrimary)
                    if let key = auth.currentAPIKey, key.count >= 4 {
                        Text("•••• \(String(key.suffix(4)))")
                            .font(.system(size: 9))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showUserMenu, arrowEdge: .bottom) {
            userMenuPopover
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

            Divider().background(AppColors.border)

            // User avatar in rail
            Button { showUserMenu = true } label: {
                userAvatar(size: 24)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showUserMenu, arrowEdge: .trailing) {
                userMenuPopover
            }
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

    // MARK: - User avatar

    @ViewBuilder
    private func userAvatar(size: CGFloat) -> some View {
        let isAuth = auth.state == .authenticated
        ZStack {
            Circle()
                .fill(isAuth ? AppColors.accent.opacity(0.2) : AppColors.surface)
                .overlay(Circle().stroke(isAuth ? AppColors.accent : AppColors.border, lineWidth: 1))
                .frame(width: size, height: size)
            Image(systemName: isAuth ? "person.fill" : "person")
                .font(.system(size: size * 0.45))
                .foregroundStyle(isAuth ? AppColors.accent : AppColors.textSecondary)
        }
    }

    // MARK: - User menu popover

    private var userMenuPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                userAvatar(size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.state == .authenticated ? "Signed in" : "Not signed in")
                        .font(AppFonts.label)
                        .foregroundStyle(AppColors.textPrimary)
                    if let key = auth.currentAPIKey, key.count >= 4 {
                        Text("API key ending in \(String(key.suffix(4)))")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().background(AppColors.border)

            if auth.state == .authenticated {
                menuItem(label: "Sign Out", icon: "rectangle.portrait.and.arrow.right", danger: true) {
                    showUserMenu = false
                    auth.signOut()
                }
            } else {
                menuItem(label: "Sign In", icon: "arrow.right.circle", danger: false) {
                    showUserMenu = false
                    auth.retry()
                }
            }
        }
        .frame(width: 220)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.border, lineWidth: 1))
    }

    @ViewBuilder
    private func menuItem(label: String, icon: String, danger: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(label)
                    .font(AppFonts.prose)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(danger ? AppColors.danger : AppColors.textPrimary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func firstLine(_ text: String) -> String? {
        text.components(separatedBy: "\n").first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }
}
