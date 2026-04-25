import Foundation
import Observation

@Observable
final class MCPServerManager {
    var clients: [UUID: MCPClient] = [:]
    var connectionErrors: [UUID: String] = [:]
    var apiKey: String?

    enum ConnectionStatus {
        case connected, connecting, stopped, error
    }

    func connect(server: AppState.ServerConfig) async {
        connectionErrors.removeValue(forKey: server.id)
        let client = MCPClient()
        clients[server.id] = client   // immediately visible as .connecting
        do {
            let transport: any MCPTransport
            switch server.transport {
            case .stdio:
                let t = StdioTransport(command: server.command, args: server.args, env: server.envVars)
                try t.start()
                transport = t
            case .http:
                guard let url = URL(string: server.url) else {
                    clients.removeValue(forKey: server.id)
                    connectionErrors[server.id] = "Invalid URL: \(server.url)"
                    return
                }
                transport = HTTPTransport(url: url, bearerToken: apiKey)
            }
            try await client.connect(transport: transport)
        } catch {
            clients.removeValue(forKey: server.id)
            connectionErrors[server.id] = error.localizedDescription
        }
    }

    func disconnect(server: AppState.ServerConfig) async {
        clients[server.id]?.disconnect()
        clients.removeValue(forKey: server.id)
    }

    func stopAll() {
        for client in clients.values { client.disconnect() }
        clients.removeAll()
    }
}
