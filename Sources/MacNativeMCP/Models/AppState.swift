import Foundation
import Observation

@Observable
class AppState {
    private let store = ServerConfigStore()

    var servers: [ServerConfig] = []
    var activeServerId: UUID? = nil
    var messages: [ConversationMessage] = []
    var selectedTool: MCPTool? = nil
    var lastToolResult: OutputResult? = nil
    var lastCalledTool: String? = nil

    init() {
        servers = store.load()
        if servers.isEmpty {
            servers = NexlayerBootstrap.defaultServers
            store.save(servers)
        }
    }

    func addServer(_ config: ServerConfig) {
        servers.append(config)
        store.save(servers)
    }

    func removeServer(id: UUID) {
        servers.removeAll { $0.id == id }
        store.save(servers)
    }

    func updateServer(_ config: ServerConfig) {
        guard let index = servers.firstIndex(where: { $0.id == config.id }) else { return }
        servers[index] = config
        store.save(servers)
    }

    /// Merge discovered Nexlayer deployments into the server list without duplicates.
    func syncDeployments(_ discovered: [ServerConfig]) {
        let existingSlugs = Set(servers.filter(\.isNexlayerDeployment).map(\.nexlayerApp))
        let newServers = discovered.filter { !existingSlugs.contains($0.nexlayerApp) }
        servers.append(contentsOf: newServers)
        if !newServers.isEmpty { store.save(servers) }
    }

    // MARK: - Chat sessions

    struct ChatSession: Identifiable {
        var id: UUID = UUID()
        var serverId: UUID
        var title: String
        var messages: [ConversationMessage] = []
        var createdAt: Date = Date()
    }

    var chatSessions: [ChatSession] = []
    var activeChatId: UUID? = nil

    func createChat(for server: ServerConfig) {
        let session = ChatSession(serverId: server.id, title: "\(server.name): New Chat")
        chatSessions.append(session)
        activeChatId = session.id
        activeServerId = server.id
    }

    func appendMessage(_ message: ConversationMessage, toChatId chatId: UUID) {
        guard let idx = chatSessions.firstIndex(where: { $0.id == chatId }) else { return }
        chatSessions[idx].messages.append(message)
    }

    enum TransportType: String, Codable {
        case stdio, http
    }

    struct ServerConfig: Identifiable, Codable {
        var id: UUID = UUID()
        var name: String = ""
        var transport: TransportType = .stdio
        // stdio fields
        var command: String = ""
        var args: [String] = []
        var envVars: [String: String] = [:]
        // http fields
        var url: String = ""
        // nexlayer metadata
        var nexlayerDomain: String = ""
        var nexlayerApp: String = ""

        var isNexlayerDeployment: Bool { !nexlayerDomain.isEmpty && !nexlayerApp.isEmpty }
    }

    struct ConversationMessage: Identifiable {
        var id: UUID = UUID()
        var role: String = "user"
        var content: String = ""
    }

    enum OutputResult {
        case code(String, String)
        case fileTree([FileEntry])
        case text(String)
    }

    struct FileEntry: Identifiable {
        var path: String
        var name: String
        var isDirectory: Bool
        var children: [FileEntry]?
        var size: Int?

        var id: String { path }
    }
}
