import Foundation
import Observation

@Observable
final class MCPServerManager {
    var clients: [UUID: MCPClient] = [:]

    func start(config: AppState.ServerConfig) async throws -> MCPClient {
        let transport = StdioTransport(command: config.command, args: config.args, env: config.envVars)
        try transport.start()
        let client = MCPClient()
        try await client.connect(transport: transport)
        clients[config.id] = client
        return client
    }

    func stop(id: UUID) {
        clients[id] = nil
    }

    func stopAll() {
        clients.removeAll()
    }
}
