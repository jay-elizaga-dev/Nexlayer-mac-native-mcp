import Foundation
import AppKit
import Observation

@Observable
@MainActor
final class NexlayerService {

    // MARK: - State

    private(set) var client: MCPClient?

    var statusCache:       [String: DeploymentStatus] = [:]
    var logsCache:         [String: String]            = [:]
    var loading:           [String: Bool]              = [:]
    var errors:            [String: String]            = [:]
    var isSyncing:         Bool                        = false

    // Cost tracking
    var callHistory:       [ToolCallRecord]            = []

    // Billing
    var creditBalance:     CreditBalance?              = nil
    var isFetchingCredits: Bool                        = false
    var referralLink:      String?                     = nil
    var isFetchingReferral: Bool                       = false
    var couponResult:      String?                     = nil
    var isApplyingCoupon:  Bool                        = false

    /// NextAuth.js session token — set after web sign-in. Enables OAuth-required tools.
    var sessionToken: String?

    // MARK: - Models

    struct DeploymentStatus {
        var raw: String
        var fetchedAt: Date
    }

    struct ToolCallRecord: Identifiable {
        var id:          UUID   = UUID()
        var tool:        String
        var deployment:  String          // nexlayerApp slug or "" for global calls
        var timestamp:   Date   = Date()
        var durationMs:  Int
        var success:     Bool
        var error:       String?
    }

    struct CreditBalance {
        var plan:        String          // "Free", "Pro", etc.
        var remaining:   Int             // credits remaining
        var used:        Int             // credits used
        var total:       Int             // plan total (may be 0 for free)
        var bonus:       Int             // bonus credits
        var accessLevel: String          // "limited", "full"
        var upgradeURL:  String?         // from "Manage your plan: URL"
        var rawResponse: String          // full text for display
        var fetchedAt:   Date = Date()
    }

    // MARK: - Setup

    func setClient(_ client: MCPClient) {
        self.client = client
    }

    func reset() {
        client = nil
        statusCache.removeAll()
        logsCache.removeAll()
        errors.removeAll()
        creditBalance = nil
        sessionToken = nil
    }

    // MARK: - Credits (works with API key auth — no OAuth required)

    func fetchCredits() async {
        isFetchingCredits = true
        defer { isFetchingCredits = false }
        do {
            // Works with API key auth — no session required
            var args: [String: Any] = [:]
            if let token = sessionToken, !token.isEmpty {
                args = sessionArgs(token: token)
            }
            let text = try await call("nexlayer_check_credits", args: args, deployment: "")
            creditBalance = parseCreditBalance(from: text)
        } catch {
            creditBalance = CreditBalance(
                plan: "Unknown",
                remaining: 0, used: 0, total: 0, bonus: 0,
                accessLevel: "unknown",
                rawResponse: "Error: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Referral (requires session — call only after web sign-in)

    func fetchReferral() async {
        guard let token = sessionToken, !token.isEmpty else {
            // Signal to BillingView that session is needed
            referralLink = "__needs_session__"
            return
        }
        isFetchingReferral = true
        defer { isFetchingReferral = false }
        do {
            let text = try await call("nexlayer_get_referral", args: sessionArgs(token: token), deployment: "")
            let cleaned = stripMetadata(from: text)
            // Extract a referral URL if present; otherwise show the cleaned message
            referralLink = extractReferralURL(from: cleaned) ?? cleaned
        } catch {
            referralLink = "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Coupon (requires session — call only after web sign-in)

    func applyCoupon(code: String) async {
        guard let token = sessionToken, !token.isEmpty else {
            couponResult = "__needs_session__"
            return
        }
        isApplyingCoupon = true
        defer { isApplyingCoupon = false }
        do {
            let text = try await call(
                "nexlayer_apply_coupon",
                args: sessionArgs(token: token).merging(["code": code]) { $1 },
                deployment: ""
            )
            couponResult = stripMetadata(from: text)
            await fetchCredits()
        } catch {
            couponResult = "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Billing portal

    func openBillingPortal() {
        NSWorkspace.shared.open(URL(string: "https://app.nexlayer.com/settings/plans")!)
    }

    // MARK: - CSV Export

    func exportCSV() -> String {
        var lines = ["id,tool,deployment,timestamp,duration_ms,success,error"]
        let fmt = ISO8601DateFormatter()
        for r in callHistory {
            let ts  = fmt.string(from: r.timestamp)
            let err = r.error?.replacingOccurrences(of: ",", with: ";") ?? ""
            lines.append("\(r.id),\(r.tool),\(r.deployment),\(ts),\(r.durationMs),\(r.success),\(err)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Status

    func fetchStatus(for server: AppState.ServerConfig) async {
        let key = server.nexlayerApp
        loading[key] = true
        defer { loading[key] = false }
        errors.removeValue(forKey: key)

        do {
            var args: [String: Any] = ["applicationName": server.nexlayerApp]
            if !server.nexlayerDomain.isEmpty { args["domain"] = server.nexlayerDomain }
            let text = try await call("nexlayer_check_deployment_status", args: args, deployment: key)
            statusCache[key] = DeploymentStatus(raw: text, fetchedAt: Date())
        } catch {
            errors[key] = error.localizedDescription
        }
    }

    // MARK: - Logs

    func fetchLogs(for server: AppState.ServerConfig, podName: String) async {
        let key = "\(server.nexlayerApp)/\(podName)"
        loading[key] = true
        defer { loading[key] = false }

        do {
            let args: [String: Any] = [
                "applicationName": server.nexlayerApp,
                "domain": server.nexlayerDomain,
                "pods": [["podName": podName, "previous": false]]
            ]
            let text = try await call("nexlayer_get_deployment_logs", args: args, deployment: server.nexlayerApp)
            logsCache[key] = text
        } catch {
            logsCache[key] = "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Restart

    func restartDeployment(_ server: AppState.ServerConfig) async throws {
        let args: [String: Any] = [
            "domain": server.nexlayerDomain,
            "deployment": server.nexlayerApp
        ]
        _ = try await call("nexlayer_debug_pod_restart_deployment", args: args, deployment: server.nexlayerApp)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await fetchStatus(for: server)
    }

    // MARK: - Discovery

    func fetchDeployments(namespace: String) async throws -> [AppState.ServerConfig] {
        isSyncing = true
        defer { isSyncing = false }
        let text = try await call("nexlayer_debug_namespace_info", args: ["domain": namespace], deployment: "")
        let slugs = Self.parseDeploymentSlugs(from: text)
        return slugs.map { slug in
            AppState.ServerConfig(
                name: Self.displayName(for: slug),
                transport: .http,
                url: "https://\(namespace)-\(slug).cloud.nexlayer.ai",
                nexlayerDomain: namespace,
                nexlayerApp: slug
            )
        }
    }

    // Visible for testing
    static func parseDeploymentSlugs(from text: String) -> [String] {
        var inServices = false
        var slugs = [String]()
        var seen = Set<String>()

        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("SERVICES:") { inServices = true; continue }
            if inServices && (line.hasPrefix("CONFIGMAPS") || line.hasPrefix("---")) { break }
            guard inServices else { continue }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let serviceName = String(trimmed.split(separator: " ").first ?? Substring(trimmed))
            guard !systemServices.contains(serviceName),
                  !serviceName.hasSuffix("...") else { continue }

            if let slug = extractSlug(from: serviceName), !seen.contains(slug) {
                seen.insert(slug)
                slugs.append(slug)
            }
        }
        return slugs.sorted()
    }

    private static let infraComponents: Set<String> = [
        "web", "kuma", "minio", "vllm", "runner", "backup", "frontend", "backend", "worker"
    ]

    private static let systemServices: Set<String> = [
        "nexlayer-debug-proxy", "pod"
    ]

    static func extractSlug(from serviceName: String) -> String? {
        guard serviceName.hasSuffix("-service") else { return nil }
        let name = String(serviceName.dropLast("-service".count))
        let tokens = name.split(separator: "-").map(String.init)
        guard tokens.count > 1 else { return name }

        for prefixLen in stride(from: tokens.count / 2, through: 1, by: -1) {
            let prefix = Array(tokens[..<prefixLen])
            for startPos in prefixLen...(tokens.count - prefixLen) {
                if Array(tokens[startPos..<(startPos + prefixLen)]) == prefix {
                    return Array(tokens[..<startPos]).joined(separator: "-")
                }
            }
        }

        if let last = tokens.last, infraComponents.contains(last) {
            let slug = Array(tokens.dropLast()).joined(separator: "-")
            return slug.isEmpty ? nil : slug
        }

        return name
    }

    static func displayName(for slug: String) -> String {
        slug.split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    // MARK: - Parsers

    /// Parses the nexlayer_check_credits response.
    /// Actual format (newline-separated):
    ///   Plan: Free
    ///   Credits remaining: 0 (used 5022 of 0, +5000 bonus)
    ///   Access level: limited
    ///
    ///   Manage your plan: https://app.nexlayer.com/settings/plans
    ///
    ///   ---
    ///   _NL Token Burn: 1 tokens (api tier)_
    static func parseCreditBalance(from text: String) -> CreditBalance {
        // Normalize pipe-separated format too
        let normalized = text.replacingOccurrences(of: " | ", with: "\n")
        var plan = "Unknown"
        var remaining = 0
        var used = 0
        var total = 0
        var bonus = 0
        var accessLevel = "unknown"
        var upgradeURL: String?

        // Stop parsing at the "---" metadata separator
        for line in normalized.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t == "---" { break }

            if t.hasPrefix("Plan:") {
                plan = String(t.dropFirst("Plan:".count)).trimmingCharacters(in: .whitespaces)
            } else if t.hasPrefix("Credits remaining:") {
                let rest = String(t.dropFirst("Credits remaining:".count)).trimmingCharacters(in: .whitespaces)
                if let spaceIdx = rest.firstIndex(of: " ") {
                    remaining = Int(rest[rest.startIndex..<spaceIdx]) ?? 0
                } else {
                    remaining = Int(rest) ?? 0
                }
                if let openParen = rest.firstIndex(of: "("),
                   let closeParen = rest.lastIndex(of: ")") {
                    let inner = String(rest[rest.index(after: openParen)..<closeParen])
                    for part in inner.components(separatedBy: ",") {
                        let p = part.trimmingCharacters(in: .whitespaces)
                        if p.hasPrefix("used ") {
                            let nums = p.dropFirst("used ".count).components(separatedBy: " of ")
                            used  = Int(nums[0].trimmingCharacters(in: .whitespaces)) ?? 0
                            total = nums.count > 1 ? (Int(nums[1].trimmingCharacters(in: .whitespaces)) ?? 0) : 0
                        } else if p.hasPrefix("+") {
                            let numStr = p.dropFirst().components(separatedBy: " ").first ?? ""
                            bonus = Int(numStr) ?? 0
                        }
                    }
                }
            } else if t.hasPrefix("Access level:") {
                accessLevel = String(t.dropFirst("Access level:".count)).trimmingCharacters(in: .whitespaces)
            } else if t.hasPrefix("Manage your plan:") {
                let url = String(t.dropFirst("Manage your plan:".count)).trimmingCharacters(in: .whitespaces)
                upgradeURL = url.isEmpty ? nil : url
            }
        }

        return CreditBalance(
            plan: plan,
            remaining: remaining,
            used: used,
            total: total,
            bonus: bonus,
            accessLevel: accessLevel,
            upgradeURL: upgradeURL,
            rawResponse: text
        )
    }

    func parseCreditBalance(from text: String) -> CreditBalance {
        Self.parseCreditBalance(from: text)
    }

    // MARK: - Private helpers

    /// Builds session args for tools that need OAuth session params.
    private func sessionArgs(token: String) -> [String: Any] {
        ["sessionToken": token, "sessionId": "", "userIP": ""]
    }

    /// Strips the `---\n_NL Token Burn:...` metadata footer from MCP responses.
    private func stripMetadata(from text: String) -> String {
        var lines = [String]()
        for line in text.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }
            lines.append(line)
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extracts a referral-specific URL (not just any nexlayer.com link).
    private func extractReferralURL(from text: String) -> String? {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.first(where: {
            ($0.hasPrefix("http://") || $0.hasPrefix("https://")) &&
            (($0.contains("invite") || $0.contains("referral") || $0.contains("ref=")))
        })
    }

    // MARK: - Private call

    private func call(_ tool: String, args: [String: Any], deployment: String = "") async throws -> String {
        guard let client else { throw NexlayerServiceError.notConnected }

        var attempt = 0
        var retryDelay: UInt64 = 1_000_000_000  // 1s → 2s (exponential)
        let start = Date()

        while true {
            do {
                let result = try await withThrowingTaskGroup(of: String.self) { group in
                    group.addTask {
                        let result = try await client.callTool(name: tool, arguments: args)
                        return result.content.compactMap { $0.text }.joined(separator: "\n")
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: 10_000_000_000)  // 10s
                        throw NexlayerServiceError.callTimeout
                    }
                    let r = try await group.next()!
                    group.cancelAll()
                    return r
                }
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                callHistory.append(ToolCallRecord(tool: tool, deployment: deployment, durationMs: ms, success: true))
                return result
            } catch NexlayerServiceError.callTimeout {
                attempt += 1
                guard attempt < 3 else {
                    let ms = Int(Date().timeIntervalSince(start) * 1000)
                    callHistory.append(ToolCallRecord(tool: tool, deployment: deployment, durationMs: ms, success: false, error: "timeout"))
                    throw NexlayerServiceError.callTimeout
                }
                try await Task.sleep(nanoseconds: retryDelay)
                retryDelay *= 2
            }
        }
    }
}

enum NexlayerServiceError: Error, LocalizedError {
    case notConnected
    case callTimeout
    var errorDescription: String? {
        switch self {
        case .notConnected: return "Nexlayer MCP client is not connected"
        case .callTimeout:  return "Tool call timed out (3 attempts × 10s) — check your connection"
        }
    }
}
