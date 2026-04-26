import Foundation
import Observation

@Observable
@MainActor
final class NexlayerService {

    // MARK: - State

    private(set) var client: MCPClient?

    var statusCache:  [String: DeploymentStatus] = [:]
    var logsCache:    [String: String]            = [:]
    var loading:      [String: Bool]              = [:]
    var errors:       [String: String]            = [:]
    var isSyncing:    Bool                        = false

    // MARK: - Models

    struct DeploymentStatus {
        var raw: String
        var fetchedAt: Date
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
            let text = try await call("nexlayer_check_deployment_status", args: args)
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
            let text = try await call("nexlayer_get_deployment_logs", args: args)
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
        _ = try await call("nexlayer_debug_pod_restart_deployment", args: args)
        // Refresh status after restart
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await fetchStatus(for: server)
    }

    // MARK: - Discovery

    func fetchDeployments(namespace: String) async throws -> [AppState.ServerConfig] {
        isSyncing = true
        defer { isSyncing = false }
        let text = try await call("nexlayer_debug_namespace_info", args: ["domain": namespace])
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

        // Strategy 1: find a prefix that repeats at a later position
        // Try longest prefixes first so "etf-bot-dev-test-etf-bot" picks "etf-bot-dev-test" not "etf"
        for prefixLen in stride(from: tokens.count / 2, through: 1, by: -1) {
            let prefix = Array(tokens[..<prefixLen])
            for startPos in prefixLen...(tokens.count - prefixLen) {
                if Array(tokens[startPos..<(startPos + prefixLen)]) == prefix {
                    return Array(tokens[..<startPos]).joined(separator: "-")
                }
            }
        }

        // Strategy 2: strip known infra component suffix
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

    // MARK: - Private

    private func call(_ tool: String, args: [String: Any]) async throws -> String {
        guard let client else { throw NexlayerServiceError.notConnected }
        let result = try await client.callTool(name: tool, arguments: args)
        return result.content.compactMap { $0.text }.joined(separator: "\n")
    }
}

enum NexlayerServiceError: Error, LocalizedError {
    case notConnected
    var errorDescription: String? { "Nexlayer MCP client is not connected" }
}
