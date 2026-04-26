import SwiftUI
import AppKit

struct CostReportsView: View {
    @Environment(AppState.self) var appState
    @Environment(NexlayerService.self) var nexlayer

    @State private var billingExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(AppColors.border)

            // Billing panel — collapsible
            DisclosureGroup("Account Balance", isExpanded: $billingExpanded) {
                BillingView()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .font(AppFonts.label)
            .foregroundStyle(AppColors.textSecondary)

            Divider().background(AppColors.border)

            if allDeploymentNames.isEmpty {
                emptyState
            } else {
                summaryTable
            }
        }
        .background(AppColors.background)
        .task { await discoverIfNeeded() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("Cost & Usage")
                .font(AppFonts.heading)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Button(action: { Task { await discoverAll() } }) {
                if nexlayer.isDiscovering {
                    ProgressView().scaleEffect(0.7).frame(width: 16, height: 16)
                } else {
                    Label("Discover", systemImage: "arrow.clockwise")
                        .font(AppFonts.label)
                }
            }
            .buttonStyle(.bordered)
            .help("Scan Nexlayer namespaces to discover all deployed services")
            Button(action: exportCSV) {
                Label("Export CSV", systemImage: "square.and.arrow.up")
                    .font(AppFonts.label)
            }
            .buttonStyle(.bordered)
            .disabled(nexlayer.callHistory.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.textSecondary)
            Text("No tool calls recorded yet")
                .font(AppFonts.prose)
                .foregroundStyle(AppColors.textSecondary)
            Text("Make some MCP tool calls to see usage metrics here.")
                .font(AppFonts.label)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Summary table

    private var summaryTable: some View {
        ScrollView {
            VStack(spacing: 0) {
                tableHeader
                Divider().background(AppColors.border)
                ForEach(deploymentSummaries, id: \.deployment) { summary in
                    summaryRow(summary)
                    Divider().background(AppColors.border.opacity(0.5))
                }
                // Global / non-deployment calls row
                let global = globalSummary
                if global.callCount > 0 {
                    summaryRow(global)
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("Deployment / Service").frame(maxWidth: .infinity, alignment: .leading)
            Text("Calls").frame(width: 55, alignment: .trailing)
            Text("Tokens").frame(width: 70, alignment: .trailing)
            Text("Est. Cost").frame(width: 80, alignment: .trailing)
            Text("Success").frame(width: 75, alignment: .trailing)
            Text("Avg (ms)").frame(width: 80, alignment: .trailing)
            Text("Last call").frame(width: 120, alignment: .trailing)
        }
        .font(AppFonts.label)
        .foregroundStyle(AppColors.textSecondary)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func summaryRow(_ s: DeploymentSummary) -> some View {
        let hasCalls = s.callCount > 0
        HStack(spacing: 0) {
            Text(s.deployment.isEmpty ? "(global)" : s.deployment)
                .font(AppFonts.code)
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(hasCalls ? "\(s.callCount)" : "—")
                .frame(width: 55, alignment: .trailing)
                .foregroundStyle(hasCalls ? AppColors.textPrimary : AppColors.textSecondary)
            Text(hasCalls ? "\(s.totalTokens)" : "—")
                .frame(width: 70, alignment: .trailing)
                .foregroundStyle(s.totalTokens > 0 ? AppColors.textPrimary : AppColors.textSecondary)
            Text(hasCalls ? formatCost(s.totalTokens) : "—")
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(s.totalTokens > 0 ? AppColors.warning : AppColors.textSecondary)
            Text(hasCalls ? String(format: "%.0f%%", s.successRate * 100) : "—")
                .frame(width: 75, alignment: .trailing)
                .foregroundStyle(hasCalls
                    ? (s.successRate > 0.9 ? AppColors.success : AppColors.danger)
                    : AppColors.textSecondary)
            Text(hasCalls ? "\(s.avgDurationMs)" : "—")
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(AppColors.textSecondary)
            Text(hasCalls ? relativeDate(s.lastCall) : "no calls yet")
                .frame(width: 120, alignment: .trailing)
                .foregroundStyle(AppColors.textSecondary)
        }
        .font(AppFonts.prose)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectedCostReport = s.deployment.isEmpty ? nil : s.deployment
        }
        .background(appState.selectedCostReport == s.deployment
                    ? AppColors.accent.opacity(0.08)
                    : Color.clear)
    }

    // MARK: - Data

    struct DeploymentSummary {
        var deployment: String
        var callCount: Int
        var totalTokens: Int
        var successRate: Double
        var avgDurationMs: Int
        var lastCall: Date
    }

    /// All unique deployment names from history + configured servers + discovered services.
    private var allDeploymentNames: Set<String> {
        var names = Set(nexlayer.callHistory.filter { !$0.deployment.isEmpty }.map(\.deployment))
        for server in appState.servers where !server.nexlayerApp.isEmpty {
            names.insert(server.nexlayerApp)
        }
        for slug in nexlayer.discoveredDeployments where !slug.isEmpty {
            names.insert(slug)
        }
        return names
    }

    private var deploymentSummaries: [DeploymentSummary] {
        let nonGlobal = nexlayer.callHistory.filter { !$0.deployment.isEmpty }
        let grouped = Dictionary(grouping: nonGlobal, by: \.deployment)

        var summaries: [DeploymentSummary] = grouped.map { dep, records in
            let successful = records.filter(\.success).count
            let avg = records.isEmpty ? 0 : records.map(\.durationMs).reduce(0, +) / records.count
            let last = records.map(\.timestamp).max() ?? Date()
            let tokens = records.map(\.tokenBurn).reduce(0, +)
            return DeploymentSummary(
                deployment: dep,
                callCount: records.count,
                totalTokens: tokens,
                successRate: records.isEmpty ? 0 : Double(successful) / Double(records.count),
                avgDurationMs: avg,
                lastCall: last
            )
        }

        // Add placeholder rows for every known deployment with no call history yet
        let withHistory = Set(summaries.map(\.deployment))
        for name in allDeploymentNames where !withHistory.contains(name) {
            summaries.append(DeploymentSummary(
                deployment: name,
                callCount: 0,
                totalTokens: 0,
                successRate: 1.0,
                avgDurationMs: 0,
                lastCall: .distantPast
            ))
        }

        return summaries.sorted {
            // Services with call history first, sorted by recency; then alpha
            if $0.callCount > 0 && $1.callCount == 0 { return true }
            if $0.callCount == 0 && $1.callCount > 0 { return false }
            if $0.callCount > 0 { return $0.lastCall > $1.lastCall }
            return $0.deployment < $1.deployment
        }
    }

    private var globalSummary: DeploymentSummary {
        let records = nexlayer.callHistory.filter { $0.deployment.isEmpty }
        let successful = records.filter(\.success).count
        let avg = records.isEmpty ? 0 : records.map(\.durationMs).reduce(0, +) / records.count
        let last = records.map(\.timestamp).max() ?? Date()
        let tokens = records.map(\.tokenBurn).reduce(0, +)
        return DeploymentSummary(
            deployment: "",
            callCount: records.count,
            totalTokens: tokens,
            successRate: records.isEmpty ? 0 : Double(successful) / Double(records.count),
            avgDurationMs: avg,
            lastCall: last
        )
    }

    // MARK: - Discovery

    private func discoverIfNeeded() async {
        guard nexlayer.discoveredDeployments.isEmpty else { return }
        await discoverAll()
    }

    private func discoverAll() async {
        let domains = Set(appState.servers.map(\.nexlayerDomain).filter { !$0.isEmpty })
        await nexlayer.discoverDeployments(for: Array(domains))
    }

    // MARK: - Helpers

    /// $10 = 1,000 credits = 1,000 NL tokens → 1 token = $0.01
    private func formatCost(_ tokens: Int) -> String {
        guard tokens > 0 else { return "—" }
        let dollars = Double(tokens) * 0.01
        if dollars < 0.01 { return "<$0.01" }
        return String(format: "$%.2f", dollars)
    }

    private func exportCSV() {
        let csv = nexlayer.exportCSV()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "nexlayer-usage-\(ISO8601DateFormatter().string(from: Date())).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private func relativeDate(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60    { return "just now" }
        if diff < 3600  { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}
