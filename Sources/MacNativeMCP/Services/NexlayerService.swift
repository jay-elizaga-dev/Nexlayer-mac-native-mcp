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
